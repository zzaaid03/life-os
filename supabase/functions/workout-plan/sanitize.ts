// Turns the model's raw plan JSON into the shape save_generated_workout_plan
// (migration 033) accepts. The CHECK constraints there are the last line of
// defence; this makes sure a bad model reply is repaired or rejected here
// instead of failing the whole save.

export type PlanExercise = {
  name: string;
  kind: "reps" | "time";
  sets: number;
  reps_min: number | null;
  reps_max: number | null;
  hold_seconds: number | null;
  rest_seconds: number;
  note: string | null;
};

export type PlanDay = { title: string; exercises: PlanExercise[] };

export type SanitizedPlan = { name: string; days: PlanDay[] };

const MAX_EXERCISES_PER_DAY = 20;

function text(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max).trim() : "";
}

// A finite number rounded to an integer and clamped, or null if it is not a number.
function int(v: unknown, min: number, max: number): number | null {
  const n = typeof v === "string" && v.trim() !== "" ? Number(v) : v;
  if (typeof n !== "number" || !Number.isFinite(n)) return null;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function sanitizeExercise(raw: unknown): PlanExercise | null {
  if (typeof raw !== "object" || raw === null) return null;
  const e = raw as Record<string, unknown>;

  const name = text(e.name, 60);
  if (!name) return null;
  if (e.kind !== "reps" && e.kind !== "time") return null;

  const sets = int(e.sets, 1, 10);
  const rest = int(e.rest_seconds, 0, 600);
  if (sets === null || rest === null) return null;

  const note = text(e.note, 140) || null;

  if (e.kind === "reps") {
    let min = int(e.reps_min, 1, 50);
    let max = int(e.reps_max, 1, 50);
    // One end of the range is enough: use it for both.
    if (min === null && max === null) return null;
    if (min === null) min = max;
    if (max === null) max = min;
    if (min! > max!) [min, max] = [max, min];
    return {
      name,
      kind: "reps",
      sets,
      reps_min: min,
      reps_max: max,
      hold_seconds: null,
      rest_seconds: rest,
      note,
    };
  }

  const hold = int(e.hold_seconds, 5, 300);
  if (hold === null) return null;
  return {
    name,
    kind: "time",
    sets,
    reps_min: null,
    reps_max: null,
    hold_seconds: hold,
    rest_seconds: rest,
    note,
  };
}

export function sanitizePlan(
  raw: unknown,
  daysPerWeek: number,
): SanitizedPlan | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  if (!Array.isArray(r.days) || r.days.length !== daysPerWeek) return null;

  const days: PlanDay[] = [];
  for (const rawDay of r.days) {
    if (typeof rawDay !== "object" || rawDay === null) return null;
    const d = rawDay as Record<string, unknown>;
    const title = text(d.title, 40);
    if (!title) return null;

    const exercises = (Array.isArray(d.exercises) ? d.exercises : [])
      .map(sanitizeExercise)
      .filter((e): e is PlanExercise => e !== null)
      .slice(0, MAX_EXERCISES_PER_DAY);
    if (exercises.length === 0) return null;

    days.push({ title, exercises });
  }

  return { name: text(r.name, 60) || "My plan", days };
}
