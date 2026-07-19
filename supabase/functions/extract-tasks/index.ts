// Supabase Edge Function: extract-tasks
//
// Receives a batch of emails (subject + snippet only — never full bodies),
// asks Groq (free, open-source Llama 3.3 70B) to extract actionable tasks,
// and returns them as structured JSON.
//
// The GROQ_API_KEY lives here as a Supabase secret — never in the app.
//
// Deploy:  supabase functions deploy extract-tasks
// Secret:  supabase secrets set GROQ_API_KEY=your_key

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");

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
- status, determined from the body content:
  - rejected: declines or says they will not proceed ("unfortunately", "we will not be
    moving forward", "leider", "nicht weiter", "eine Absage")
  - interview: invited to interview or to schedule a call
  - offer: a job offer
  - viewed: the application was viewed/noticed by the hiring team (no decision yet)
  - applied: an application confirmation/received with no decision yet
  - deadline: a posting/role about to expire
  - other: anything else job-related
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

Deno.serve(async (req: Request) => {
  // Browser preflight (Flutter web calls this from a different origin).
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GROQ_API_KEY) {
      return jsonResponse({ error: "GROQ_API_KEY is not configured." }, 500);
    }

    const body = await req.json().catch(() => null);
    const emails = body?.emails;
    if (!Array.isArray(emails)) {
      return jsonResponse({ error: "Body must be { emails: [...] }" }, 400);
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
      const detail = await groqRes.text();
      return jsonResponse({ error: "Groq API error", detail }, 502);
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
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
