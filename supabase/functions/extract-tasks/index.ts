// Supabase Edge Function: extract-tasks
//
// Reads the user's recent Gmail SERVER-SIDE and classifies each email into
// actionable TASKS and JOB-APPLICATION updates using the AI model (see _shared/ai.ts).
//
// The caller must be an authenticated Supabase user. We look up their stored
// Google refresh token and mint a fresh access token server-side. Survives
// reloads; no re-auth. There is no way to pass a Gmail token in the request.
//
// Email bodies never touch the client and are never stored — only derived
// tasks/summaries are returned.
//
// Secrets: AI_API_KEY (see _shared/ai.ts), GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
//          (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are auto-injected).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handlePreflight, jsonResponse, requireUser } from "../_shared/http.ts";
import { aiConfigured, chatJson } from "../_shared/ai.ts";
import { SYSTEM_PROMPT } from "./prompt.ts";
import {
  accessTokenFromRefresh,
  fetchEmailBodies,
  listInboxIds,
  localDate,
} from "./gmail.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Subtracts ids already analysed (present in processed_emails) from a listed
// id set. Only the listed ids are queried, in chunks, so the API's 1000-row
// cap can never hide a processed row. A query failure THROWS: treating
// everything as pending would silently re-bill the model for old mail.
async function filterPendingIds(
  userId: string,
  ids: string[],
): Promise<string[]> {
  if (ids.length === 0) return ids;
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const processed = new Set<string>();
  for (let i = 0; i < ids.length; i += 100) {
    const chunk = ids.slice(i, i + 100);
    const { data, error } = await admin
      .from("processed_emails")
      .select("email_id")
      .eq("user_id", userId)
      .in("email_id", chunk);
    if (error) throw new Error(error.message);
    for (const r of data ?? []) processed.add((r as { email_id: string }).email_id);
  }
  return ids.filter((id) => !processed.has(id));
}

// Marks a batch as analysed after a SUCCESSFUL model response only. A write
// failure here is logged and swallowed — the user getting their tasks matters
// more than the mark, and the cost of a missed mark is just re-analysis.
async function markProcessed(userId: string, ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const rows = ids.map((id) => ({ user_id: userId, email_id: id }));
    const { error } = await admin
      .from("processed_emails")
      .upsert(rows, { onConflict: "user_id,email_id", ignoreDuplicates: true });
    if (error) {
      console.error("processed_emails upsert failed", error);
    }
  } catch (e) {
    console.error("processed_emails upsert failed", e);
  }
}

// Resolve a Gmail access token for this request from the stored refresh token.
async function resolveAccessToken(
  req: Request,
): Promise<{ token: string; userId: string } | { error: Response }> {
  // Identify the user from their Supabase JWT, load stored refresh token.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const user = await requireUser(req, admin);
  if (user instanceof Response) return { error: user };
  const userId = user.id;
  const { data: cred } = await admin
    .from("google_credentials")
    .select("refresh_token")
    .eq("user_id", userId)
    .maybeSingle();
  if (!cred?.refresh_token) {
    return { error: jsonResponse(req, { error: "gmail_not_connected" }, 200) };
  }
  try {
    return { token: await accessTokenFromRefresh(cred.refresh_token), userId };
  } catch (e) {
    return { error: jsonResponse(req, { error: "token_refresh_failed", detail: String(e) }, 502) };
  }
}

function truncate(s: string, max = 80): string {
  const t = s.trim();
  return t.length > max ? t.slice(0, max) : t;
}

