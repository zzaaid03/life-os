# Life OS: project context for agents

Life OS is a Flutter + Supabase life-management app. Its main feature: the AI reads the user's Gmail,
extracts tasks, tracks job applications and subscriptions, and helps with goals and cooking.
Follow the global agent workflow in `~/.claude/CLAUDE.md` (planner/worker roles, rounds, token rules).

@_planning/STATE.md

The import above is gitignored and holds the live state, infra details and open findings. If it is
missing (fresh clone), ask Zaid before assuming anything about production. Long-form history lives in
`_planning/history.md`. Read it only when a task needs the story behind a decision.

## Stack & layout
- Flutter 3.44 / Dart 3.12, Riverpod, GoRouter, Drift (local, tasks only), Supabase (Postgres, Auth,
  Storage, Edge Functions in Deno).
- Feature-first: `lib/features/<feature>/{data,domain,presentation}`. Mirror `lib/features/tasks/`.
  Shared code goes in `lib/core/` (e.g. `core/utils/date_format.dart` for every user-facing date).
- Edge functions: `supabase/functions/<name>/index.ts`. Every model call goes through ONE client,
  `supabase/functions/_shared/ai.ts` (`chatJson`). Provider, model and key are secrets
  (`AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL`, `AI_REASONING_EFFORT`); currently OpenAI.
- Functions: `extract-tasks` (inbox scan), `daily-brief` (no model, assembled in code),
  `goal-breakdown`, `infer-facts`, `label-file`, `recipe-chef`.
- Migrations: `supabase/migrations/NNN_name.sql`, numbered, idempotent. There is deliberately NO
  `supabase/config.toml`; do not create one (a later `config push` could overwrite hosted auth
  settings, including the OAuth redirect allow-list).
- Platforms: web (CanvasKit, self-hosted engine and fonts), Android, iOS (unsigned IPA built in CI,
  sideloaded). Web uses `TaskRepositoryImpl.remoteOnly`; native is Drift local-first then sync.

## Commands
- `flutter analyze` (must be clean) and `flutter test` (CI runs it; a red suite blocks deploys).
- `flutter run -d chrome` for dev.
- `deno check supabase/functions/<name>/index.ts` to typecheck a function. Also check an untouched
  function as a control so a pass means something.
- Web build: `scripts/build-web.sh <env>` (CI) and `scripts/build-web.ps1` (local twin). Keep them in sync.
- iOS compile check for Swift/native changes: `gh workflow run "Build iOS IPA (unsigned)" --ref <branch>`.
- Pushing `main` deploys production, pushing `staging` deploys staging (`.github/workflows/deploy.yml`).
- NEVER run `npx supabase db push` or `functions deploy` as a worker. They hit production instantly.

## Quality bar (every change, every agent)
These turn Zaid's four goals into rules. A diff that breaks one is not done.

**1. No spaghetti**
- Do not push a file past 600 lines. If a screen is already over, put new widgets in their own file.
- Widgets call notifiers/providers, never repositories directly. Multi-step writes belong in a
  notifier or repository, not in `onPressed`.
- Before writing a helper, grep `lib/core/` and `supabase/functions/_shared/` for an existing one.
  Shared edge-function code (CORS, `jsonResponse`, auth) belongs in `_shared/`.
- When your change orphans code (a provider, a file, a param), delete it.

**2. Secure**
- An edge function gets the user ONLY from the JWT (`auth.getUser`). Never trust a user id, token or
  ownership claim from the request body.
- Cap every string and array that comes from a request before using it or sending it to a model.
- Every model call goes through `chatJson`, the one place where spend limits are enforced.
  No direct provider fetch.
- Every new table: RLS on, policies scoped to `auth.uid()`, `WITH CHECK` on INSERT/UPDATE, grants to
  `authenticated, service_role` only. Never grant to `anon`, even if a Postgres error hint suggests it.
- `.env` ships inside the public web bundle. Only browser-public values may live there.

**3. Survives real users**
- No `catch` that drops the error. Surface it to the user or log it. "Failed" must never look like
  "empty" or "nothing found".
- Every list query has a `.limit()`/`.range()` or a comment saying why not. Counts use
  `{ count: "exact" }`, never `.length` of a limited query.
- Every outbound `fetch` checks `res.ok` and has a timeout.
- Never mark work done (processed, synced, seen) before it actually succeeded.
- A column you filter or sort on needs an index.

**4. Token-cheap**
- Grep to the target, then read a line range. Never whole-read a file over ~400 lines.
- Never re-read a file you just edited to verify it.
- Reports are terse: `flutter analyze` result, `git status --short`, one line per changed file.

## Gotchas (do not relearn these)
**Data and Supabase**
- Raw-SQL tables need explicit `GRANT ... TO authenticated, service_role`, or the client gets 42501.
  RLS and grants are separate layers.
- Soft deletes (`deleted_at`) mean `ON DELETE CASCADE` never fires from the app. Cascades are in Dart.
- `handle_new_user()` creates a `profiles` row at sign-up, so `profile == null` is not a "new user"
  signal. Onboarding uses a per-user SharedPreferences flag.
