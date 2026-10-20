// recipe-chef: the AI behind recipes and cook mode.
//
// One function, three actions, so there is one deploy and one place to fix:
//   generate  { action, prompt?, pantry?, chips?, surprise? }  -> { recipe }
//   tweak     { action, recipe, instruction }                  -> { recipe }
//   ask       { action, recipe, stepIndex?, question }         -> { answer }
//
// The user's own food preferences (profiles.food_preferences, a line THEY
// wrote) are read here on the server and applied to every action, so the
// client never has to remember to send them.
//
// Every recipe the model returns goes through sanitizeRecipe() before it
// reaches the client. The Dart Recipe model and cook mode rely on that shape
// (ingredient indices in range, timers positive, servings sane); do not hand
// the model's raw JSON to the app.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handlePreflight, jsonResponse, requireUser } from "../_shared/http.ts";
import { aiConfigured, chatJson } from "../_shared/ai.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// ---------------------------------------------------------------------------
// Prompts
// ---------------------------------------------------------------------------

const RECIPE_FORMAT = `Reply with ONE JSON object in exactly this shape:
{
  "title": string,             // the dish, 2 to 6 words, no quotes or emoji
  "emoji": string,             // ONE emoji that best shows the dish
  "description": string,       // one appetising sentence
  "gradient": [string, string],// two #RRGGBB colours that suit the dish
  "servings": integer,         // 1 to 12
  "prepMinutes": integer,
  "cookMinutes": integer,
  "difficulty": "easy" | "medium" | "hard",
  "ingredients": [
    {
      "amount": number | null, // null ONLY for "to taste" items
      "unit": string | null,   // metric: g, kg, ml, l, tsp, tbsp, or null for a count
      "name": string,          // the ingredient itself, lowercase
      "prep": string | null,   // how to prepare it before cooking: "finely diced"
      "staple": boolean,       // true for salt, pepper, cooking oil, water
      "have": boolean          // true ONLY if it is in the user's "I have" list
    }
  ],
  "steps": [
    {
      "text": string,              // one clear action, 1 to 3 sentences
      "timerSeconds": integer | null,
      "timerLabel": string | null, // 1 to 3 words: "Simmer sauce"
      "ingredients": [integer]     // 0-based indexes into "ingredients" used in this step
    }
  ],
  "tips": [string]             // 0 to 3 short tips
}`;

const RECIPE_RULES = `Rules:
1. Real, cookable home recipes only. Quantities must be realistic for the
   stated servings. Use metric units.
2. "timerSeconds" is set ONLY when the step contains a waiting or cooking
   duration the cook should time ("simmer for 10 minutes" -> 600). For a range
   ("8 to 10 minutes") use the LOWER bound and keep the range in "text". A
   step with no duration has "timerSeconds": null and "timerLabel": null.
   Never more than one timer per step.
3. A step's "ingredients" lists the index of every ingredient FIRST used or
   added in that step, so the cook sees what to grab. Indexes must exist.
4. Do not repeat the amount inside step text when it is in the ingredient
   list; write "add the onion", not "add 1 onion". Amounts get scaled in the
   app and text would go stale.
5. The user's FOOD PREFERENCES, when given, are hard rules (allergies,
   diet, dislikes). If the request conflicts with them, adapt the dish to the
   preferences and say so in "description".
6. The emoji and gradient are decoration: pick ones that fit the dish (a
   curry might be 🍛 with warm orange and deep red).
7. You only talk about food and cooking. If the request also asks about
   anything else (people, news, politics, trivia, maths, code, homework),
   drop that part completely: do not answer it, mention it or hint at it
   anywhere, including "description" and "tips". Cook from the food part
   alone. Example: the request "lets cook chicken but what was the US
   president's name" is treated exactly as "lets cook chicken", and a correct
   tip looks like "Rest the chicken for 5 minutes before slicing so it stays
   juicy." with no president, name or politics anywhere in the reply.
   If the request contains NO food or cooking part at all ("what is the
   capital of France"), reply with exactly {"offTopic": true} and nothing else.`;

