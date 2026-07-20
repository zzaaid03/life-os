// Supabase Edge Function: daily-brief
//
// Builds a warm, 2–3 sentence natural-language summary of the user's day:
// tasks due today/overdue, active job applications by status, and habit
// streaks. The caller is identified from their Supabase JWT; data is read
// server-side with the service role and only compact counts/titles are
// sent to Groq (llama-3.3-70b-versatile). Returns { brief: string }.
//
// Deploy:  npx supabase functions deploy daily-brief
// Secrets: GROQ_API_KEY (shared with extract-tasks);
//          SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are auto-injected.

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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const SYSTEM_PROMPT = `You write a short "daily brief" for a personal life
dashboard. Given compact JSON about the user's day (name, tasks due today or
overdue, job applications by status, habit streaks), respond with a warm,
encouraging 2-3 sentence summary in plain English. Mention the most important
numbers naturally (tasks due, standout job news like interviews or offers,
notable streaks). No emojis, no bullet points, no headings — just the
sentences. If everything is empty, gently invite them to plan their day.`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GROQ_API_KEY) {
      return jsonResponse({ error: "GROQ_API_KEY is not configured." }, 500);
    }

    // Identify the caller from their JWT.
    const jwt = (req.headers.get("Authorization") ?? "").replace(
      /^Bearer\s+/i,
      "",
    );
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }
    const userId = userData.user.id;
    const displayName =
      (userData.user.user_metadata?.display_name as string | undefined) ??
      (userData.user.user_metadata?.full_name as string | undefined) ??
      "";

    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    // Compact reads — counts and titles only, never bodies/contents.
    const [tasksRes, jobsRes, habitsRes, entriesRes] = await Promise.all([
      admin
        .from("tasks")
        .select("title, due_date, status")
        .eq("user_id", userId)
        .is("deleted_at", null)
        .neq("status", "completed")
        .neq("status", "archived"),
      admin
        .from("job_applications")
        .select("company, role, status")
        .eq("user_id", userId),
      admin
        .from("habits")
        .select("id, name")
        .eq("user_id", userId)
        .eq("is_archived", false)
        .is("deleted_at", null),
      admin
        .from("habit_entries")
        .select("habit_id, completed_date")
        .eq("user_id", userId)
        .is("deleted_at", null)
        .gte(
          "completed_date",
          new Date(Date.now() - 60 * 86400_000).toISOString().slice(0, 10),
        ),
    ]);

    const tasks = (tasksRes.data ?? []) as {
      title: string;
      due_date: string | null;
      status: string;
    }[];
    const dueToday = tasks.filter(
      (t) => t.due_date && new Date(t.due_date) <= todayEnd,
    );
    const undated = tasks.filter((t) => !t.due_date);

    const jobs = (jobsRes.data ?? []) as { status: string }[];
    const jobsByStatus: Record<string, number> = {};
    for (const j of jobs) {
      jobsByStatus[j.status] = (jobsByStatus[j.status] ?? 0) + 1;
    }

    // Current streak per habit (consecutive days ending today/yesterday).
    const habits = (habitsRes.data ?? []) as { id: string; name: string }[];
    const entries = (entriesRes.data ?? []) as {
      habit_id: string;
      completed_date: string;
    }[];
    const datesByHabit = new Map<string, Set<string>>();
    for (const e of entries) {
      if (!datesByHabit.has(e.habit_id)) datesByHabit.set(e.habit_id, new Set());
      datesByHabit.get(e.habit_id)!.add(e.completed_date);
    }
    const dayKey = (d: Date) => d.toISOString().slice(0, 10);
    const streaks = habits.map((h) => {
      const dates = datesByHabit.get(h.id) ?? new Set();
      const day = new Date();
      if (!dates.has(dayKey(day))) day.setDate(day.getDate() - 1);
      let streak = 0;
      while (dates.has(dayKey(day))) {
        streak += 1;
        day.setDate(day.getDate() - 1);
      }
      return { name: h.name, streak };
    });

    const summaryInput = {
      name: displayName,
      tasksDueTodayOrOverdue: dueToday.slice(0, 8).map((t) => t.title),
      tasksDueTodayOrOverdueCount: dueToday.length,
      unscheduledTaskCount: undated.length,
      jobApplicationsByStatus: jobsByStatus,
      habitStreaks: streaks.filter((s) => s.streak > 0).slice(0, 8),
      habitCount: habits.length,
    };

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
          temperature: 0.4,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: JSON.stringify(summaryInput) },
          ],
        }),
      },
    );

    if (!groqRes.ok) {
      return jsonResponse(
        { error: "Groq API error", detail: await groqRes.text() },
        502,
      );
    }

    const data = await groqRes.json();
    const brief = (data.choices?.[0]?.message?.content ?? "").trim();
    if (!brief) {
      return jsonResponse({ error: "empty_brief" }, 502);
    }

    return jsonResponse({ brief });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
