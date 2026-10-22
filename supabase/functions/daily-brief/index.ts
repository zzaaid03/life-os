// Supabase Edge Function: daily-brief
//
// Builds a deterministic, plain-sentence summary of the user's day: overdue
// tasks, tasks due today/soon, the single highest-priority open task, a
// company-matched cross-reference between standout job applications and the
// task list, and a completed-this-week count. Every sentence is assembled in
// TypeScript directly from the caller's own rows, no model is involved, so
// nothing is ever invented. The caller is identified from their Supabase
// JWT; data is read server-side with the service role. Returns
// { brief: string, noticed: string | null }. `noticed` is one AI-inferred
// user fact (from `user_facts`), rotated by local date; it is not part of
// the model-free brief guarantee above since it comes from a separate table.
//
// Deploy:  npx supabase functions deploy daily-brief
// Secrets: SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are auto-injected.

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { handlePreflight, jsonResponse, requireUser } from "../_shared/http.ts";
import {
  type BriefSet,
  fitnessSentences,
  setKey,
  type Units,
} from "./fitness.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// `priority` mirrors `TaskPriority` in lib/features/tasks/data/models/task.dart,
// stored as the enum index (0=none, 1=low, 2=medium, 3=high) in
// `tasks.priority`: a higher number is a higher priority, directly comparable.
interface OpenTask {
  id: string;
  title: string;
  due_date: string | null;
  priority: number;
  status: string;
}

interface CompletedTask {
  id: string;
  title: string;
  updated_at: string;
}

interface JobApplication {
  company: string;
  role: string;
  status: string;
  updated_at: string;
}

interface UserFact {
  category: string;
  fact: string;
}

const SET_COLUMNS = "exercise_name, kind, reps, weight_kg, hold_seconds";
const MAX_SESSION_SETS = 200;
const MAX_PRIOR_LOOKUPS = 15;