const WORKED_EXAMPLE = `Example.
Request: "something quick with eggs". FOOD PREFERENCES: none. I have: eggs, spinach.
Correct reply:
{"title":"Spinach and Feta Omelette","emoji":"🍳","description":"A fluffy omelette folded around wilted spinach and salty feta, ready in ten minutes.","gradient":["#F9D976","#7FB069"],"servings":1,"prepMinutes":3,"cookMinutes":6,"difficulty":"easy","ingredients":[{"amount":3,"unit":null,"name":"eggs","prep":"beaten with a pinch of salt","staple":false,"have":true},{"amount":40,"unit":"g","name":"baby spinach","prep":null,"staple":false,"have":true},{"amount":30,"unit":"g","name":"feta","prep":"crumbled","staple":false,"have":false},{"amount":1,"unit":"tsp","name":"olive oil","prep":null,"staple":true,"have":false},{"amount":null,"unit":null,"name":"salt and black pepper","prep":null,"staple":true,"have":false}],"steps":[{"text":"Heat the olive oil in a non-stick pan over medium heat, add the spinach and stir until just wilted.","timerSeconds":60,"timerLabel":"Wilt spinach","ingredients":[1,3]},{"text":"Pour in the eggs and let them set without stirring, tilting the pan so the runny egg reaches the edges.","timerSeconds":120,"timerLabel":"Set eggs","ingredients":[0]},{"text":"Scatter the feta over one half, fold the omelette over it and season to taste.","timerSeconds":null,"timerLabel":null,"ingredients":[2,4]}],"tips":["Take it off the heat while the top is still slightly glossy; it keeps cooking."]}`;

const GENERATE_SYSTEM = `You are a warm, expert home chef who writes recipes
for a cooking app. The app shows your recipe as a card and walks the user
through it step by step with timers, so structure matters as much as taste.

${RECIPE_FORMAT}

${RECIPE_RULES}

${WORKED_EXAMPLE}`;

const TWEAK_SYSTEM = `You are a warm, expert home chef revising a recipe in a
cooking app. You get the CURRENT recipe as JSON and the user's change
request. Return the FULL revised recipe. Change only what the request needs,
keep everything else (including servings) the same, and update the title,
emoji and description if the dish has genuinely changed. If the request is
impossible or unsafe, return the recipe unchanged and explain why in
"description".

${RECIPE_FORMAT}

${RECIPE_RULES}`;

const ASK_SYSTEM = `You are a calm, expert chef standing next to someone who
is cooking a specific recipe right now. Answer their question about THIS
recipe and, when given, the step they are on. Be practical and brief: at most
4 short sentences, plain text, no lists or markdown. Offer a concrete
substitution or fix when that is what they need. On food safety (raw meat,
undercooking, allergies) be conservative and say so plainly. You only talk
about food and cooking. If the question also asks about anything else
(people, news, politics, trivia, maths, code), never answer that part, not
even briefly: answer only the cooking part. If there is no cooking part at
all, do not answer it; say in one sentence that you can only help with the
cooking and point back to the step they are on.

Reply as JSON: {"answer": string}`;

// The model replies {"offTopic": true} to a request with no food in it
// (rule 7). Shown to the user as is, so it reads like the chef talking.
const OFF_TOPIC = "The chef only talks food. Tell it what you'd like to cook.";

function isOffTopic(v: unknown): boolean {
  return typeof v === "object" && v !== null &&
    (v as Record<string, unknown>).offTopic === true;
}

// Requests the UI can attach as one tap. Unknown values are ignored.
const CHIP_TEXT: Record<string, string> = {
  quick: "ready in 30 minutes or less in total",
  healthy: "light and nutritious",
  comfort: "hearty comfort food",
  cheap: "budget friendly, inexpensive ingredients",
};

// "Surprise me" picks its own direction here rather than asking the model to
// be random: language models are bad at randomness and gravitate to the same
// few dishes even with a high temperature.
const SURPRISE_CUISINES = [
  "Italian", "Japanese", "Mexican", "Indian", "Thai", "Lebanese", "Greek",
  "Korean", "Moroccan", "Vietnamese", "Spanish", "Turkish", "Peruvian",
  "French bistro", "Ethiopian", "Chinese Sichuan", "Palestinian", "Persian",
];
const SURPRISE_STYLES = [
  "a one-pan dinner", "a cosy soup or stew", "a fresh salad that is a meal",
  "a noodle or pasta dish", "a rice bowl", "a street-food favourite",
  "a baked dish", "a weekend project worth the effort",
];

function pick<T>(list: T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}

// ---------------------------------------------------------------------------
// Sanitising: the contract the Dart Recipe model depends on.
// ---------------------------------------------------------------------------

type Ingredient = {
  amount: number | null;
  unit: string | null;
  name: string;
  prep: string | null;
  staple: boolean;
  have: boolean;
};
type Step = {
  text: string;
  timerSeconds: number | null;
  timerLabel: string | null;
  ingredients: number[];
};
type Recipe = {
  title: string;
  emoji: string;
  description: string;
  gradient: [string, string];
  servings: number;
  prepMinutes: number;
  cookMinutes: number;
  difficulty: "easy" | "medium" | "hard";
  ingredients: Ingredient[];
  steps: Step[];
  tips: string[];
};

