// Supabase Edge Function: extract-tasks
//
// Reads the user's recent Gmail SERVER-SIDE and classifies each email into
// actionable TASKS and JOB-APPLICATION updates using Groq (Llama 3.3 70B).
//
// Two ways to get a Gmail access token:
//   1. App path (production): the caller is an authenticated Supabase user and
//      does NOT pass a token. We look up their stored Google refresh token and
//      mint a fresh access token server-side. Survives reloads; no re-auth.
//   2. Test path: caller passes { accessToken } directly (used by our terminal
//      test scripts). Bypasses the stored-credential lookup.
//
// Email bodies never touch the client and are never stored — only derived
// tasks/summaries are returned.
//
// Secrets: GROQ_API_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
//          (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are auto-injected).

import { createClient } from "jsr:@supabase/supabase-js@2";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID");
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT =
  `You are an inbox assistant for a busy person who is also actively job-hunting.
You read emails and produce TWO things: (1) actionable TASKS, and (2) JOB APPLICATION
UPDATES. Be precise: if an email fits neither category, ignore it completely.

The user message states TODAY as the user's local date, and every email carries its own
sentDate. Resolve dates against those two only, never against your own idea of the date.

=== TASKS ===
Extract a task when the email requires the recipient to personally DO something, or
names something dated they cannot afford to miss. That means any of:
1. REQUESTS AND DEADLINES: a real person asking them to send/review/reply/prepare
   something, or a deadline they must act on.
2. BILLS AND PAYMENTS DUE: an amount the recipient still owes. A paid receipt or a
   successful payment confirmation is NOT a bill.
3. APPOINTMENTS AND EVENTS: something at a specific time they must attend, book,
   confirm or reschedule.
4. SUBSCRIPTION RENEWALS: a subscription, plan or membership that will auto-renew,
   expire, or change price, where knowing the date lets them cancel or budget.
5. DELIVERIES AND COLLECTION DEADLINES: a parcel needing action from them, such as
   collect by a date, arrange redelivery, or a failed delivery attempt.

ALWAYS IGNORE for tasks (they are noise):
- Automated notifications and security alerts ("a new app/login was added",
  "your data was shared", "sign-in from a new device")
- Newsletters, marketing, promotions, and job-board nudges
- Receipts, and order or shipping updates that need nothing from the recipient
- Social notifications, "Welcome to X" emails, and no-reply informational mail
A dated fact the recipient can do nothing about is NOT a task.
Do NOT invent vague tasks like "review this" or "visit settings" from informational
emails. Emit ONE task per distinct action; never split one request into many.
Each task: {title (short imperative), dueDate (see DATES), dueDateHint (short phrase
or null), priority (none|low|medium|high), sourceEmailId}.

DATES. dueDate is an ISO yyyy-mm-dd string and is the anti-hallucination gate:
- Emit a dueDate ONLY when the email states the date plainly enough that you could
  point at the words that say it. "Due 15 March", "by 03/15/2026", "renews on
  1 April" all qualify. A weekday or relative phrase ("by Friday", "within 7 days")
  qualifies ONLY once you resolve it against that email's sentDate.
- If the year is missing, pick the year that puts the date on or after the email's
  sentDate. Never emit a dueDate before that email's sentDate.
- If the email gives no date, or gives a vague one ("soon", "shortly", "as soon as
  possible", "end of the month"), dueDate MUST be null. Guessing a date is a failure,
  worse than emitting none. Put the vague wording in dueDateHint instead.
- dueDate and dueDateHint are independent. Emit either, both, or neither.

=== JOB UPDATES ===
Produce a job update ONLY when the email clearly concerns the RECIPIENT'S OWN
application to a specific employer — their personal application lifecycle.
Qualifying emails: an application confirmation/received, notice that their
application was viewed by the employer, an interview invite or scheduling request,
an online assessment/test tied to their application, a rejection, or an offer/
acceptance. This includes ATS emails (Workday, Greenhouse, Lever, SmartRecruiters,
etc.) about a role they actually applied to.

NEVER create a job update from (these are NOT applications the recipient made):
- Job alerts, recommended jobs, or job-board digests (LinkedIn, Indeed, Glassdoor, etc.)
- Recruiter cold-outreach or "I have an opportunity for you" messages
- "We're hiring" / careers marketing / newsletters
- Postings about to expire or generic "apply now" nudges
If an email is job-related but you cannot tell it reflects the recipient's OWN
application to a specific company, DO NOT emit a job update — skip it. Never guess a
company or invent an application. When in doubt, emit nothing.

Only create a TASK from a job email if there is a concrete action with a deadline
(e.g. "confirm interview time", "reply by Friday").
Emails may be in English or German — read the BODY, not just the subject, to decide
status. Subjects like "Your update from X" are neutral; the real outcome is in the body.
Each job update: {company, role, status, summary, sourceEmailId}.
- status MUST be exactly one of: applied | viewed | interview | rejected | accepted.
  Determined from the body content:
  - rejected: declines or says they will not proceed ("unfortunately", "we will not be
    moving forward", "leider", "nicht weiter", "eine Absage")
  - interview: invited to interview or to schedule a call
  - accepted: a job offer or an acceptance (any "offer" counts as accepted)
  - viewed: the application was viewed/noticed by the hiring team (no decision yet)
  - applied: a genuine application confirmation/received with no decision yet
  Use applied ONLY for a real application confirmation — NEVER as a catch-all for
  ambiguous or merely job-related emails (skip those entirely).
  NEVER emit any other status word.
- summary: one concise, human sentence reflecting the ACTUAL outcome
  (e.g. "RoboService rejected your application for the Data Science working-student role.")

Respond with ONLY a JSON object of this exact form:
{"tasks":[{"title": string, "dueDate": string|null, "dueDateHint": string|null, "priority": string, "sourceEmailId": string}],
 "jobUpdates":[{"company": string, "role": string, "status": string, "summary": string, "sourceEmailId": string}]}`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// --- Google token: mint a fresh access token from a stored refresh token ---
