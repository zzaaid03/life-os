// Shared AI client for every edge function that calls a model.
//
// Any OpenAI-compatible chat completions API works. Provider, model and key
// all come from Supabase secrets, so switching provider is a secrets change
// plus a redeploy, not a code change:
//   AI_API_KEY           required
//   AI_BASE_URL          default https://api.mistral.ai/v1
//   AI_MODEL             default mistral-small-latest
//   AI_REASONING_EFFORT  default "none". Mistral Small 4 is a hybrid reasoning
//                        model: with reasoning on, message.content becomes a
//                        list of chunks and output tokens grow a lot. Set it
//                        to an empty string for a provider that rejects the
//                        field.

const AI_API_KEY = Deno.env.get("AI_API_KEY");
const AI_BASE_URL = (Deno.env.get("AI_BASE_URL") ?? "https://api.mistral.ai/v1")
  .replace(/\/+$/, "");
const AI_MODEL = Deno.env.get("AI_MODEL") ?? "mistral-small-latest";
const AI_REASONING_EFFORT = Deno.env.get("AI_REASONING_EFFORT") ?? "none";

// Mistral's free tier allows about one request per second, so a 429 is
// usually cleared by waiting a moment. Three retries covers ~7s of backoff.
const MAX_RETRIES = 3;
const MAX_WAIT_MS = 10_000;

export const aiConfigured = Boolean(AI_API_KEY);

export type AiResult =
  | { ok: true; content: string }
  | { ok: false; status: number; detail: string };

/// Sends one system + user message pair in JSON mode and returns the reply
/// text. Transport errors throw, exactly like a bare fetch would.
///
/// maxTokens caps the reply. Without it the provider may count the model's
/// whole output allowance against the tokens-per-minute limit, which on a
/// small free-tier budget can reject every request before it runs.
export async function chatJson(
  system: string,
  user: string,
  maxTokens = 2048,
): Promise<AiResult> {
  const body: Record<string, unknown> = {
    model: AI_MODEL,
    temperature: 0,
    max_tokens: maxTokens,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
  };
  if (AI_REASONING_EFFORT) body.reasoning_effort = AI_REASONING_EFFORT;

  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`${AI_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${AI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (res.status === 429 && attempt < MAX_RETRIES) {
      await res.body?.cancel();
      const retryAfter = Number(res.headers.get("retry-after"));
      const waitMs = Number.isFinite(retryAfter) && retryAfter > 0
        ? Math.min(retryAfter * 1000, MAX_WAIT_MS)
        : 1000 * 2 ** attempt;
      await new Promise((r) => setTimeout(r, waitMs));
      continue;
    }

    if (!res.ok) {
      // The model name is included so a failure shows which model the
      // secrets actually resolved to.
      return { ok: false, status: res.status, detail: `${AI_MODEL}: ${await res.text()}` };
    }

    const data = await res.json();
    return { ok: true, content: messageText(data.choices?.[0]?.message?.content) };
  }
}

// Plain string normally. If reasoning is ever switched on, Mistral returns a
// list of chunks; keep only the text ones so the thinking never reaches
// JSON.parse.
function messageText(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((c) => c?.type === "text" && typeof c.text === "string")
      .map((c) => c.text)
      .join("");
  }
  return "{}";
}
