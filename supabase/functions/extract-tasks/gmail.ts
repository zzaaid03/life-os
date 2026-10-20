const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID");
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET");

// --- Google token: mint a fresh access token from a stored refresh token ---
export async function accessTokenFromRefresh(refreshToken: string): Promise<string> {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    throw new Error("GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET not configured");
  }
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) {
    throw new Error(`Google token refresh ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

// --- Gmail helpers (bodies stay server-side) ---

interface GmailPart {
  mimeType?: string;
  body?: { data?: string };
  parts?: GmailPart[];
  headers?: { name: string; value: string }[];
}

function decodeBase64Url(data: string): string {
  const b64 = data.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(b64);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function findPart(payload: GmailPart | undefined, mime: string): string | null {
  if (!payload) return null;
  if (payload.mimeType === mime && payload.body?.data) return payload.body.data;
  for (const p of payload.parts ?? []) {
    const d = findPart(p, mime);
    if (d) return d;
  }
  return null;
}

function extractBody(payload: GmailPart | undefined): string {
  const plain = findPart(payload, "text/plain");
  if (plain) return decodeBase64Url(plain);
  const html = findPart(payload, "text/html");
  if (html) return decodeBase64Url(html).replace(/<[^>]+>/g, " ");
  if (payload?.body?.data) return decodeBase64Url(payload.body.data);
  return "";
}

// Local calendar date (yyyy-mm-dd) for an epoch, shifted by the caller's UTC offset.
// The model resolves "by Friday" against these, so they must be the user's dates and
// not the server's. Same tzOffsetMinutes contract daily-brief already uses.
export function localDate(epochMs: number, tzOffsetMinutes: number): string {
  return new Date(epochMs + tzOffsetMinutes * 60_000).toISOString().slice(0, 10);
}

function gmailFetch(accessToken: string, path: string): Promise<Response> {
  return fetch(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(15_000),
  });
}

// Lists inbox message ids inside a rolling horizon, newest first (Gmail's own
// order), without fetching any body. One page only (500 ids) — if Gmail says
// there's more, `capped` is set so the caller can report it, but we never
// page further in a single request.
export async function listInboxIds(
  accessToken: string,
  horizonDays: number,
): Promise<{ account: string; ids: string[]; capped: boolean }> {
  // Which Google account does this token actually belong to?
  let account = "";
  const profileRes = await gmailFetch(accessToken, "profile");
  if (profileRes.ok) {
    account = (await profileRes.json()).emailAddress ?? "";
  }

  const afterEpochSeconds = Math.floor(Date.now() / 1000) - horizonDays * 86400;
  const listRes = await gmailFetch(
    accessToken,
    `messages?maxResults=500&labelIds=INBOX&q=${encodeURIComponent(`after:${afterEpochSeconds}`)}`,
  );
  if (!listRes.ok) {
    throw new Error(`Gmail list ${listRes.status}: ${(await listRes.text()).slice(0, 200)}`);
  }
  const { messages = [], nextPageToken } = await listRes.json();
  const ids = messages.map((m: { id: string }) => m.id as string);
  return { account, ids, capped: Boolean(nextPageToken) };
}

// Gets one message, retrying 429/5xx twice. Returns null for a 404 (message
// deleted since it was listed). Any other failure throws, so the caller never
// sees a blank email that was not really read.
async function fetchMessage(accessToken: string, id: string) {
  for (let attempt = 0; ; attempt++) {
    const r = await gmailFetch(accessToken, `messages/${id}?format=full`);
    if (r.ok) return await r.json();
    if (r.status === 404) {
      await r.body?.cancel();
      return null;
    }
    const retryable = r.status === 429 || r.status >= 500;
    if (retryable && attempt < 2) {
      await r.body?.cancel();
      const retryAfter = Number(r.headers.get("retry-after"));
      const waitMs = Number.isFinite(retryAfter) && retryAfter > 0
        ? Math.min(retryAfter, 5) * 1000
        : 1000 * (attempt + 1);
      await new Promise((res) => setTimeout(res, waitMs));
      continue;
    }
    const text = (await r.text()).slice(0, 200);
    throw new Error(`Gmail message ${id} ${r.status}: ${text}`);
  }
}

// Fetches full bodies for exactly the given ids (a selected batch, not "recent N"),
// at most 10 at a time. Deleted messages (404) are left out of the result.
export async function fetchEmailBodies(
  accessToken: string,
  ids: string[],
  tzOffsetMinutes: number,
) {
  const out = [];
  for (let i = 0; i < ids.length; i += 10) {
    const group = ids.slice(i, i + 10);
    const emails = await Promise.all(
      group.map(async (id: string) => {
      const m = await fetchMessage(accessToken, id);
      if (m === null) return null;
      const headers = m.payload?.headers ?? [];
      const h = (n: string) =>
        headers.find((x: { name: string }) => x.name.toLowerCase() === n.toLowerCase())
          ?.value ?? "";
      const body = extractBody(m.payload).replace(/\s+/g, " ").trim().slice(0, 1500);
      // internalDate (epoch ms, Gmail's own receipt time) rather than the Date
      // header, which is free-form and sometimes absent or forged.
      const epoch = Number(m.internalDate);
      const sentDate = Number.isFinite(epoch)
        ? localDate(epoch, tzOffsetMinutes)
        : null;
      return { id, from: h("From"), subject: h("Subject"), sentDate, body };
      }),
    );
    for (const e of emails) if (e) out.push(e);
  }
  return out;
}
