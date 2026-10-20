import { assertEquals } from "jsr:@std/assert";
import {
  corsHeaders,
  handlePreflight,
  jsonResponse,
  requireUser,
} from "./http.ts";

function reqWithOrigin(origin?: string, method = "POST"): Request {
  const headers = new Headers();
  if (origin) headers.set("Origin", origin);
  return new Request("https://example.test/fn", { method, headers });
}

Deno.test("allowed origins are echoed with Vary: Origin", () => {
  for (
    const origin of [
      "https://lifeos.deadthrone.dev",
      "https://staging.lifeos.deadthrone.dev",
      "http://localhost:51234",
      "http://127.0.0.1:8080",
      "http://localhost",
    ]
  ) {
    const h = corsHeaders(reqWithOrigin(origin));
    assertEquals(h["Access-Control-Allow-Origin"], origin);
    assertEquals(h["Vary"], "Origin");
  }
});

Deno.test("unknown and missing origins get no Allow-Origin header", () => {
  for (
    const origin of [
      "https://evil.example",
      "https://lifeos.deadthrone.dev.evil.example",
      "http://localhost.evil.example",
      "https://localhost:3000",
      undefined,
    ]
  ) {
    const h = corsHeaders(reqWithOrigin(origin));
    assertEquals(h["Access-Control-Allow-Origin"], undefined);
    assertEquals(h["Vary"], "Origin");
  }
});

Deno.test("preflight answers OPTIONS and ignores other methods", async () => {
  const res = handlePreflight(
    reqWithOrigin("https://lifeos.deadthrone.dev", "OPTIONS"),
  );
  assertEquals(res?.status, 200);
  assertEquals(
    res?.headers.get("Access-Control-Allow-Origin"),
    "https://lifeos.deadthrone.dev",
  );
  assertEquals(await res?.text(), "ok");
  assertEquals(handlePreflight(reqWithOrigin(undefined, "POST")), null);
});

Deno.test("jsonResponse sets status, body and content type", async () => {
  const res = jsonResponse(
    reqWithOrigin("https://lifeos.deadthrone.dev"),
    { a: 1 },
    201,
  );
  assertEquals(res.status, 201);
  assertEquals(res.headers.get("Content-Type"), "application/json");
  assertEquals(
    res.headers.get("Access-Control-Allow-Origin"),
    "https://lifeos.deadthrone.dev",
  );
  assertEquals(await res.json(), { a: 1 });
});

Deno.test("jsonResponse defaults to 200", () => {
  assertEquals(jsonResponse(reqWithOrigin(), {}).status, 200);
});

Deno.test("requireUser returns 401 when the JWT is missing or rejected", async () => {
  // Fake admin client: no network, rejects any token.
  // deno-lint-ignore no-explicit-any
  const admin: any = {
    auth: {
      getUser: (_jwt: string) =>
        Promise.resolve({ data: { user: null }, error: { message: "bad" } }),
    },
  };
  const result = await requireUser(reqWithOrigin(), admin);
  assertEquals(result instanceof Response, true);
  const res = result as Response;
  assertEquals(res.status, 401);
  assertEquals(await res.json(), { error: "unauthorized" });
});

Deno.test("requireUser strips Bearer and returns the user on success", async () => {
  let seen = "";
  // deno-lint-ignore no-explicit-any
  const admin: any = {
    auth: {
      getUser: (jwt: string) => {
        seen = jwt;
        return Promise.resolve({ data: { user: { id: "u1" } }, error: null });
      },
    },
  };
  const req = new Request("https://example.test/fn", {
    headers: { Authorization: "Bearer abc.def" },
  });
  const result = await requireUser(req, admin);
  assertEquals(seen, "abc.def");
  assertEquals((result as { id: string }).id, "u1");
});
