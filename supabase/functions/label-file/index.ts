// Supabase Edge Function: label-file
//
// Given a fileId, generates alternative search terms for that file from its
// file name and user-typed note only, and stores them on ai_label. Never
// reads file contents (no Storage download) and never labels a private file.
//
// Secrets: GROQ_API_KEY (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are
// auto-injected).

import { createClient } from "jsr:@supabase/supabase-js@2";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SYSTEM_PROMPT =
  `You generate alternative search terms for a stored file, given only its
file name and the owner's own one-line note about what it is. Return 4 to 8
short alternative search terms someone might type to find this document:
synonyms and category words only (a note "my flat lease" should yield things
like "rental contract", "tenancy agreement", "housing", "landlord").

Do NOT invent facts not present in the note or file name. Do NOT include
dates, names, or numbers. If the note and file name say nothing meaningful,
return an empty array.

Respond with ONLY a JSON object of this exact form:
{"labels": string[]}`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GROQ_API_KEY) {
      return jsonResponse({ error: "GROQ_API_KEY is not configured." }, 500);
    }

    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }
    const userId = userData.user.id;

    const body = await req.json().catch(() => null);
    const fileId = body?.fileId;
    if (typeof fileId !== "string" || fileId.length === 0) {
      return jsonResponse({ error: "fileId is required" }, 400);
    }

    const { data: row, error: rowErr } = await admin
      .from("user_files")
      .select("id, user_id, file_name, user_note, is_private")
      .eq("id", fileId)
      .is("deleted_at", null)
      .maybeSingle();

    if (rowErr || !row) {
      return jsonResponse({ error: "file not found" }, 404);
    }

    // The admin client bypasses RLS, so this ownership check is the only
    // thing preventing one user labelling another user's file.
    if (row.user_id !== userId) {
      return jsonResponse({ error: "forbidden" }, 403);
    }

    // The per-file private toggle means this file's data must never reach a
    // third party — skip the Groq call entirely, don't just discard the result.
    if (row.is_private) {
      return jsonResponse({ skipped: "private" });
    }

    const userContent =
      `File name: ${row.file_name ?? ""}\nNote: ${row.user_note ?? ""}`;

    let labels: string[] = [];
    try {
      const groqRes = await fetch(
        "https://api.groq.com/openai/v1/chat/completions",
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${GROQ_API_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "llama-3.3-70b-versatile",
            temperature: 0,
            response_format: { type: "json_object" },
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: userContent },
            ],
          }),
        },
      );

      if (groqRes.ok) {
        const data = await groqRes.json();
        const content = data.choices?.[0]?.message?.content ?? "{}";
        const parsed = JSON.parse(content);
        if (Array.isArray(parsed.labels)) {
          labels = parsed.labels.filter((l: unknown): l is string => typeof l === "string");
        }
      }
    } catch {
      // Labelling is an enhancement to search, never presented as a failure —
      // the file is already uploaded and still findable by its note and name.
      labels = [];
    }

    if (labels.length === 0) {
      // Write nothing. Groq failing, or genuinely having nothing to add, must
      // not blank a label this file already had: the update would silently
      // narrow what search can find and there is no way to notice from the UI.
      return jsonResponse({ aiLabel: null });
    }

    const aiLabel = labels.join(", ");

    await admin
      .from("user_files")
      .update({ ai_label: aiLabel })
      .eq("id", fileId);

    return jsonResponse({ aiLabel });
  } catch (_e) {
    // Any unexpected failure is still reported as a 200 with a null label —
    // labelling must never surface as an error to the caller.
    return jsonResponse({ aiLabel: null });
  }
});
