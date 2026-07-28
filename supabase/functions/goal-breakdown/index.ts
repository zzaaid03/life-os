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

You may be given an "About this person" context block describing their real
job applications, open tasks, recently completed tasks, and other goals.

WHEN THAT BLOCK IS PRESENT, USING IT IS THE MOST IMPORTANT PART OF THIS
TASK. Generic advice that ignores it is a failure. Work through it like
this:

1. First decide which facts in the block are actually relevant to THIS
   goal. Most facts will not be. That is expected.
2. For every relevant fact, the task you write must account for it instead
   of giving the textbook answer. If the block shows they already have
   something, do not tell them to go get it. If it shows they already did
   something, do not tell them to do it again. If it shows a specific
   field, tool, employer or constraint, name that specific thing rather
   than the general category.
3. Never force an irrelevant fact in. Twisting an unrelated detail into a
   task is worse than leaving it out. If nothing in the block is relevant,
   write the best general plan you can and return an empty usedContext.
4. Never invent facts beyond what the block states, never quote the block
   back at them, and never reveal that you were given it. Do not produce a
   task that duplicates one of their existing open tasks.

Each task: {title (short imperative), description (one short sentence of
extra context, or null), priority (none|low|medium|high)}.

Also return usedContext: an array of the specific facts from the block that
you actually let change a task. Quote each fact briefly. Return an empty
array if the block was absent or nothing in it was relevant. Be honest
here: list only facts that genuinely changed what you wrote.

