// Supabase Edge Function: daily-brief
//
// Builds a warm, 2–3 sentence natural-language summary of the user's day:
// tasks due today/overdue and active job applications by status. The caller
// is identified from their Supabase JWT; data is read server-side with the
// service role and only compact counts/titles are sent to Groq
// (llama-3.3-70b-versatile). Returns { brief: string }.
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

const SYSTEM_PROMPT = `You write a personal "daily brief" for the user's life dashboard. You receive compact JSON about their day: their first name, the count and titles of tasks due today or overdue, the count of unscheduled tasks, job applications grouped by status, and "standout" job updates (interviews, acceptances, rejections) with the company name. Write 2-3 warm, natural sentences that are SPECIFIC to this exact data: cite the real number of tasks due today/overdue and name at least one actual task title when there are any; if there are standout job updates, name the company (e.g. "your interview at Acme"); address them by first name if one is provided. Never invent anything not in the data. Never use generic motivational filler, clichés, or hype ("seize the day", "you've got this", "make it count", "crush your goals"). If every list and count is empty, warmly invite them to plan their day. No emojis, no bullet points, no headings — just the sentences.`;

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
    const [tasksRes, jobsRes] = await Promise.all([
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

    const jobs = (jobsRes.data ?? []) as {
      company: string;
      role: string;
      status: string;
    }[];
    const jobsByStatus: Record<string, number> = {};
    for (const j of jobs) {
      jobsByStatus[j.status] = (jobsByStatus[j.status] ?? 0) + 1;
    }

    const standoutJobs = jobs
      .filter(
        (j) =>
          ["interview", "accepted", "rejected"].includes(j.status) &&
          j.company,
      )
      .map((j) => ({ company: j.company, role: j.role, status: j.status }))
      .slice(0, 6);

    const summaryInput = {
      name: displayName.split(" ")[0] ?? "",
      tasksDueTodayOrOverdue: dueToday.slice(0, 8).map((t) => t.title),
      tasksDueTodayOrOverdueCount: dueToday.length,
      unscheduledTaskCount: undated.length,
      jobApplicationsByStatus: jobsByStatus,
      standoutJobs,
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
          temperature: 0.3,
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
