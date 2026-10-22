import { assertEquals } from "jsr:@std/assert";
import { type BriefSet, fitnessSentences, setKey } from "./fitness.ts";

const bench = (kg: number, reps: number): BriefSet => ({
  exercise_name: "Bench press",
  kind: "reps",
  reps,
  weight_kg: kg,
  hold_seconds: null,
});

const now = new Date("2026-10-22T10:00:00Z");

function run(
  sets: BriefSet[],
  priors: BriefSet[],
  over: { units?: "metric" | "imperial"; startedAt?: Date; tz?: number } = {},
) {
  return fitnessSentences({
    dayTitle: "Push",
    startedAt: over.startedAt ?? new Date("2026-10-21T09:00:00Z"),
    sets,
    priorBests: new Map(priors.map((p) => [setKey(p), p])),
    units: over.units ?? "metric",
    tzOffsetMinutes: over.tz ?? 0,
    now,
  });
}

Deno.test("empty session gives nothing", () => {
  assertEquals(run([], []), []);
});

Deno.test("yesterday, kg, new best", () => {
  assertEquals(run([bench(62.5, 8), bench(60, 8)], [bench(60, 8)]), [
    "Your last workout was Push yesterday, 2 sets.",
    "New best: Bench press 62.5 kg × 8.",
  ]);
});

Deno.test("today and lb", () => {
  const out = run([bench(100, 5)], [bench(90, 5)], {
    units: "imperial",
    startedAt: new Date("2026-10-22T08:00:00Z"),
  });
  assertEquals(out, [
    "Your last workout was Push today, 1 set.",
    "New best: Bench press 220.5 lb × 5.",
  ]);
});

Deno.test("local day uses the offset", () => {
  // 23:30 UTC on the 21st is already the 22nd at UTC+2.
  const out = run([bench(50, 5)], [], {
    startedAt: new Date("2026-10-21T23:30:00Z"),
    tz: 120,
  });
  assertEquals(out, ["Your last workout was Push today, 1 set."]);
});

Deno.test("older sessions use the weekday", () => {
  const out = run([bench(50, 5)], [], {
    startedAt: new Date("2026-10-19T09:00:00Z"),
  });
  assertEquals(out, ["Your last workout was Push on Monday, 1 set."]);
});

Deno.test("first log and equal sets are not a best", () => {
  assertEquals(run([bench(60, 8)], []).length, 1);
  assertEquals(run([bench(60, 8)], [bench(60, 8)]).length, 1);
});

Deno.test("more than three bests ends with and N more", () => {
  const names = ["A", "B", "C", "D", "E"];
  const mk = (n: string, hold: number): BriefSet => ({
    exercise_name: n,
    kind: "time",
    reps: null,
    weight_kg: null,
    hold_seconds: hold,
  });
  const out = run(names.map((n) => mk(n, 60)), names.map((n) => mk(n, 30)));
  assertEquals(out[1], "New best: A 60s, B 60s, C 60s and 2 more.");
});
