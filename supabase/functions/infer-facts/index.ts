// Supabase Edge Function: infer-facts
//
// Reads the caller's own tasks, goals, job applications and file notes,
// asks Groq for durable facts that are traceable to real rows, validates
// every returned fact, and upserts survivors into public.user_facts keyed
// on (user_id, fact_key). Never touches suppressed_at or first_seen_at on
// conflict — those are how a user's rejection of a wrong fact stays
// permanent. Below a sparse-data floor, writes nothing and calls no model.
//
// Deploy:  npx supabase functions deploy infer-facts --workdir . --project-ref ganbmkphtzdvxxnmprku
// Secrets: GROQ_API_KEY (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are auto-injected).

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
  `You infer durable facts about a person from their own app data. You will be shown their tasks, goals, job applications and file notes.

Return JSON only: {"facts":[{"category":"...","fact":"...","evidence":"..."}]}

Rules, in order of importance:
1. Every fact MUST be supported by specific rows in the data shown. In "evidence", quote or name the actual rows that support it. If you cannot point at real rows, do not return the fact.
2. Return AT MOST 8 facts. Returning 2 well-supported facts is a success. Returning 8 by padding with guesses is a failure.
3. If the data does not support any durable fact, return {"facts":[]}. This is a valid and correct answer.
4. "category" must be exactly one of: routine, preference, situation, constraint.
   routine = when they actually do things. preference = how they like to work.
   situation = what is currently true of their life. constraint = what they avoid or cannot do.
5. A fact is one short sentence, under 200 characters, written in the second person ("You usually..."). It must be something that stays true for weeks, not a restatement of a single row.
6. Never infer anything about health, religion, politics, sexuality, or finances beyond what a task literally says.`;

const VALID_CATEGORIES = new Set([
  "routine",
  "preference",
  "situation",
  "constraint",
]);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function toFactKey(fact: string): string {
  return fact
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 200);
}

interface CompletedTaskRow {
  title: string;
  updated_at: string;
}

interface OpenTaskRow {
  title: string;
  due_date: string | null;
}

interface JobAppRow {
  company: string;
  status: string;
}

interface GoalRow {
  title: string;
}

interface FileNoteRow {
  user_note: string;
}

interface QueryErrors {
  completedTasks?: string;
  openTasks?: string;
  jobApps?: string;
  goals?: string;
  fileNotes?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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

    const ninetyDaysAgo = new Date(
      Date.now() - 90 * 24 * 60 * 60 * 1000,
    ).toISOString();

    const queryErrors: QueryErrors = {};

    let completedTasksCount = 0;
    let completedTasks: CompletedTaskRow[] = [];
    {
      const res = await admin
        .from("tasks")
        .select("title, updated_at", { count: "exact" })
        .eq("user_id", userId)
        .is("deleted_at", null)
        .eq("status", "completed")
        .gte("updated_at", ninetyDaysAgo)
        .order("created_at", { ascending: false })
        .limit(40);
      if (res.error) {
        queryErrors.completedTasks = res.error.message;
      } else {
        completedTasksCount = res.count ?? res.data?.length ?? 0;
        completedTasks = (res.data ?? []) as CompletedTaskRow[];
      }
    }

    let openTasksCount = 0;
    let openTasks: OpenTaskRow[] = [];
    {
      const res = await admin
        .from("tasks")
        .select("title, due_date", { count: "exact" })
        .eq("user_id", userId)
        .is("deleted_at", null)
        .neq("status", "completed")
        .neq("status", "archived")
        .order("created_at", { ascending: false })
        .limit(20);
      if (res.error) {
        queryErrors.openTasks = res.error.message;
      } else {
        openTasksCount = res.count ?? res.data?.length ?? 0;
        openTasks = (res.data ?? []) as OpenTaskRow[];
      }
    }

    let jobAppsCount = 0;
    let jobApps: JobAppRow[] = [];
    {
      const res = await admin
        .from("job_applications")
        .select("company, status", { count: "exact" })
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(20);
      if (res.error) {
        queryErrors.jobApps = res.error.message;
      } else {
        jobAppsCount = res.count ?? res.data?.length ?? 0;
        jobApps = (res.data ?? []) as JobAppRow[];
      }
    }

    let goalsCount = 0;
    let goals: GoalRow[] = [];
    {
      const res = await admin
        .from("goals")
        .select("title", { count: "exact" })
        .eq("user_id", userId)
        .is("deleted_at", null)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(10);
      if (res.error) {
        queryErrors.goals = res.error.message;
      } else {
        goalsCount = res.count ?? res.data?.length ?? 0;
        goals = (res.data ?? []) as GoalRow[];
      }
    }

