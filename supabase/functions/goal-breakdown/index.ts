// Supabase Edge Function: goal-breakdown
//
// Given a goal (title, optional description, optional target date), asks
// Groq (Llama 3.3 70B) for an ordered list of 4-8 concrete, actionable,
// sequential tasks toward that goal. The AI is NOT asked for dates — this
// function computes each task's suggestedDueDate itself by spreading tasks
// evenly between today and the target date (or a 30-day horizon if no
// target date was given).
//
// Secrets: GROQ_API_KEY (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are
// auto-injected, but unused here — this function only needs the caller's
// JWT to confirm they're authenticated).

import { createClient } from "jsr:@supabase/supabase-js@2";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT =
  `You are a planning assistant that breaks a goal down into concrete next
steps. Given a goal's title and (optionally) a description, produce an
ORDERED list of 4 to 8 concrete, actionable, sequential tasks that move the
person toward that goal. Each task should be a single, specific action —
not vague ("make progress") and not a restatement of the goal itself. Order
them the way the person should actually do them, earliest/most foundational
first.

Do NOT include any dates or due-date hints — dates are computed separately.

Each task: {title (short imperative), description (one short sentence of
extra context, or null), priority (none|low|medium|high)}.

Respond with ONLY a JSON object of this exact form:
{"tasks":[{"title": string, "description": string|null, "priority": string}]}`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface RawTask {
  title?: string;
  description?: string | null;
  priority?: string;
}

/// Spreads [count] tasks evenly between today and [targetDate] (or a 30-day
/// horizon if [targetDate] is null), returning one ISO date string per task.
function computeSuggestedDueDates(count: number, targetDate: string | null): string[] {
  const start = new Date();
  const end = targetDate ? new Date(targetDate) : new Date(start.getTime() + 30 * 24 * 60 * 60 * 1000);

  const startMs = start.getTime();
  const endMs = end.getTime() > startMs ? end.getTime() : startMs + 24 * 60 * 60 * 1000;
  const span = endMs - startMs;

  const dates: string[] = [];
  for (let i = 0; i < count; i++) {
    // Spread evenly across (0, span], so the last task lands on/near the
    // target date and none land on "today" itself.
    const fraction = (i + 1) / count;
    dates.push(new Date(startMs + span * fraction).toISOString());
  }
  return dates;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GROQ_API_KEY) {
      return jsonResponse({ error: "GROQ_API_KEY is not configured." }, 500);
    }

    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null);
    const goalTitle = (body?.goalTitle as string | undefined)?.trim();
    const goalDescription = (body?.goalDescription as string | undefined)?.trim() || null;
    const targetDate = (body?.targetDate as string | undefined) || null;

    if (!goalTitle) {
      return jsonResponse({ error: "goalTitle is required" }, 400);
    }

    const userContent = goalDescription
      ? `Goal: ${goalTitle}\nDescription: ${goalDescription}`
      : `Goal: ${goalTitle}`;

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

    let parsed: { tasks?: RawTask[] };
    try {
      parsed = JSON.parse(content);
    } catch {
      return jsonResponse({ error: "Model returned invalid JSON", raw: content }, 502);
    }

    const rawTasks = Array.isArray(parsed.tasks) ? parsed.tasks : [];
    const suggestedDueDates = computeSuggestedDueDates(
      Math.max(rawTasks.length, 1),
      targetDate,
    );

    const tasks = rawTasks.map((t, i) => ({
      title: (t.title ?? "").trim(),
      description: t.description?.trim() || null,
      priority: (t.priority ?? "none").trim().toLowerCase(),
      suggestedDueDate: suggestedDueDates[i],
    })).filter((t) => t.title.length > 0);

    return jsonResponse({ tasks });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
