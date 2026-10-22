// Workout sentences for the daily brief. Pure: the caller loads the rows.
// The best-set rule mirrors lib/features/fitness/domain/personal_best.dart.

export interface BriefSet {
  exercise_name: string;
  kind: string;
  reps: number | null;
  weight_kg: number | null;
  hold_seconds: number | null;
}

export type Units = "metric" | "imperial";

const KG_PER_LB = 0.45359237;
const WEEKDAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];
const DAY_MS = 86400000;
const MAX_NAMED_BESTS = 3;

export function setKey(s: { exercise_name: string; kind: string }): string {
  return `${s.kind}|${s.exercise_name}`;
}

// Whether a strictly beats b (same exercise and kind). Heavier wins, more reps
// break a tie, no weight counts as 0. Time sets: longest hold.
export function isBetterSet(a: BriefSet, b: BriefSet): boolean {
  if (a.kind === "time") return (a.hold_seconds ?? 0) > (b.hold_seconds ?? 0);
  const wa = a.weight_kg ?? 0;
  const wb = b.weight_kg ?? 0;
  if (wa !== wb) return wa > wb;
  return (a.reps ?? 0) > (b.reps ?? 0);
}

function trimmed(n: number, digits: number): string {
  return n.toFixed(digits).replace(/0+$/, "").replace(/\.$/, "");
}

export function describeSet(s: BriefSet, units: Units): string {
  if (s.kind === "time") return `${s.hold_seconds ?? 0}s`;
  const reps = s.reps ?? 0;
  const kg = s.weight_kg ?? 0;
  if (kg <= 0) return `${reps} reps`;
  return units === "imperial"
    ? `${trimmed(kg / KG_PER_LB, 1)} lb × ${reps}`
    : `${trimmed(kg, 2)} kg × ${reps}`;
}

// "Today", "yesterday" or "on Monday", by the caller's local calendar day.
function dayWord(startedAt: Date, now: Date, tzOffsetMinutes: number): string {
  const offsetMs = tzOffsetMinutes * 60000;
  const dayOf = (d: Date) => Math.floor((d.getTime() + offsetMs) / DAY_MS);
  const diff = dayOf(now) - dayOf(startedAt);
  if (diff <= 0) return "today";
  if (diff === 1) return "yesterday";
  return `on ${WEEKDAYS[new Date(startedAt.getTime() + offsetMs).getUTCDay()]}`;
}

// sets: the sets of the last session. priorBests: best earlier set per setKey.
export function fitnessSentences(opts: {
  dayTitle: string;
  startedAt: Date;
  sets: BriefSet[];
  priorBests: Map<string, BriefSet>;
  units: Units;
  tzOffsetMinutes: number;
  now: Date;
}): string[] {
  if (opts.sets.length === 0) return [];
  const out: string[] = [];
  const when = dayWord(opts.startedAt, opts.now, opts.tzOffsetMinutes);
  const count = opts.sets.length;
  out.push(
    `Your last workout was ${opts.dayTitle} ${when}, ${count} ${
      count === 1 ? "set" : "sets"
    }.`,
  );

  const best = new Map<string, BriefSet>();
  for (const s of opts.sets) {
    const cur = best.get(setKey(s));
    if (!cur || isBetterSet(s, cur)) best.set(setKey(s), s);
  }
  const bests: string[] = [];
  for (const [key, s] of best) {
    const prior = opts.priorBests.get(key);
    if (prior && isBetterSet(s, prior)) {
      bests.push(`${s.exercise_name} ${describeSet(s, opts.units)}`);
    }
  }
  if (bests.length > 0) {
    const named = bests.slice(0, MAX_NAMED_BESTS).join(", ");
    const more = bests.length - MAX_NAMED_BESTS;
    out.push(more > 0 ? `New best: ${named} and ${more} more.` : `New best: ${named}.`);
  }
  return out;
}