    let fileNotesCount = 0;
    let fileNotes: FileNoteRow[] = [];
    {
      const res = await admin
        .from("user_files")
        .select("user_note", { count: "exact" })
        .eq("user_id", userId)
        .eq("is_private", false)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(20);
      if (res.error) {
        queryErrors.fileNotes = res.error.message;
      } else {
        fileNotesCount = res.count ?? res.data?.length ?? 0;
        fileNotes = (res.data ?? [])
          .filter((r: { user_note: string | null }) => !!r.user_note) as FileNoteRow[];
      }
    }

    const evidenceCounts = {
      completedTasks: completedTasksCount,
      openTasks: openTasksCount,
      jobApps: jobAppsCount,
      goals: goalsCount,
      fileNotes: fileNotesCount,
    };

    const totalGathered =
      completedTasks.length +
      openTasks.length +
      jobApps.length +
      goals.length +
      fileNotes.length;

    if (totalGathered < 5) {
      return jsonResponse({
        written: 0,
        skipped: 0,
        reason: "not_enough_data",
        evidenceCounts,
      });
    }

    const lines: string[] = [];
    if (completedTasks.length > 0) {
      lines.push("Completed tasks (last 90 days):");
      for (const t of completedTasks) {
        lines.push(`- "${t.title}" completed ${t.updated_at}`);
      }
    }
    if (openTasks.length > 0) {
      lines.push("Open tasks:");
      for (const t of openTasks) {
        lines.push(`- "${t.title}" due ${t.due_date ?? "no due date"}`);
      }
    }
    if (jobApps.length > 0) {
      lines.push("Job applications:");
      for (const j of jobApps) {
        lines.push(`- ${j.company} (${j.status})`);
      }
    }
    if (goals.length > 0) {
      lines.push("Active goals:");
      for (const g of goals) {
        lines.push(`- "${g.title}"`);
      }
    }
    if (fileNotes.length > 0) {
      lines.push("File notes:");
      for (const f of fileNotes) {
        lines.push(`- "${f.user_note}"`);
      }
    }
    const contextBlock = lines.join("\n");

    if (!GROQ_API_KEY) {
      return jsonResponse({ error: "GROQ_API_KEY is not configured." }, 500);
    }

    interface RawFact {
      category?: unknown;
      fact?: unknown;
      evidence?: unknown;
    }

    let rawFacts: RawFact[] = [];
    try {
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
              { role: "user", content: contextBlock },
            ],
          }),
        },
      );

      if (groqRes.ok) {
        const data = await groqRes.json();
        const content = data.choices?.[0]?.message?.content ?? "{}";
        const parsed = JSON.parse(content);
        if (Array.isArray(parsed.facts)) {
          rawFacts = parsed.facts;
        }
      }
    } catch {
      rawFacts = [];
    }

    let dropped = 0;
    const validFacts: { category: string; fact: string; evidence: string; factKey: string }[] = [];

    for (const rf of rawFacts.slice(0, 8)) {
      const category = typeof rf.category === "string" ? rf.category : "";
      const fact = typeof rf.fact === "string" ? rf.fact : "";
      const evidence = typeof rf.evidence === "string" ? rf.evidence : "";

      if (!VALID_CATEGORIES.has(category)) {
        dropped++;
        continue;
      }
      if (fact.length === 0 || fact.length > 200) {
        dropped++;
        continue;
      }
      if (evidence.length === 0 || evidence.length > 400) {
        dropped++;
        continue;
      }

      const factKey = toFactKey(fact);
      if (factKey.length === 0) {
        dropped++;
        continue;
      }

      validFacts.push({ category, fact, evidence, factKey });
    }

    let written = 0;
    for (const vf of validFacts) {
      const { data: existing } = await admin
        .from("user_facts")
        .select("id")
        .eq("user_id", userId)
        .eq("fact_key", vf.factKey)
        .maybeSingle();

      if (existing) {
        const { error } = await admin
          .from("user_facts")
          .update({
            category: vf.category,
            fact: vf.fact,
            evidence: vf.evidence,
            last_confirmed_at: new Date().toISOString(),
          })
          .eq("id", existing.id);
        if (!error) written++;
      } else {
        const { error } = await admin.from("user_facts").insert({
          user_id: userId,
          category: vf.category,
          fact: vf.fact,
          evidence: vf.evidence,
          fact_key: vf.factKey,
        });
        if (!error) written++;
      }
    }

    return jsonResponse({
      written,
      dropped,
      reason: "ok",
      blockLength: contextBlock.length,
      evidenceCounts,
      queryErrors,
    });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