- `signUp` can return a user with `session == null` (email confirmation pending). Check the session.
- A new Task column must be added to the Drift table AND both mappers, or it silently vanishes on
  native while working on web.
- Store datetimes as UTC, display local. Server code that says "today" needs the client's
  `tzOffsetMinutes`; due dates are local midnight stored as UTC.
- Make migrations idempotent (`IF NOT EXISTS`, `DROP ... IF EXISTS`, `OR REPLACE`). SQL gets re-run.
- RLS test harnesses: `SET LOCAL role` outside a transaction is ignored and you test as superuser.
  Rehearse migrations with `supabase start` in a TEMP dir, never in the repo.
- A negative test ("I can't see it") proves nothing unless some screen could have shown it.

**AI and edge functions**
- Every prompt must contain the word "JSON" (OpenAI json_object mode requires it). Keep it that way.
- Reasoning models reject `max_tokens` and reject `temperature` while reasoning is on. `chatJson`
  handles both.
- temperature 0 kills creative features (same "surprise" every time). Extraction uses 0.
- A worked example (exact input, exact correct JSON) beats an abstract rule in a prompt. Ban a
  category of bad output, not a list of words.
- Money and dates are computed in Dart, never by the model. The model copies literal text.
- Never hand raw model JSON to the app: sanitize it into the Dart model's contract first
  (see `sanitizeRecipe`).
- Never key an identity match on more than one AI-extracted field; they drift between emails.
- On failure, write nothing. Never blank an existing field because a model call failed.
- A longer system prompt is paid on every request; re-check the batch's token budget when it grows.
- Clamp limits on the SERVER. Installed mobile builds cannot be fixed by a client-only change.
- Use "assemble in code" for reporting facts from rows, and the model for judgement.
- Isolate a provider failure with one tiny hand-sent request before changing code.

**Flutter and platforms**
- An unawaited Future inside `try` makes the `catch` dead code. Fire-and-forget is
  `unawaited(f.catchError(...))`.
- `Image.network` with `cacheWidth` still downloads the full image. List thumbnails come from the
  stored `thumbnail_base64`.
- A provider with no consumer is never created. When you delete a screen, check its providers.
- Notification ids: reminders below `kCookTimerIdBase` (100000), cook timers above. Any new
  notification type needs its own id range.
- Web must not load anything from a Google CDN. New font weights/styles go into
  `assets/google_fonts/` as TTFs or they fail to load.
- Do not run `dart format` on recipe files you only touched; it rewraps them.
- Read the INSTALLED package source/README for plugin APIs, not memory or tutorials.
- Android plugin builds need core library desugaring and compileSdk 36 forced for plugins
  (`android/build.gradle.kts`). A green web or iOS build says nothing about Android.
- iOS bundle id is `com.lifeos.app.zaid`, but the OAuth URL scheme stays `com.lifeos.app`.
  The mismatch is deliberate.

**Process**
- Verify reports (workers, partners, CI) against the real thing: read the diff, curl with a
  cache-busting query, grep the code. Use a control.
- Fix the bug class, not the instance: grep every copy before calling it fixed.
- Before blaming your change for a failing test, check whether it failed on clean `HEAD`.
- With parallel workers in the tree, stage explicit paths, never `git add -A`.
- Search for multi-byte characters with ripgrep `\x{2014}` escapes, not bash bracket expressions.

## For WORKER agents (Zed CC): read this before every task
You execute ONE well-scoped task from a planner-written prompt, then report. You make NO product decisions.
- Confirm the working dir is `C:\Users\Zaid\Desktop\life-os` (a stale clone exists at
  `Documents\github\life-os`; never edit that one).
- Stay in scope. Do not touch `supabase/`, migrations, secrets or unrelated features unless the
  prompt says so. Never run Supabase CLI commands that touch the remote project.
- Follow the Quality bar above. If the task would force you to break it, stop and report.
- Verify before reporting: `flutter analyze` (error-free), plus `deno check` for any function you touched.
- Do NOT commit unless the prompt says so.
- Report: analyze output, `git status --short`, one line per changed file. If something is ambiguous
  or out of scope, STOP and report instead of guessing. List out-of-scope problems you noticed.
- Public repo: comments, commit messages and copy must read like Zaid wrote them. No em or en dashes,
  no AI attribution anywhere.

## Worker prompt template (planner reuse)
> **You are a WORKER agent** (Sonnet, in Zed). Execute this ONE task exactly, make no product
> decisions, then report. This prompt is self-contained; do not assume any prior context.
> **Task:** <one deliverable>. **Working dir:** `C:\Users\Zaid\Desktop\life-os`.
> **Do:** <files/changes, known touchpoints>.
> **Do NOT touch:** <out-of-scope list, always incl. `supabase/` unless intended>.
> **Acceptance:** `flutter analyze` clean; <feature checks>; Quality bar respected.
> **Report:** analyze output + `git status --short` + one line per changed file. Do NOT commit.
