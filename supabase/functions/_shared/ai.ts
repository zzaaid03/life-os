// Shared AI client for every edge function that calls a model.
//
// Any OpenAI-compatible chat completions API works. Provider, model and key
// all come from Supabase secrets, so switching provider is a secrets change
// plus a redeploy, not a code change:
//   AI_API_KEY           required
//   AI_BASE_URL          default https://api.openai.com/v1
//   AI_MODEL             default gpt-6-luna
//   AI_REASONING_EFFORT  default "none". gpt-6-luna is a reasoning model whose
//                        own default is "medium"; "none" keeps replies fast
//                        and cheap for plain extraction. Any other value also
//                        drops temperature, which OpenAI rejects while
//                        reasoning is on. Set it to an empty string for a
//                        provider that does not know the field.

const AI_API_KEY = Deno.env.get("AI_API_KEY");
const AI_BASE_URL = (Deno.env.get("AI_BASE_URL") ?? "https://api.openai.com/v1")
  .replace(/\/+$/, "");
const AI_MODEL = Deno.env.get("AI_MODEL") ?? "gpt-6-luna";
const AI_REASONING_EFFORT = Deno.env.get("AI_REASONING_EFFORT") ?? "none";

// A 429 from a busy provider usually clears within seconds. Three retries
// covers ~7s of backoff.
const MAX_RETRIES = 3;
const MAX_WAIT_MS = 10_000;

export const aiConfigured = Boolean(AI_API_KEY);

export type AiResult =
  | { ok: true; content: string }
  | { ok: false; status: number; detail: string };

/// Sends one system + user message pair in JSON mode and returns the reply
/// text. Transport errors throw, exactly like a bare fetch would.
///
/// maxTokens caps the reply, reasoning tokens included, so one bad request
/// can never produce an unbounded bill.
export async function chatJson(
  system: string,
  user: string,
  maxTokens = 2048,
): Promise<AiResult> {
  const body: Record<string, unknown> = {
    model: AI_MODEL,
    max_completion_tokens: maxTokens,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
  };
  if (AI_REASONING_EFFORT) body.reasoning_effort = AI_REASONING_EFFORT;
  if (!AI_REASONING_EFFORT || AI_REASONING_EFFORT === "none") body.temperature = 0;

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
    const content = data.choices?.[0]?.message?.content;
    return { ok: true, content: typeof content === "string" ? content : "{}" };
  }
}
