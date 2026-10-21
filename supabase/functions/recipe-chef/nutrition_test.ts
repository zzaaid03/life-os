import { assertEquals } from "jsr:@std/assert";
import { nutritionPerServing } from "./nutrition.ts";

const eggs = {
  amount: 3,
  grams: 150,
  per100g: { kcal: 140, protein: 12, carbs: 1, fat: 10 },
};
const feta = {
  amount: 30,
  grams: 30,
  per100g: { kcal: 260, protein: 14, carbs: 4, fat: 21 },
};

Deno.test("sums grams times per100g and rounds", () => {
  // eggs: 210 kcal, 18 p, 1.5 c, 15 f. feta: 78 kcal, 4.2 p, 1.2 c, 6.3 f.
  assertEquals(nutritionPerServing([eggs, feta], 1), {
    kcal: 288,
    protein: 22,
    carbs: 3,
    fat: 21,
  });
});

Deno.test("a to-taste item is ignored", () => {
  const salt = { amount: null, grams: null, per100g: null };
  assertEquals(nutritionPerServing([eggs, salt], 1), nutritionPerServing([eggs], 1));
});

Deno.test("a measured item without per100g gives null", () => {
  assertEquals(nutritionPerServing([eggs, { amount: 1, grams: 5 }], 1), null);
});

Deno.test("out of range numbers give null", () => {
  const bad = (per100g: Record<string, number>, grams = 100) =>
    nutritionPerServing([{ amount: 1, grams, per100g }], 1);
  assertEquals(bad({ kcal: 1200, protein: 1, carbs: 1, fat: 1 }), null);
  assertEquals(bad({ kcal: 100, protein: 150, carbs: 0, fat: 0 }), null);
  assertEquals(bad({ kcal: 100, protein: -1, carbs: 0, fat: 0 }), null);
  assertEquals(bad({ kcal: 100, protein: 1, carbs: 1, fat: 1 }, 6000), null);
  assertEquals(bad({ kcal: 100, protein: 1, carbs: 1, fat: 1 }, 0), null);
});

Deno.test("macros adding up to more than 100 give null", () => {
  const item = { amount: 1, grams: 100, per100g: { kcal: 400, protein: 50, carbs: 40, fat: 20 } };
  assertEquals(nutritionPerServing([item], 1), null);
});

Deno.test("divides by servings, clamped to 1..12", () => {
  assertEquals(nutritionPerServing([eggs], 2), { kcal: 105, protein: 9, carbs: 1, fat: 8 });
  assertEquals(nutritionPerServing([eggs], 0), nutritionPerServing([eggs], 1));
  assertEquals(nutritionPerServing([eggs], 50), nutritionPerServing([eggs], 12));
});

Deno.test("no counted ingredients or a non-array gives null", () => {
  assertEquals(nutritionPerServing([], 1), null);
  assertEquals(nutritionPerServing(["x", null], 1), null);
  assertEquals(nutritionPerServing("eggs", 1), null);
  assertEquals(nutritionPerServing(undefined, 1), null);
});
