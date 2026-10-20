// Supabase Edge Function: label-file
//
// Given a fileId, generates alternative search terms for that file from its
// file name and user-typed note only, and stores them on ai_label. Never
// reads file contents (no Storage download) and never labels a private file.
//
// Secrets: AI_API_KEY, see _shared/ai.ts (SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY are
// auto-injected).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handlePreflight, jsonResponse, requireUser } from "../_shared/http.ts";
import { aiConfigured, chatJson } from "../_shared/ai.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

    const body = await req.json().catch(() => null);
    const fileId = typeof body?.fileId === "string"
      ? body.fileId.trim().slice(0, 64)
      : "";
    if (!fileId) {
      return jsonResponse(req, { error: "fileId is required" }, 400);
    }

    const { data: row, error: rowErr } = await admin
      .from("user_files")
      .select("id, user_id, file_name, user_note, is_private")
      .eq("id", fileId)
      .is("deleted_at", null)
      .maybeSingle();

    if (rowErr || !row) {
      return jsonResponse(req, { error: "file not found" }, 404);
    }

    // The admin client bypasses RLS, so this ownership check is the only
    // thing preventing one user labelling another user's file.
    if (row.user_id !== userId) {
      return jsonResponse(req, { error: "forbidden" }, 403);
    }

    // The per-file private toggle means this file's data must never reach a
    // third party, so skip the model call entirely, don't just discard the result.
    if (row.is_private) {
      return jsonResponse(req, { skipped: "private" });
    }

    const userContent =
      `File name: ${row.file_name ?? ""}\nNote: ${row.user_note ?? ""}`;

    let labels: string[] = [];
    try {
      const aiRes = await chatJson(userId, SYSTEM_PROMPT, userContent, 256);

      if (aiRes.ok) {
        const content = aiRes.content;
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
      // Write nothing. The model failing, or genuinely having nothing to add, must
      // not blank a label this file already had: the update would silently
      // narrow what search can find and there is no way to notice from the UI.
      return jsonResponse(req, { aiLabel: null });
    }

    const aiLabel = labels.join(", ");

    await admin
      .from("user_files")
      .update({ ai_label: aiLabel })
      .eq("id", fileId);

    return jsonResponse(req, { aiLabel });
  } catch (_e) {
    // Any unexpected failure is still reported as a 200 with a null label —
    // labelling must never surface as an error to the caller.
    return jsonResponse(req, { aiLabel: null });
  }
});