Respond with ONLY a JSON object of this exact form:
{"usedContext": string[], "tasks":[{"title": string, "description": string|null, "priority": string}]}`;

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

function truncate(s: string, max = 80): string {
  const t = s.trim();
  return t.length > max ? t.slice(0, max) : t;
}

/// Assembles a plain-text "About this person" context block from the
/// caller's own rows, for tailoring the goal breakdown. Returns "" if
/// there's nothing to say (all four lists empty).
function buildContextBlock(
  openTasks: { title?: string | null }[],
  openTasksCount: number,
  completedTasks: { title?: string | null }[],
  completedTasksCount: number,
  jobApps: { company?: string | null; role?: string | null; status?: string | null }[],
  jobAppsCount: number,
  otherGoals: { title?: string | null; status?: string | null }[],
  userFacts: { category?: string | null; fact?: string | null }[],
): string {
  const lines: string[] = [];

  if (jobApps.length > 0) {
    const items = jobApps
      .slice(0, 15)
      .map((j) => {
        const company = truncate(j.company ?? "Unknown");
        const role = j.role ? ` - ${truncate(j.role, 40)}` : "";
        const status = j.status ? ` (${truncate(j.status, 20)})` : "";
        return `${company}${role}${status}`;
      })
      .filter((s) => s.length > 0);
    if (items.length > 0) {
      lines.push(
        `Currently tracking ${jobAppsCount} job application${jobAppsCount === 1 ? "" : "s"}: ${items.join(", ")}`,
      );
    }
  }

  if (openTasks.length > 0) {
    const examples = openTasks
      .slice(0, 6)
      .map((t) => truncate(t.title ?? ""))
      .filter((s) => s.length > 0);
    if (examples.length > 0) {
      lines.push(
        `They have ${openTasksCount} open task${openTasksCount === 1 ? "" : "s"}. Recent examples: ${examples.join(", ")}`,
      );
    }
  }

  if (completedTasksCount > 0) {
    lines.push(
      `They completed ${completedTasksCount} task${completedTasksCount === 1 ? "" : "s"} in the last 30 days.`,
    );
  }

  if (otherGoals.length > 0) {
    const examples = otherGoals
      .slice(0, 5)
      .map((g) => truncate(g.title ?? ""))
      .filter((s) => s.length > 0);
    if (examples.length > 0) {
      lines.push(`Their other active goals: ${examples.join(", ")}`);
    }
  }

  if (userFacts.length > 0) {
    const examples = userFacts
      .slice(0, 15)
      .map((f) => truncate(f.fact ?? ""))
      .filter((s) => s.length > 0);
    if (examples.length > 0) {
      lines.push(`Known facts about them: ${examples.join(", ")}`);
    }
  }

  if (lines.length === 0) return "";

  let block = "About this person, for tailoring only:\n" + lines.join("\n");
  if (block.length > 2000) {
    const kept = block.slice(0, 2000).split("\n");
    kept.pop(); // drop a possibly-partial trailing line
    block = kept.join("\n");
  }
  return block;
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

    const userId = userData.user.id;
    const thirtyDaysAgoIso = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [openTasksRes, completedTasksRes, jobAppsRes, otherGoalsRes, userFactsRes] = await Promise.all([
      admin
        .from("tasks")
        .select("title", { count: "exact" })
        .eq("user_id", userId)
        .is("deleted_at", null)
        .neq("status", "completed")
        .neq("status", "archived")
        .order("created_at", { ascending: false })
        .limit(20),
      admin
        .from("tasks")
        .select("title", { count: "exact" })
        .eq("user_id", userId)
        .is("deleted_at", null)
        .eq("status", "completed")
        .gte("updated_at", thirtyDaysAgoIso)
        .limit(50),
      admin
        .from("job_applications")
        .select("company, role, status", { count: "exact" })
        .eq("user_id", userId)
        .order("updated_at", { ascending: false })
        .limit(15),
      admin
        .from("goals")
        .select("title, status")
        .eq("user_id", userId)
        .is("deleted_at", null)
        .neq("status", "archived")
        .limit(10),
      admin
        .from("user_facts")
        .select("category, fact")
        .eq("user_id", userId)
        .is("suppressed_at", null)
        .order("last_confirmed_at", { ascending: false })
        .limit(15),
    ]);

    const openTasks = openTasksRes.data ?? [];
    const completedTasks = completedTasksRes.data ?? [];
    const jobApps = jobAppsRes.data ?? [];
    // Exclude the goal being broken down right now (it may already be saved),
    // so "their other active goals" doesn't list this same goal back.
    const otherGoals = (otherGoalsRes.data ?? []).filter(
      (g) => (g.title ?? "").trim().toLowerCase() !== goalTitle.toLowerCase(),
    );
    const userFacts = userFactsRes.data ?? [];

    const contextBlock = buildContextBlock(
      openTasks,
      openTasksRes.count ?? openTasks.length,
      completedTasks,
      completedTasksRes.count ?? completedTasks.length,
      jobApps,
      jobAppsRes.count ?? jobApps.length,
      otherGoals,
      userFacts,
    );

    const baseUserContent = goalDescription
      ? `Goal: ${goalTitle}\nDescription: ${goalDescription}`
      : `Goal: ${goalTitle}`;

    // The context block goes AFTER the goal on purpose. It used to lead, and
    // the model reliably ignored it: given "Pay outstanding balance to McFIT"
    // and a fitness goal, it still answered "research local gyms". Putting it
    // last places it closest to the point of generation.
    const userContent = contextBlock
      ? `${baseUserContent}\n\n${contextBlock}`
      : baseUserContent;

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

    let parsed: { tasks?: RawTask[]; usedContext?: unknown };
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

    // Diagnostic echo. The context block is assembled from the caller's own
    // rows and is returned only to that same caller, so nothing leaks. This
    // exists because a failed context query degrades silently to an omitted
    // section — without it, "the model had no data" and "the queries returned
    // nothing" are indistinguishable from the UI.
    return jsonResponse({
      tasks,
      context: {
        block: contextBlock,
        blockLength: contextBlock.length,
        // What the model claims it actually let change a task. A populated
        // block with an empty usedContext is the failure this prompt was
        // rewritten to fix, and it is only visible because it is echoed here.
        usedContext: Array.isArray(parsed.usedContext)
          ? parsed.usedContext.filter((f): f is string => typeof f === 'string')
          : [],
        openTasksCount: openTasksRes.count ?? 0,
        completedTasksCount: completedTasksRes.count ?? 0,
        jobAppsCount: jobAppsRes.count ?? 0,
        otherGoalsCount: otherGoals.length,
        queryErrors: {
          openTasks: openTasksRes.error?.message ?? null,
          completedTasks: completedTasksRes.error?.message ?? null,
          jobApps: jobAppsRes.error?.message ?? null,
          otherGoals: otherGoalsRes.error?.message ?? null,
          userFacts: userFactsRes.error?.message ?? null,
        },
      },
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