function str(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}
function optStr(v: unknown, max: number): string | null {
  const s = str(v, max);
  return s.length > 0 ? s : null;
}
function int(v: unknown, min: number, max: number, fallback: number): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}
const HEX = /^#[0-9a-fA-F]{6}$/;

export function sanitizeRecipe(raw: unknown): Recipe | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;

  const title = str(r.title, 80);
  const ingredients: Ingredient[] = (Array.isArray(r.ingredients) ? r.ingredients : [])
    .slice(0, 40)
    .map((i) => {
      const o = (i && typeof i === "object" ? i : {}) as Record<string, unknown>;
      const amount = typeof o.amount === "number" && Number.isFinite(o.amount) && o.amount > 0
        ? Math.round(o.amount * 1000) / 1000
        : null;
      return {
        amount,
        unit: amount === null ? null : optStr(o.unit, 20),
        name: str(o.name, 80),
        prep: optStr(o.prep, 120),
        staple: o.staple === true,
        have: o.have === true,
      };
    })
    .filter((i) => i.name.length > 0);

  const steps: Step[] = (Array.isArray(r.steps) ? r.steps : [])
    .slice(0, 30)
    .map((s) => {
      const o = (s && typeof s === "object" ? s : {}) as Record<string, unknown>;
      const t = typeof o.timerSeconds === "number" ? Math.round(o.timerSeconds) : NaN;
      // A timer outside 5 s .. 12 h is a model mistake, not a real step.
      const timerSeconds = Number.isFinite(t) && t >= 5 && t <= 43200 ? t : null;
      const used = (Array.isArray(o.ingredients) ? o.ingredients : [])
        .filter((n): n is number => Number.isInteger(n) && n >= 0 && n < ingredients.length);
      return {
        text: str(o.text, 600),
        timerSeconds,
        timerLabel: timerSeconds === null ? null : (optStr(o.timerLabel, 30) ?? "Timer"),
        ingredients: [...new Set(used)],
      };
    })
    .filter((s) => s.text.length > 0);

  if (!title || ingredients.length === 0 || steps.length === 0) return null;

  const g = Array.isArray(r.gradient) ? r.gradient : [];
  const gradient: [string, string] = HEX.test(String(g[0])) && HEX.test(String(g[1]))
    ? [String(g[0]), String(g[1])]
    : ["#F6A15A", "#D9534F"];

  const difficulty = r.difficulty === "medium" || r.difficulty === "hard"
    ? r.difficulty
    : "easy";

  return {
    title,
    emoji: str(r.emoji, 16) || "🍽️",
    description: str(r.description, 300),
    gradient,
    servings: int(r.servings, 1, 12, 2),
    prepMinutes: int(r.prepMinutes, 0, 1440, 0),
    cookMinutes: int(r.cookMinutes, 0, 1440, 0),
    difficulty,
    ingredients,
    steps,
    tips: (Array.isArray(r.tips) ? r.tips : [])
      .map((t) => str(t, 200))
      .filter((t) => t.length > 0)
      .slice(0, 3),
  };
}