/// Assembles a short "About this user" block from user_facts, for the model's
/// background only. Returns "" on a query error or zero facts —
/// a facts problem must never change what's sent to the model beyond this block.
async function buildFactsBlock(
  userId: string,
): Promise<{ block: string; factsCount: number }> {
  const EMPTY = { block: "", factsCount: 0 };

  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data, error } = await admin
      .from("user_facts")
      .select("category, fact")
      .eq("user_id", userId)
      .is("suppressed_at", null)
      .order("last_confirmed_at", { ascending: false })
      .limit(15);

    if (error || !data || data.length === 0) return EMPTY;

    const lines = data
      .map((f) => `- ${truncate(f.category ?? "", 30)}: ${truncate(f.fact ?? "", 100)}`)
      .filter((l) => l !== "- : ");
    if (lines.length === 0) return EMPTY;

    // Budget the LINES rather than trimming the finished string, so the
    // reported count always matches what the model was actually shown. A
    // diagnostic that over-reports is worse than no diagnostic: it makes
    // "the facts were cut" look like "the model ignored them".
    const header =
      "About this user (background only — these are NOT tasks and must never be extracted as tasks):";
    const kept: string[] = [];
    let length = header.length;
    for (const line of lines) {
      if (length + 1 + line.length > 1200) break;
      kept.push(line);
      length += 1 + line.length;
    }
    if (kept.length === 0) return EMPTY;

    return { block: `${header}\n${kept.join("\n")}`, factsCount: kept.length };
  } catch (_) {
    // A facts problem must never break an inbox scan. The Supabase client
    // returns {error} for query failures, but a transport-level fault still
    // throws, and that would 500 the whole scan over an optional extra.
    return EMPTY;
  }
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    if (!aiConfigured) {
      return jsonResponse(req, { error: "AI_API_KEY is not configured." }, 500);
    }

    const body = await req.json().catch(() => null);
    // Clamped SERVER-SIDE, deliberately, to match kScanBatchSize in the
    // client. Clamping here rather than only in the client protects builds already
    // installed on phones, which cannot be updated without a new IPA.
    const kMaxBatch = 50;
    const maxResults = Math.min(
      Math.max(Number(body?.maxResults) || 10, 1),
      kMaxBatch,
    );
    const debug = body?.debug === true;
    // Clamped to the real-world range and defaulting to 0, so a missing or junk
    // value degrades to UTC dates rather than throwing the scan away.
    const rawTz = Number(body?.tzOffsetMinutes);
    const tzOffsetMinutes = Number.isFinite(rawTz)
      ? Math.min(Math.max(rawTz, -840), 840)
      : 0;
    const action = body?.action === "count" ? "count" : "scan";
    const order = body?.order === "oldest" ? "oldest" : "newest";
    const rawHorizon = Number(body?.horizonDays);
    const horizonDays = Number.isFinite(rawHorizon)
      ? Math.min(Math.max(Math.floor(rawHorizon), 1), 90)
      : 30;

    const resolved = await resolveAccessToken(req);
    if ("error" in resolved) return resolved.error;
    const { token: accessToken, userId } = resolved;

    let account = "";
    let pendingIds: string[] = [];
    let capped = false;
    let listingIds: string[] = [];
    try {
      const listing = await listInboxIds(accessToken, horizonDays);
      account = listing.account;
      capped = listing.capped;
      listingIds = listing.ids;
    } catch (e) {
      return jsonResponse(req, { error: "Gmail fetch failed", detail: String(e) }, 502);
    }
    // Shared by the scan and `count` paths, so both fail the same way.
    try {
      pendingIds = await filterPendingIds(userId, listingIds);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return jsonResponse(req, 
        { error: "Lookup failed", detail: `processed_emails lookup failed: ${msg}` },
        502,
      );
    }

    // Count-only: must never fetch a body or call the model. Returns as soon
    // as the id set is known, before any per-message Gmail call is made.
    if (action === "count") {
      return jsonResponse(req, {
        pending: pendingIds.length,
        capped,
        horizonDays,
        scannedAccount: account,
      });
    }

    if (pendingIds.length === 0) {
      return jsonResponse(req, {
        tasks: [],
        jobUpdates: [],
        subscriptions: [],
        scannedAccount: account,
      });
    }

    const orderedIds = order === "oldest" ? [...pendingIds].reverse() : pendingIds;
    const batchIds = orderedIds.slice(0, maxResults);

    let emails;
    try {
      emails = await fetchEmailBodies(accessToken, batchIds, tzOffsetMinutes);
    } catch (e) {
      return jsonResponse(req, { error: "Gmail fetch failed", detail: String(e) }, 502);
    }

    // Every message in the batch was deleted since it was listed: nothing to
    // send. Mark them so they stop blocking the batch, and skip the model.
    if (emails.length === 0) {
      await markProcessed(userId, batchIds);
      return jsonResponse(req, {
        tasks: [],
        jobUpdates: [],
        subscriptions: [],
        scannedAccount: account,
        analyzedCount: batchIds.length,
        remaining: Math.max(pendingIds.length - batchIds.length, 0),
      });
    }

    const { block: factsBlock, factsCount } = await buildFactsBlock(userId);
    const todayLine = `TODAY is ${localDate(Date.now(), tzOffsetMinutes)}.`;
    const userContent = factsBlock
      ? `${todayLine}\n\n${factsBlock}\n\nEmails:\n${JSON.stringify(emails)}`
      : `${todayLine}\n\nEmails:\n${JSON.stringify(emails)}`;

    // A batch can return tasks, job updates and subscriptions for up to 50
    // emails. A reply cut off by the cap is invalid JSON, the batch is never
    // marked analysed and every later scan would retry it, so leave headroom.
    const aiRes = await chatJson(userId, SYSTEM_PROMPT, userContent, 16384);

    if (!aiRes.ok) {
      if (aiRes.quotaExceeded) {
        return jsonResponse(req, { error: "daily_ai_limit", detail: aiRes.detail }, 429);
      }
      return jsonResponse(req, { error: "AI provider error", detail: aiRes.detail }, 502);
    }

    const content = aiRes.content;

    let parsed: {
      tasks?: unknown[];
      jobUpdates?: unknown[];
      subscriptions?: unknown[];
    };
    try {
      parsed = JSON.parse(content);
    } catch {
      return jsonResponse(req, { error: "Model returned invalid JSON", raw: content }, 502);
    }

    // Only mark the batch analysed once the model has genuinely succeeded, never
    // on a Gmail/model/JSON failure above, and never on the count path.
    await markProcessed(userId, batchIds);
    const analyzedCount = batchIds.length;
    const remaining = Math.max(pendingIds.length - analyzedCount, 0);

    return jsonResponse(req, {
      tasks: parsed.tasks ?? [],
      jobUpdates: parsed.jobUpdates ?? [],
      subscriptions: parsed.subscriptions ?? [],
      scannedAccount: account,
      analyzedCount,
      remaining,
      ...(debug
        ? {
            _debug: {
              fetchedSubjects: emails.map((e: { subject: string }) => e.subject),
              rawModel: content,
              factsCount,
            },
          }
        : {}),
    });
  } catch (e) {
    return jsonResponse(req, { error: String(e) }, 500);
  }
});
