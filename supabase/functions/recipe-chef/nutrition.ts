// Per-serving nutrition for a recipe, summed in code.
//
// The model only gives grams and per-100g values for each ingredient. It never
// adds anything up, because models are bad at arithmetic. If any measured
// ingredient has numbers that look wrong we return null instead of guessing,
// so the app shows no nutrition rather than a made-up one.

export type Nutrition = { kcal: number; protein: number; carbs: number; fat: number };

function num(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

function inRange(v: number | null, min: number, max: number): v is number {
  return v !== null && v >= min && v <= max;
}

export function nutritionPerServing(rawIngredients: unknown, servings: number): Nutrition | null {
  if (!Array.isArray(rawIngredients)) return null;
  const people = Math.min(12, Math.max(1, Math.round(Number.isFinite(servings) ? servings : 1)));

  let kcal = 0;
  let protein = 0;
  let carbs = 0;
  let fat = 0;
  let counted = 0;

  for (const item of rawIngredients.slice(0, 40)) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;

    // "To taste" items have no amount and add nothing.
    const amount = num(o.amount);
    if (amount === null || amount <= 0) continue;

    const grams = num(o.grams);
    if (grams === null || grams <= 0 || grams > 5000) return null;

    const p = o.per100g;
    if (!p || typeof p !== "object") return null;
    const per = p as Record<string, unknown>;
    const k = num(per.kcal);
    const pr = num(per.protein);
    const c = num(per.carbs);
    const f = num(per.fat);
    if (!inRange(k, 0, 900)) return null;
    if (!inRange(pr, 0, 100) || !inRange(c, 0, 100) || !inRange(f, 0, 100)) return null;
    // A little slack: 33.3 + 33.3 + 33.4 is not exactly 100 in floating point.
    if (pr + c + f > 100.5) return null;

    const factor = grams / 100;
    kcal += factor * k;
    protein += factor * pr;
    carbs += factor * c;
    fat += factor * f;
    counted++;
  }

  if (counted === 0) return null;

  const out: Nutrition = {
    kcal: Math.round(kcal / people),
    protein: Math.round(protein / people),
    carbs: Math.round(carbs / people),
    fat: Math.round(fat / people),
  };
  if (out.kcal < 1 || out.kcal > 5000) return null;
  return out;
}
