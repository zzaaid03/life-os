import { assertEquals } from "jsr:@std/assert@1";
import { sanitizePlan } from "./sanitize.ts";

const goodDay = {
  title: "Push",
  exercises: [
    {
      name: "Push-up",
      kind: "reps",
      sets: 3,
      reps_min: 8,
      reps_max: 12,
      hold_seconds: null,
      rest_seconds: 90,
      note: "Keep your body in one line",
    },
    {
      name: "Plank",
      kind: "time",
      sets: 3,
      reps_min: null,
      reps_max: null,
      hold_seconds: 45,
      rest_seconds: 60,
      note: "",
    },
  ],
};

Deno.test("a good plan passes through", () => {
  const plan = sanitizePlan({ name: "Home plan", days: [goodDay, goodDay] }, 2);
  assertEquals(plan?.name, "Home plan");
  assertEquals(plan?.days.length, 2);
  assertEquals(plan?.days[0].exercises[0].reps_max, 12);
  assertEquals(plan?.days[0].exercises[1].note, null);
});

Deno.test("values are clamped and the plan name falls back", () => {
  const plan = sanitizePlan({
    name: "   ",
    days: [{
      title: "x".repeat(80),
      exercises: [{
        name: "Squat",
        kind: "reps",
        sets: 99,
        reps_min: 80,
        reps_max: 0,
        rest_seconds: 9999,
        note: "n".repeat(300),
      }, {
        name: "Wall sit",
        kind: "time",
        sets: 0,
        hold_seconds: 1,
        rest_seconds: -5,
      }],
    }],
  }, 1);
  assertEquals(plan?.name, "My plan");
  assertEquals(plan?.days[0].title.length, 40);
  const [squat, wall] = plan!.days[0].exercises;
  assertEquals(squat.sets, 10);
  assertEquals(squat.reps_min, 1);
  assertEquals(squat.reps_max, 50);
  assertEquals(squat.rest_seconds, 600);
  assertEquals(squat.note?.length, 140);
  assertEquals(wall.sets, 1);
  assertEquals(wall.hold_seconds, 5);
  assertEquals(wall.rest_seconds, 0);
});

Deno.test("kind and field mismatches are repaired", () => {
  const plan = sanitizePlan({
    name: "Mix",
    days: [{
      title: "Day",
      exercises: [
        // reps row that also carries a hold
        {
          name: "Curl",
          kind: "reps",
          sets: 3,
          reps_min: 10,
          reps_max: 12,
          hold_seconds: 30,
          rest_seconds: 60,
        },
        // time row that also carries reps
        {
          name: "Hollow hold",
          kind: "time",
          sets: 3,
          reps_min: 5,
          reps_max: 8,
          hold_seconds: 20,
          rest_seconds: 60,
        },
        // unrepairable: reps row with no reps at all
        { name: "Lunge", kind: "reps", sets: 3, rest_seconds: 60 },
      ],
    }],
  }, 1);
  const ex = plan!.days[0].exercises;
  assertEquals(ex.length, 2);
  assertEquals(ex[0].hold_seconds, null);
  assertEquals(ex[1].reps_min, null);
  assertEquals(ex[1].reps_max, null);
  assertEquals(ex[1].hold_seconds, 20);
});

Deno.test("a wrong day count gives null", () => {
  assertEquals(sanitizePlan({ name: "P", days: [goodDay] }, 3), null);
  assertEquals(sanitizePlan({ name: "P", days: [goodDay, goodDay] }, 1), null);
});

Deno.test("a day with no usable exercises gives null", () => {
  assertEquals(
    sanitizePlan({
      name: "P",
      days: [goodDay, { title: "Empty", exercises: [] }],
    }, 2),
    null,
  );
  assertEquals(
    sanitizePlan({
      name: "P",
      days: [{ title: "Bad", exercises: [{ name: "", kind: "reps" }] }],
    }, 1),
    null,
  );
});
