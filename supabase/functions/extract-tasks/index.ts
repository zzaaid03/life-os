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
UPDATES. Be precise — if an email fits neither category, ignore it completely.

=== TASKS ===
Extract a task ONLY when the email clearly requires the recipient to personally DO
something actionable — a real person asking them to send/review/reply/prepare
something, a deadline they must act on, an appointment to book, or a bill to pay.

ALWAYS IGNORE for tasks (they are noise):
- Automated notifications and security alerts ("a new app/login was added",
  "your data was shared", "sign-in from a new device")
- Newsletters, marketing, promotions, and job-board nudges
- Receipts, order/shipping updates, and bills that need no action
- Social notifications, "Welcome to X" emails, and no-reply informational mail
Do NOT invent vague tasks like "review this" or "visit settings" from informational
emails. Emit ONE task per distinct action; never split one request into many.
Each task: {title (short imperative), dueDateHint (short phrase or null),
priority (none|low|medium|high), sourceEmailId}.

=== JOB UPDATES ===
For any email about the recipient's job applications or opportunities — application
received/viewed/rejected, interview invites, offers, or a specific role/deadline —
produce a short summary entry instead of (or in addition to) a task.
Only create a TASK from a job email if there is a concrete action with a deadline
(e.g. "confirm interview time", "reply by Friday", "role expires soon — reapply").
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
  - applied: an application confirmation/received with no decision yet
  If the email is job-related but doesn't clearly fit any of the above
  (e.g. a posting about to expire, a recruiter nudge), use applied.
  NEVER emit any other status word.
- summary: one concise, human sentence reflecting the ACTUAL outcome
  (e.g. "RoboService rejected your application for the Data Science working-student role.")

Respond with ONLY a JSON object of this exact form:
{"tasks":[{"title": string, "dueDateHint": string|null, "priority": string, "sourceEmailId": string}],
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

async function fetchRecentEmails(accessToken: string, maxResults: number) {
  const gmail = (path: string) =>
    fetch(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

  // Which Google account does this token actually belong to?
  let account = "";
  const profileRes = await gmail("profile");
  if (profileRes.ok) {
    account = (await profileRes.json()).emailAddress ?? "";
  }

  const listRes = await gmail(`messages?maxResults=${maxResults}&labelIds=INBOX`);
  if (!listRes.ok) {
    throw new Error(`Gmail list ${listRes.status}: ${await listRes.text()}`);
  }
  const { messages = [] } = await listRes.json();

  const emails = await Promise.all(
    messages.map(async ({ id }: { id: string }) => {
      const r = await gmail(`messages/${id}?format=full`);
      const m = await r.json();
      const headers = m.payload?.headers ?? [];
      const h = (n: string) =>
        headers.find((x: { name: string }) => x.name.toLowerCase() === n.toLowerCase())
          ?.value ?? "";
      const body = extractBody(m.payload).replace(/\s+/g, " ").trim().slice(0, 1500);
      return { id, from: h("From"), subject: h("Subject"), body };
    }),
  );
  return { account, emails };
}

// Resolve a Gmail access token for this request (test path OR stored-refresh path).
async function resolveAccessToken(
  req: Request,
  bodyToken: string | undefined,
): Promise<{ token?: string; error?: Response }> {
  // Test path: token passed directly.
  if (bodyToken) return { token: bodyToken };

  // App path: identify the user from their Supabase JWT, load stored refresh token.
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !userData?.user) {
    return { error: jsonResponse({ error: "unauthorized" }, 401) };
  }
  const { data: cred } = await admin
    .from("google_credentials")
    .select("refresh_token")
    .eq("user_id", userData.user.id)
    .maybeSingle();
  if (!cred?.refresh_token) {
    return { error: jsonResponse({ error: "gmail_not_connected" }, 200) };
  }
  try {
    return { token: await accessTokenFromRefresh(cred.refresh_token) };
  } catch (e) {
    return { error: jsonResponse({ error: "token_refresh_failed", detail: String(e) }, 502) };
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
    const maxResults = Math.min(Math.max(Number(body?.maxResults) || 10, 1), 20);
    const debug = body?.debug === true;

    const { token: accessToken, error: tokenError } = await resolveAccessToken(
      req,
      body?.accessToken,
    );
    if (tokenError) return tokenError;

    let account = "";
    let emails;
    try {
      const result = await fetchRecentEmails(accessToken!, maxResults);
      account = result.account;
      emails = result.emails;
    } catch (e) {
      return jsonResponse({ error: "Gmail fetch failed", detail: String(e) }, 502);
    }
    if (emails.length === 0) {
      return jsonResponse({ tasks: [], jobUpdates: [], scannedAccount: account });
    }

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
            { role: "user", content: "Emails:\n" + JSON.stringify(emails) },
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

    return jsonResponse({
      tasks: parsed.tasks ?? [],
      jobUpdates: parsed.jobUpdates ?? [],
      scannedAccount: account,
      ...(debug
        ? {
            _debug: {
              fetchedSubjects: emails.map((e: { subject: string }) => e.subject),
              rawModel: content,
            },
          }
        : {}),
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