async function accessTokenFromRefresh(refreshToken: string): Promise<string> {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    throw new Error("GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET not configured");
  }
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  if (!res.ok) {
    throw new Error(`Google token refresh ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

// --- Gmail helpers (bodies stay server-side) ---

interface GmailPart {
  mimeType?: string;
  body?: { data?: string };
  parts?: GmailPart[];
  headers?: { name: string; value: string }[];
}

function decodeBase64Url(data: string): string {
  const b64 = data.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(b64);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function findPart(payload: GmailPart | undefined, mime: string): string | null {
  if (!payload) return null;
  if (payload.mimeType === mime && payload.body?.data) return payload.body.data;
  for (const p of payload.parts ?? []) {
    const d = findPart(p, mime);
    if (d) return d;
  }
  return null;
}

function extractBody(payload: GmailPart | undefined): string {
  const plain = findPart(payload, "text/plain");
  if (plain) return decodeBase64Url(plain);
  const html = findPart(payload, "text/html");
  if (html) return decodeBase64Url(html).replace(/<[^>]+>/g, " ");
  if (payload?.body?.data) return decodeBase64Url(payload.body.data);
  return "";
}

// Local calendar date (yyyy-mm-dd) for an epoch, shifted by the caller's UTC offset.
// The model resolves "by Friday" against these, so they must be the user's dates and
// not the server's. Same tzOffsetMinutes contract daily-brief already uses.
function localDate(epochMs: number, tzOffsetMinutes: number): string {
  return new Date(epochMs + tzOffsetMinutes * 60_000).toISOString().slice(0, 10);
}

function gmailFetch(accessToken: string, path: string): Promise<Response> {
  return fetch(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}

// Lists inbox message ids inside a rolling horizon, newest first (Gmail's own
// order), without fetching any body. One page only (500 ids) — if Gmail says
// there's more, `capped` is set so the caller can report it, but we never
// page further in a single request.
async function listInboxIds(
  accessToken: string,
  horizonDays: number,
): Promise<{ account: string; ids: string[]; capped: boolean }> {
  // Which Google account does this token actually belong to?
  let account = "";
  const profileRes = await gmailFetch(accessToken, "profile");
  if (profileRes.ok) {
    account = (await profileRes.json()).emailAddress ?? "";
  }

  const afterEpochSeconds = Math.floor(Date.now() / 1000) - horizonDays * 86400;
  const listRes = await gmailFetch(
    accessToken,
    `messages?maxResults=500&labelIds=INBOX&q=${encodeURIComponent(`after:${afterEpochSeconds}`)}`,
  );
  if (!listRes.ok) {
    throw new Error(`Gmail list ${listRes.status}: ${await listRes.text()}`);
  }
  const { messages = [], nextPageToken } = await listRes.json();
  const ids = messages.map((m: { id: string }) => m.id as string);
  return { account, ids, capped: Boolean(nextPageToken) };
}

// Fetches full bodies for exactly the given ids (a selected batch, not "recent N").
async function fetchEmailBodies(
  accessToken: string,
  ids: string[],
  tzOffsetMinutes: number,
) {
  return await Promise.all(
    ids.map(async (id: string) => {
      const r = await gmailFetch(accessToken, `messages/${id}?format=full`);
      const m = await r.json();
      const headers = m.payload?.headers ?? [];
      const h = (n: string) =>
        headers.find((x: { name: string }) => x.name.toLowerCase() === n.toLowerCase())
          ?.value ?? "";
      const body = extractBody(m.payload).replace(/\s+/g, " ").trim().slice(0, 1500);
      // internalDate (epoch ms, Gmail's own receipt time) rather than the Date
      // header, which is free-form and sometimes absent or forged.
      const epoch = Number(m.internalDate);
      const sentDate = Number.isFinite(epoch)
        ? localDate(epoch, tzOffsetMinutes)
        : null;
      return { id, from: h("From"), subject: h("Subject"), sentDate, body };
    }),
  );
}

// Subtracts ids already analysed (present in processed_emails) from a listed
// id set. A query failure degrades to "nothing filtered" — re-analysing a few
// emails is wasteful, failing the scan over it is not. No user id (test path)
// means no processed-set to check, so nothing is filtered either.
async function filterPendingIds(
  userId: string | undefined,
  ids: string[],
): Promise<string[]> {
  if (!userId || ids.length === 0) return ids;
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data, error } = await admin
      .from("processed_emails")
      .select("email_id")
      .eq("user_id", userId);
    if (error || !data) return ids;
    const processed = new Set(data.map((r: { email_id: string }) => r.email_id as string));
    return ids.filter((id) => !processed.has(id));
  } catch (_) {
    return ids;
  }
}

// Marks a batch as analysed after a SUCCESSFUL Groq response only. A write
// failure here is logged and swallowed — the user getting their tasks matters
// more than the mark, and the cost of a missed mark is just re-analysis.
async function markProcessed(userId: string | undefined, ids: string[]): Promise<void> {
  if (!userId || ids.length === 0) return;
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

// Resolve a Gmail access token for this request (test path OR stored-refresh path).
async function resolveAccessToken(
  req: Request,
  bodyToken: string | undefined,
): Promise<{ token?: string; userId?: string; error?: Response }> {
  // Test path: token passed directly. No JWT, so no user id is available.
  if (bodyToken) return { token: bodyToken };

  // App path: identify the user from their Supabase JWT, load stored refresh token.
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return { error: jsonResponse({ error: "unauthorized" }, 401) };
  }
  const userId = userData.user.id;
  const { data: cred } = await admin
    .from("google_credentials")
    .select("refresh_token")
    .eq("user_id", userId)
    .maybeSingle();
  if (!cred?.refresh_token) {
    return { error: jsonResponse({ error: "gmail_not_connected" }, 200) };
  }
  try {
    return { token: await accessTokenFromRefresh(cred.refresh_token), userId };
  } catch (e) {
    return { error: jsonResponse({ error: "token_refresh_failed", detail: String(e) }, 502) };
  }
}

function truncate(s: string, max = 80): string {
  const t = s.trim();
  return t.length > max ? t.slice(0, max) : t;
}

/// Assembles a short "About this user" block from user_facts, for the model's
/// background only. Returns "" on no user id, a query error, or zero facts —
/// a facts problem must never change what's sent to Groq beyond this block.
async function buildFactsBlock(
  userId: string | undefined,
): Promise<{ block: string; factsCount: number }> {
  const EMPTY = { block: "", factsCount: 0 };
  if (!userId) return EMPTY;

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
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GROQ_API_KEY) {
      return jsonResponse({ error: "GROQ_API_KEY is not configured." }, 500);
    }

    const body = await req.json().catch(() => null);
    const maxResults = Math.min(Math.max(Number(body?.maxResults) || 10, 1), 50);
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

    const { token: accessToken, userId, error: tokenError } = await resolveAccessToken(
      req,
      body?.accessToken,
    );
    if (tokenError) return tokenError;

    let account = "";
    let pendingIds: string[] = [];
    let capped = false;
    try {
      const listing = await listInboxIds(accessToken!, horizonDays);
      account = listing.account;
      capped = listing.capped;
      pendingIds = await filterPendingIds(userId, listing.ids);
    } catch (e) {
      return jsonResponse({ error: "Gmail fetch failed", detail: String(e) }, 502);
    }

    // Count-only: must never fetch a body or call the model. Returns as soon
    // as the id set is known, before any per-message Gmail call is made.
    if (action === "count") {
      return jsonResponse({
        pending: pendingIds.length,
        capped,
        horizonDays,
        scannedAccount: account,
      });
    }

    if (pendingIds.length === 0) {
      return jsonResponse({ tasks: [], jobUpdates: [], scannedAccount: account });
    }

    const orderedIds = order === "oldest" ? [...pendingIds].reverse() : pendingIds;
    const batchIds = orderedIds.slice(0, maxResults);

    let emails;
    try {
      emails = await fetchEmailBodies(accessToken!, batchIds, tzOffsetMinutes);
    } catch (e) {
      return jsonResponse({ error: "Gmail fetch failed", detail: String(e) }, 502);
    }

    const { block: factsBlock, factsCount } = await buildFactsBlock(userId);
    const todayLine = `TODAY is ${localDate(Date.now(), tzOffsetMinutes)}.`;
    const userContent = factsBlock
      ? `${todayLine}\n\n${factsBlock}\n\nEmails:\n${JSON.stringify(emails)}`
      : `${todayLine}\n\nEmails:\n${JSON.stringify(emails)}`;

    const groqRes = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${GROQ_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          temperature: 0,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: userContent },
          ],
        }),
      },
    );

    if (!groqRes.ok) {
      return jsonResponse({ error: "Groq API error", detail: await groqRes.text() }, 502);
    }

    const data = await groqRes.json();
    const content = data.choices?.[0]?.message?.content ?? "{}";

    let parsed: { tasks?: unknown[]; jobUpdates?: unknown[] };
    try {
      parsed = JSON.parse(content);
    } catch {
      return jsonResponse({ error: "Model returned invalid JSON", raw: content }, 502);
    }

    // Only mark the batch analysed once Groq has genuinely succeeded — never
    // on a Gmail/Groq/JSON failure above, and never on the count path.
    await markProcessed(userId, batchIds);
    const analyzedCount = batchIds.length;
    const remaining = Math.max(pendingIds.length - analyzedCount, 0);

    return jsonResponse({
      tasks: parsed.tasks ?? [],
      jobUpdates: parsed.jobUpdates ?? [],
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
    return jsonResponse({ error: String(e) }, 500);
  }
});