// The workout sentences for the last 7 days. A failed query logs and gives no
// sentences, so the rest of the brief still goes out.
async function loadFitnessSentences(
  admin: SupabaseClient,
  userId: string,
  now: Date,
  sevenDaysAgo: Date,
  tzOffsetMinutes: number,
): Promise<string[]> {
  try {
    const lastRes = await admin
      .from("workout_sets")
      .select("session_id, workout_sessions(day_title, started_at)")
      .eq("user_id", userId)
      .gte("logged_at", sevenDaysAgo.toISOString())
      .order("logged_at", { ascending: false })
      .limit(1);
    if (lastRes.error) throw lastRes.error;
    const last = lastRes.data?.[0] as
      | { session_id: string; workout_sessions: unknown }
      | undefined;
    if (!last) return [];
    const embedded = last.workout_sessions;
    const session = (Array.isArray(embedded) ? embedded[0] : embedded) as
      | { day_title: string; started_at: string }
      | undefined;
    if (!session) return [];

    const [setsRes, profileRes] = await Promise.all([
      admin
        .from("workout_sets")
        .select(SET_COLUMNS)
        .eq("user_id", userId)
        .eq("session_id", last.session_id)
        .limit(MAX_SESSION_SETS),
      admin
        .from("profiles")
        .select("unit_system")
        .eq("id", userId)
        .limit(1),
    ]);
    if (setsRes.error) throw setsRes.error;
    if (profileRes.error) throw profileRes.error;
    const sets = (setsRes.data ?? []) as BriefSet[];
    const units: Units = profileRes.data?.[0]?.unit_system === "imperial"
      ? "imperial"
      : "metric";

    const groups = new Map<string, BriefSet>();
    for (const s of sets) groups.set(setKey(s), s);
    const picked = [...groups.values()].slice(0, MAX_PRIOR_LOOKUPS);
    const priors = await Promise.all(picked.map(async (s) => {
      const q = admin
        .from("workout_sets")
        .select(SET_COLUMNS)
        .eq("user_id", userId)
        .eq("exercise_name", s.exercise_name)
        .eq("kind", s.kind)
        .lt("logged_at", session.started_at);
      const ordered = s.kind === "time"
        ? q.order("hold_seconds", { ascending: false, nullsFirst: false })
        : q
          .order("weight_kg", { ascending: false, nullsFirst: false })
          .order("reps", { ascending: false, nullsFirst: false });
      const res = await ordered.limit(1);
      if (res.error) throw res.error;
      return res.data?.[0] as BriefSet | undefined;
    }));
    const priorBests = new Map<string, BriefSet>();
    picked.forEach((s, i) => {
      const p = priors[i];
      if (p) priorBests.set(setKey(s), p);
    });

    return fitnessSentences({
      dayTitle: session.day_title,
      startedAt: new Date(session.started_at),
      sets,
      priorBests,
      units,
      tzOffsetMinutes,
      now,
    });
  } catch (e) {
    console.error("daily-brief: fitness sentences skipped", e);
    return [];
  }
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    // Identify the caller from their JWT.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const user = await requireUser(req, admin);
    if (user instanceof Response) return user;
    const userId = user.id;
    const displayName =
      (user.user_metadata?.display_name as string | undefined) ??
      (user.user_metadata?.full_name as string | undefined) ??
      "";
    const firstName = displayName.split(" ")[0] ?? "";

    // `due_date` is stored as the caller's local midnight converted to UTC
    // (e.g. local July 24 at UTC+2 is stored as 2026-07-23T22:00Z), so day
    // boundaries computed from raw UTC misclassify tasks near midnight. The
    // client sends its UTC offset in minutes; shift `now` by that offset,
    // take the UTC calendar date of the shifted instant (i.e. the caller's
    // local date), then shift back to get the true instant of local midnight.
    let tzOffsetMinutes = 0;
    try {
      const body = await req.json();
      const rawOffset = body?.tzOffsetMinutes;
      if (typeof rawOffset === "number" && Number.isFinite(rawOffset)) {
        tzOffsetMinutes = Math.max(-840, Math.min(840, rawOffset));
      }
    } catch {
      tzOffsetMinutes = 0;
    }

    const now = new Date();
    const offsetMs = tzOffsetMinutes * 60000;
    const shifted = new Date(now.getTime() + offsetMs);
    const day0Start = new Date(
      Date.UTC(
        shifted.getUTCFullYear(),
        shifted.getUTCMonth(),
        shifted.getUTCDate(),
      ) - offsetMs,
    );
    const day1Start = new Date(day0Start.getTime() + 24 * 60 * 60 * 1000);
    const day4Start = new Date(day0Start.getTime() + 4 * 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [openTasksRes, completedTasksRes, jobsRes, factsRes] =
      await Promise.all([
        admin
          .from("tasks")
          .select("id, title, due_date, priority, status")
          .eq("user_id", userId)
          .is("deleted_at", null)
          .neq("status", "completed")
          .neq("status", "archived"),
        admin
          .from("tasks")
          .select("id, title, updated_at")
          .eq("user_id", userId)
          .is("deleted_at", null)
          .eq("status", "completed")
          .gte("updated_at", thirtyDaysAgo.toISOString()),
        admin
          .from("job_applications")
          .select("company, role, status, updated_at")
          .eq("user_id", userId),
        admin
          .from("user_facts")
          .select("category, fact")
          .eq("user_id", userId)
          .is("suppressed_at", null)
          .order("last_confirmed_at", { ascending: false })
          .limit(15),
      ]);

    const openTasks = (openTasksRes.data ?? []) as OpenTask[];
    const completedTasks = (completedTasksRes.data ?? []) as CompletedTask[];
    const jobs = (jobsRes.data ?? []) as JobApplication[];
    const facts = (factsRes.error ? [] : factsRes.data ?? []) as UserFact[];

    // Rotate deterministically by the caller's local date so it isn't the
    // same fact every day, without needing any extra state.
    const dayNumber = Math.floor(day0Start.getTime() / 86400000);
    const noticed = facts.length > 0
      ? facts[dayNumber % facts.length].fact
      : null;

    const overdue = openTasks.filter(
      (t) => t.due_date && new Date(t.due_date) < day0Start,
    );
    const dueToday = openTasks.filter(
      (t) =>
        t.due_date &&
        new Date(t.due_date) >= day0Start &&
        new Date(t.due_date) < day1Start,
    );
    const dueSoon = openTasks.filter(
      (t) =>
        t.due_date &&
        new Date(t.due_date) >= day1Start &&
        new Date(t.due_date) < day4Start,
    );

    // Highest-priority open task, tie-broken by earliest due date (tasks
    // with no due date sort last within the same priority).
    let nextUp: OpenTask | null = null;
    for (const t of openTasks) {
      if (!nextUp) {
        nextUp = t;
        continue;
      }
      if (t.priority > nextUp.priority) {
        nextUp = t;
        continue;
      }
      if (t.priority === nextUp.priority) {
        const tDue = t.due_date
          ? new Date(t.due_date).getTime()
          : Number.POSITIVE_INFINITY;
        const nextDue = nextUp.due_date
          ? new Date(nextUp.due_date).getTime()
          : Number.POSITIVE_INFINITY;
        if (tDue < nextDue) nextUp = t;
      }
    }

    const completedThisWeek = completedTasks.filter(
      (t) => new Date(t.updated_at) >= sevenDaysAgo,
    ).length;

    const standoutJobs = jobs
      .filter(
        (j) =>
          (j.status === "interview" || j.status === "accepted") &&
          new Date(j.updated_at) >= fourteenDaysAgo,
      )
      .sort(
        (a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime(),
      )
      .slice(0, 3);

    const sentences: string[] = [];

    if (overdue.length > 0) {
      const titles = overdue.slice(0, 3).map((t) => t.title).join(", ");
      sentences.push(
        overdue.length === 1
          ? `You have 1 overdue task: ${titles}.`
          : `You have ${overdue.length} overdue tasks: ${titles}.`,
      );
    }

    if (dueToday.length > 0) {
      sentences.push(
        dueToday.length === 1
          ? "1 task is due today."
          : `${dueToday.length} tasks are due today.`,
      );
    }

    if (dueSoon.length > 0) {
      sentences.push(
        dueSoon.length === 1
          ? "1 task is due in the next few days."
          : `${dueSoon.length} tasks are due in the next few days.`,
      );
    }

    if (nextUp) {
      sentences.push(`Your top priority is "${nextUp.title}".`);
    }

    for (const job of standoutJobs) {
      const companyLower = job.company.toLowerCase();
      const openMatch = openTasks.find((t) =>
        t.title.toLowerCase().includes(companyLower)
      );
      const completedMatch = completedTasks.find((t) =>
        t.title.toLowerCase().includes(companyLower)
      );
      if (openMatch) {
        sentences.push(
          `${job.company}: ${job.status} stage. Next step: ${openMatch.title}.`,
        );
      } else if (completedMatch) {
        sentences.push(
          `${job.company}: ${job.status} stage. Your last step (${completedMatch.title}) is done, nothing open.`,
        );
      } else {
        sentences.push(`${job.company}: ${job.status} stage. No task is tracking it.`);
      }
    }

    const hasNothingToReport =
      overdue.length === 0 &&
      dueToday.length === 0 &&
      dueSoon.length === 0 &&
      standoutJobs.length === 0;

    const fitness = await loadFitnessSentences(
      admin,
      userId,
      now,
      sevenDaysAgo,
      tzOffsetMinutes,
    );

    if (hasNothingToReport) {
      const line = firstName
        ? `${firstName}, nothing needs your attention today.`
        : "Nothing needs your attention today.";
      const brief = [line, ...fitness].join(" ");
      return jsonResponse(req, { brief, noticed });
    }

    if (completedThisWeek > 0) {
      sentences.push(
        completedThisWeek === 1
          ? "You completed 1 task this week."
          : `You completed ${completedThisWeek} tasks this week.`,
      );
    }

    sentences.push(...fitness);
    let brief = sentences.join(" ");
    if (firstName) {
      brief = `${firstName}, ${brief.charAt(0).toLowerCase()}${brief.slice(1)}`;
    }

    return jsonResponse(req, { brief, noticed });
  } catch (e) {
    return jsonResponse(req, { error: String(e) }, 500);
  }
});