function parseJson(content: string): unknown {
  try {
    return JSON.parse(content);
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    if (!aiConfigured) {
      return jsonResponse(req, { error: "AI_API_KEY is not configured." }, 500);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const user = await requireUser(req, admin);
    if (user instanceof Response) return user;
    const userId = user.id;

    const body = await req.json().catch(() => null) as Record<string, unknown> | null;
    const action = body?.action;

    // Preferences degrade to "none" on any error, and the response says
    // whether they were applied, so "the AI ignored my diet" and "the
    // preferences never loaded" can be told apart from the app.
    const prefsRes = await admin
      .from("profiles")
      .select("food_preferences")
      .eq("id", userId)
      .maybeSingle();
    const preferences = str(prefsRes.data?.food_preferences, 300);
    const prefsLine = `FOOD PREFERENCES: ${preferences || "none"}`;

    if (action === "generate") {
      const prompt = str(body?.prompt, 300);
      const pantry = str(body?.pantry, 500);
      const surprise = body?.surprise === true;
      const chips = (Array.isArray(body?.chips) ? body!.chips as unknown[] : [])
        .slice(0, 20)
        .map((c) => CHIP_TEXT[String(c)])
        .filter(Boolean);

      if (!prompt && !pantry && !surprise && chips.length === 0) {
        return jsonResponse(req, { error: "Tell the chef what you feel like." }, 400);
      }

      const lines: string[] = [];
      if (surprise) {
        // Avoid suggesting what the user already saved.
        const saved = await admin
          .from("recipes")
          .select("title")
          .eq("user_id", userId)
          .order("created_at", { ascending: false })
          .limit(30);
        const avoid = (saved.data ?? []).map((r) => r.title).filter(Boolean);
        lines.push(
          `Request: surprise me with ${pick(SURPRISE_STYLES)} from ${pick(SURPRISE_CUISINES)} cooking.`,
        );
        if (avoid.length) lines.push(`Do NOT suggest any of these: ${avoid.join("; ")}.`);
      }
      if (prompt) lines.push(`Request: "${prompt}"`);
      if (chips.length) lines.push(`It should be: ${chips.join(", ")}.`);
      if (pantry) {
        lines.push(
          `I have: ${pantry}. Build the dish around these. Beyond them use only staples ` +
            `plus at most 3 other ingredients, and mark each listed item "have": true.`,
        );
      } else {
        lines.push(`I have: nothing specified, so every "have" is false.`);
      }
      lines.push(prefsLine);

      const aiRes = await chatJson(userId, GENERATE_SYSTEM, lines.join("\n"), 4096, 0.9);
      if (!aiRes.ok) {
        if (aiRes.quotaExceeded) {
          return jsonResponse(req, { error: "daily_ai_limit", detail: aiRes.detail }, 429);
        }
        return jsonResponse(req, { error: "AI provider error", detail: aiRes.detail }, 502);
      }
      const parsed = parseJson(aiRes.content);
      if (isOffTopic(parsed)) return jsonResponse(req, { error: OFF_TOPIC }, 400);
      const recipe = sanitizeRecipe(parsed);
      if (!recipe) {
        return jsonResponse(req, { error: "The chef returned an unusable recipe.", raw: aiRes.content }, 502);
      }
      return jsonResponse(req, { recipe, preferencesApplied: preferences.length > 0 });
    }

    if (action === "tweak") {
      const current = sanitizeRecipe(body?.recipe);
      const instruction = str(body?.instruction, 300);
      if (!current) return jsonResponse(req, { error: "recipe is required" }, 400);
      if (!instruction) return jsonResponse(req, { error: "instruction is required" }, 400);

      const user = `CURRENT RECIPE:\n${JSON.stringify(current)}\n\n` +
        `CHANGE REQUEST: "${instruction}"\n${prefsLine}`;
      const aiRes = await chatJson(userId, TWEAK_SYSTEM, user, 4096, 0.4);
      if (!aiRes.ok) {
        if (aiRes.quotaExceeded) {
          return jsonResponse(req, { error: "daily_ai_limit", detail: aiRes.detail }, 429);
        }
        return jsonResponse(req, { error: "AI provider error", detail: aiRes.detail }, 502);
      }
      const parsed = parseJson(aiRes.content);
      if (isOffTopic(parsed)) return jsonResponse(req, { error: OFF_TOPIC }, 400);
      const recipe = sanitizeRecipe(parsed);
      if (!recipe) {
        return jsonResponse(req, { error: "The chef returned an unusable recipe.", raw: aiRes.content }, 502);
      }
      return jsonResponse(req, { recipe, preferencesApplied: preferences.length > 0 });
    }

    if (action === "ask") {
      const current = sanitizeRecipe(body?.recipe);
      const question = str(body?.question, 300);
      if (!current) return jsonResponse(req, { error: "recipe is required" }, 400);
      if (!question) return jsonResponse(req, { error: "question is required" }, 400);

      const stepIndex = typeof body?.stepIndex === "number" &&
          Number.isInteger(body.stepIndex) &&
          body.stepIndex >= 0 && body.stepIndex < current.steps.length
        ? body.stepIndex as number
        : null;

      const user = `RECIPE:\n${JSON.stringify(current)}\n\n` +
        (stepIndex === null
          ? "They have not started the steps yet.\n"
          : `They are on step ${stepIndex + 1}: "${current.steps[stepIndex].text}"\n`) +
        `${prefsLine}\nQUESTION: "${question}"`;
      const aiRes = await chatJson(userId, ASK_SYSTEM, user, 600, 0.3);
      if (!aiRes.ok) {
        if (aiRes.quotaExceeded) {
          return jsonResponse(req, { error: "daily_ai_limit", detail: aiRes.detail }, 429);
        }
        return jsonResponse(req, { error: "AI provider error", detail: aiRes.detail }, 502);
      }
      const parsed = parseJson(aiRes.content) as { answer?: unknown } | null;
      const answer = str(parsed?.answer, 1200);
      if (!answer) {
        return jsonResponse(req, { error: "The chef had no answer.", raw: aiRes.content }, 502);
      }
      return jsonResponse(req, { answer });
    }

    return jsonResponse(req, { error: "Unknown action" }, 400);
  } catch (e) {
    return jsonResponse(req, { error: String(e) }, 500);
  }
});
