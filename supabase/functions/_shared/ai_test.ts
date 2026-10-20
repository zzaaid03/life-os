import { assertEquals, assertStringIncludes } from "jsr:@std/assert";

type Chat = typeof import("./ai.ts").chatJson;

const ENV_KEYS = [
  "AI_API_KEY",
  "AI_BASE_URL",
  "AI_MODEL",
  "AI_REASONING_EFFORT",
  "AI_DAILY_CALL_LIMIT",
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
];

let importCounter = 0;

// ai.ts reads env at import time, so each scenario imports a fresh copy.
async function loadAi(env: Record<string, string | null>): Promise<Chat> {
  for (const k of ENV_KEYS) Deno.env.delete(k);
  Deno.env.set("AI_API_KEY", "test-key");
  Deno.env.set("SUPABASE_URL", "https://supabase.test");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-key");
  for (const [k, v] of Object.entries(env)) {
    if (v === null) Deno.env.delete(k);
    else Deno.env.set(k, v);
  }
  const mod = await import(`./ai.ts?case=${importCounter++}`);
  return mod.chatJson;
}

interface Captured {
  providerBodies: Record<string, unknown>[];
  rpcBodies: Record<string, unknown>[];
}

// Stubs fetch: the quota RPC and the provider are told apart by URL.
async function withFetch(
  quota: () => Response,
  provider: () => Response,
  run: (cap: Captured) => Promise<void>,
) {
  const original = globalThis.fetch;
  const cap: Captured = { providerBodies: [], rpcBodies: [] };
  globalThis.fetch = ((input: Request | URL | string, init?: RequestInit) => {
    const req = input instanceof Request ? input : null;
    const url = req ? req.url : String(input);
    const rawBody = init?.body ?? null;
    if (url.includes("/rest/v1/rpc/consume_ai_call")) {
      if (typeof rawBody === "string") cap.rpcBodies.push(JSON.parse(rawBody));
      return Promise.resolve(quota());
    }
    if (url.includes("/chat/completions")) {
      cap.providerBodies.push(JSON.parse(String(rawBody)));
      return Promise.resolve(provider());
    }
    return Promise.reject(new Error(`unexpected fetch: ${url}`));
  }) as typeof fetch;
  try {
    await run(cap);
  } finally {
    globalThis.fetch = original;
  }
}

const quotaOk = () =>
  new Response("true", { headers: { "Content-Type": "application/json" } });
const quotaOver = () =>
  new Response("false", { headers: { "Content-Type": "application/json" } });
const providerOk = (content = '{"x":1}') =>
  new Response(JSON.stringify({ choices: [{ message: { content } }] }), {
    headers: { "Content-Type": "application/json" },
  });

Deno.test("default (effort none) sends temperature and reasoning_effort none", async () => {
  const chatJson = await loadAi({});
  await withFetch(quotaOk, () => providerOk(), async (cap) => {
    const r = await chatJson("u1", "sys JSON", "usr", 500, 0.7);
    assertEquals(r, { ok: true, content: '{"x":1}' });
    const b = cap.providerBodies[0];
    assertEquals(b.temperature, 0.7);
    assertEquals(b.reasoning_effort, "none");
    assertEquals(b.max_completion_tokens, 500);
    assertEquals("max_tokens" in b, false);
    assertEquals(b.response_format, { type: "json_object" });
  });
});

Deno.test("reasoning on drops temperature and never sends max_tokens", async () => {
  const chatJson = await loadAi({ AI_REASONING_EFFORT: "medium" });
  await withFetch(quotaOk, () => providerOk(), async (cap) => {
    await chatJson("u1", "s", "u", 500, 0.9);
    const b = cap.providerBodies[0];
    assertEquals("temperature" in b, false);
    assertEquals("max_tokens" in b, false);
    assertEquals(b.reasoning_effort, "medium");
  });
});

Deno.test("empty effort omits reasoning_effort and keeps temperature", async () => {
  const chatJson = await loadAi({ AI_REASONING_EFFORT: "" });
  await withFetch(quotaOk, () => providerOk(), async (cap) => {
    await chatJson("u1", "s", "u", 500, 0.3);
    const b = cap.providerBodies[0];
    assertEquals("reasoning_effort" in b, false);
    assertEquals(b.temperature, 0.3);
  });
});

Deno.test("non-ok provider response returns an error, not empty data", async () => {
  const chatJson = await loadAi({ AI_MODEL: "test-model" });
  await withFetch(
    quotaOk,
    () => new Response("boom", { status: 500 }),
    async () => {
      const r = await chatJson("u1", "s", "u");
      assertEquals(r.ok, false);
      if (!r.ok) {
        assertEquals(r.status, 500);
        assertStringIncludes(r.detail, "test-model");
        assertStringIncludes(r.detail, "boom");
      }
    },
  );
});

Deno.test("missing content falls back to {} only on an ok response", async () => {
  const chatJson = await loadAi({});
  await withFetch(
    quotaOk,
    () => new Response(JSON.stringify({ choices: [] })),
    async () => {
      assertEquals(await chatJson("u1", "s", "u"), { ok: true, content: "{}" });
    },
  );
});

Deno.test("over quota refuses with 429 and never calls the provider", async () => {
  const chatJson = await loadAi({});
  await withFetch(quotaOver, () => providerOk(), async (cap) => {
    const r = await chatJson("u1", "s", "u");
    assertEquals(r.ok, false);
    if (!r.ok) {
      assertEquals(r.status, 429);
      assertEquals(r.quotaExceeded, true);
    }
    assertEquals(cap.providerBodies.length, 0);
  });
});

Deno.test("quota check failure fails closed with 503", async () => {
  const chatJson = await loadAi({});
  await withFetch(
    () =>
      new Response(JSON.stringify({ message: "db down" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }),
    () => providerOk(),
    async (cap) => {
      const r = await chatJson("u1", "s", "u");
      assertEquals(r.ok, false);
      if (!r.ok) {
        assertEquals(r.status, 503);
        assertStringIncludes(r.detail, "ai_quota_check_failed");
      }
      assertEquals(cap.providerBodies.length, 0);
    },
  );
});

Deno.test("daily limit comes from env, bad values fall back to 80", async () => {
  for (const [value, expected] of [["5", 5], ["abc", 80], ["0", 80], ["-3", 80]] as const) {
    const chatJson = await loadAi({ AI_DAILY_CALL_LIMIT: value });
    await withFetch(quotaOk, () => providerOk(), async (cap) => {
      await chatJson("u1", "s", "u");
      assertEquals(cap.rpcBodies[0].p_limit, expected);
      assertEquals(cap.rpcBodies[0].p_user_id, "u1");
    });
  }
});
