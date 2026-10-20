// Shared HTTP plumbing for every edge function: CORS, JSON responses, and
// JWT auth. Keep this the only place that sets Access-Control-Allow-Origin.

import type { SupabaseClient, User } from "jsr:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://lifeos.deadthrone.dev",
  "https://staging.lifeos.deadthrone.dev",
]);

// Local dev: Flutter web picks a random port, so any localhost port is fine.
const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

function isAllowedOrigin(origin: string): boolean {
  return ALLOWED_ORIGINS.has(origin) || LOCAL_ORIGIN.test(origin);
}

// Native apps send no Origin header and don't need CORS at all, so they get
// no Allow-Origin header. An unknown origin gets none either, never a wildcard.
export function corsHeaders(req: Request): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  const origin = req.headers.get("Origin");
  if (origin && isAllowedOrigin(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

export function handlePreflight(req: Request): Response | null {
  if (req.method !== "OPTIONS") return null;
  return new Response("ok", { headers: corsHeaders(req) });
}

export function jsonResponse(
  req: Request,
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

// The user comes from the JWT only, never from the request body.
export async function requireUser(
  req: Request,
  admin: SupabaseClient,
): Promise<User | Response> {
  const jwt = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user) {
    return jsonResponse(req, { error: "unauthorized" }, 401);
  }
  return data.user;
}
