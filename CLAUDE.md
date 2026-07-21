# Life OS — Project Context (for CC agents in Zed)

Life OS: a Flutter + Supabase AI life-management app. Killer feature = AI reads the user's Gmail,
extracts tasks, and tracks job applications. **Follow the global agent workflow in ~/.claude/CLAUDE.md**
(planner/worker roles, rounds, onboarding/offboarding, token discipline, novice guardrails).

## Stack & layout
Flutter 3.44 / Dart 3.12, Riverpod, GoRouter, Drift (local), Supabase (backend + AI Edge Functions
using Groq, model `llama-3.3-70b-versatile`). Feature-first architecture — mirror `lib/features/tasks/`
for new features. Supabase project ref: `ganbmkphtzdvxxnmprku`. CLI via `npx supabase` (no global
install, no Docker). Runs on Chrome for dev (`flutter run -d chrome`).

## Current state (2026-07-21) — origin/main @ c86a574 — LIVE IN PRODUCTION
WORKING: AI inbox scan (Gmail read SERVER-SIDE via a stored refresh token → Groq → tasks +
job-application updates), job tracker with manual add/edit/delete, tasks, unified timeline, AI Daily
Brief card, dark mode + theme toggle, 5-status job vocab (applied/viewed/interview/rejected/accepted),
AI Goal Breakdown (goal → Groq → reviewable tasks → saved linked via `tasks.goal_id`, derived progress).
Journal removed. Notes+Habits removed (79e38a1).
BACKEND: Edge Functions deployed: `extract-tasks`, `daily-brief`, `goal-breakdown`. Secrets set:
GROQ_API_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET. Migrations 001–012 applied. Per-user Gmail =
stored refresh token (`google_credentials`) minted server-side. Google OAuth app is still in TESTING
mode (test users only: jarrarzaid3@, zaidgpt3@) — hosted ≠ publicly usable.

## Hosting / deploy (live since 2026-07-21)
- **Production:** https://lifeos.deadthrone.dev   **Staging:** https://staging.lifeos.deadthrone.dev
- VPS is Ibrahim's (167.233.39.1). **Caddy serves the bundle off disk** from `~/lifeos/stable/` and
  `~/lifeos/staging/`. There is NO Docker, nginx, compose, or container — that plan was abandoned.
  Deploying = writing files; a build is live the moment rsync finishes. Ibrahim owns TLS/certs.
- **CI:** `.github/workflows/deploy.yml`. Push to `main` → stable; push to `staging` → staging; plus
  manual `workflow_dispatch`. Builds via `scripts/build-web.sh <env>` then a single
  `rsync -av --delete build/web/ ibrahim@167.233.39.1:<env>/`. ~2.5 min end to end.
- **The deploy key is restricted server-side** with `command="rrsync /home/ibrahim/lifeos",restrict`.
  It CANNOT open a shell or run remote commands. Never add an ssh/mkdir/restart step, and never pass
  exotic rsync flags like `--rsync-path` — the wrapper refuses them.
- GitHub Actions secrets: `VPS_DEPLOY_KEY`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
  `GOOGLE_CLIENT_ID`. Environments differ ONLY by `--dart-define=APP_ENV` (staging shows a banner).
  Both point at the SAME Supabase project — deliberate, not an oversight.

## Session handoff (2026-07-21, evening)
- **DONE (committed + pushed, LIVE on both envs @ `c86a574`):** AI Goal Breakdown full slice
  (migration 012 `tasks.goal_id`, `goal-breakdown` Edge Function, input→generate→review→save flow,
  derived goal progress); GitHub Actions CI deploy; `.env.example` public-asset warning; STAGING
  banner; abandoned Docker/nginx config deleted; `staging` branch created.
- **⚠️ KNOWN BUGS SHIPPED — fix these next (found by review, NOT yet fixed):**
  1. **Drift drops `goal_id` on native.** `task_local_data_source.dart` `_taskToCompanion` has no
     `goalId:` entry and `_taskFromEntry` omits `'goal_id'`, and the Drift `Tasks` table in
     `lib/core/services/app_database.dart` has no such column. Native writes local-first, so the
     value is discarded and later synced to Supabase as NULL. **Web is unaffected** (web uses
     `TaskRepositoryImpl.remoteOnly`) — which is why it passed testing and shipped.
  2. **`schemaVersion` still 1** with an empty `onUpgrade` stub. Adding the column above REQUIRES
     bumping to 2 + `m.addColumn(tasks, tasks.goalId)`. This is the repo's first real Drift migration.
  3. **Silent partial failure on save** (`goal_breakdown_screen.dart`). `TaskListNotifier.createTask`
     is optimistic and `unawaited(...)`s the write, so the screen's try/catch can only ever catch a
     GOAL failure. If tasks fail to persist, the user sees success and gets an orphaned goal.
     **This one DOES affect web/production.**
  - Lower priority: timezone off-by-one on `targetDate`; AI tasks carry UTC `DateTime`s while all
    others are local; home dashboard still shows raw `goal.progress` not derived; `goalId` param on
    `TaskEditorSheet` is dead code; archived tasks inflate the progress denominator.
- **OPEN DECISION (unanswered):** migration 012 uses `goal_id ... ON DELETE CASCADE`, so deleting a
  goal deletes all its tasks. Planner recommended `ON DELETE SET NULL` (tasks survive, unlinked).
  Needs Zaid's answer; changing it now means a small migration 013.
- **PENDING manual steps:** CONFIRMED DONE — migration 012 applied, `goal-breakdown` deployed, all 4
  GitHub secrets installed, Supabase redirect allowlist + Google console updated for the `.dev` domains.
  **UNCONFIRMED (carried over from the previous session, never verified):** whether the rewritten
  `daily-brief` function was ever deployed —
  `npx supabase functions deploy daily-brief --project-ref ganbmkphtzdvxxnmprku`. Symptom if not: the
  Daily Brief card reads generic rather than personal/specific. Cheap to just redeploy and check.
- **NOT VERIFIED THIS SESSION:** nobody has smoke-tested the LIVE production site end to end (login,
  inbox scan, goal breakdown). Staging was deployed and verified only at the HTTP level (200, correct
  title, correct bundle). Do this before treating prod as trusted.
- **TELL IBRAHIM:** his brief specified `rsync ... :~/lifeos/<env>/`, which FAILS — `rrsync` chroots to
  `/home/ibrahim/lifeos` and resolves paths relative to it, so `~` is taken literally and it tries
  `/home/ibrahim/lifeos/~/lifeos/<env>`. Correct destination is just `<env>/`.
- **NEXT:** fix the 3 known bugs above on the `staging` branch, verify on staging, then merge to `main`.
- **DECISIONS:** due dates mandatory on tasks. Staging + stable deliberately share ONE Supabase project
  (Zaid's call — do not re-litigate); therefore NEVER trial a migration on staging.

## Roadmap
1. **Pre-mobile refinement** (split worker rounds): ✅ Notes+Habits removed. ✅ Daily Brief made
   specific + Habits-free (`6c91fdd`). ✅ Due dates mandatory on tasks. ✅ `(+)` FAB Add Task/Add Goal
   chooser. ✅ AI Goal Breakdown shipped (with 3 known bugs — see handoff).
   **TODO: full QA / clean-code pass — never done, still outstanding.** This was the last planned item
   of this phase before hosting was prioritised ahead of it.
2. **Web hosting** ✅ DONE 2026-07-21 — live on prod + staging with CI (see "Hosting / deploy").
3. **Fix the 3 known Goal Breakdown bugs** (handoff section) — do this before mobile: bugs #1/#2 are
   Drift/native-only and would otherwise ambush the mobile round on day one.
4. **Mobile app version** (Android/iOS).
5. **Public launch**: Google OAuth verification (needed to leave Testing mode). Note the `gmail.readonly`
   sensitive scope makes this a real timeline risk — Google review is slow. Until then only
   jarrarzaid3@ / zaidgpt3@ can sign in, on ANY host.

## Hard-won gotchas (do NOT relearn these)
- Raw-SQL Supabase tables need explicit `GRANT ... TO authenticated, service_role` or they throw
  42501 permission-denied. RLS ≠ table grants. (See migrations 008/011. This bug bit us 3×.)
- Web OAuth `providerRefreshToken` is only present right after `Supabase.initialize()` in main() —
  capture it there, not in later listeners.
- Make every migration idempotent (`DROP POLICY IF EXISTS`, `IF NOT EXISTS`) — SQL gets re-run.
- The AI (Groq) sometimes returns job updates with no company; keep/persist them keyed by source_email_id.
- **`.env` is a PUBLIC WEB ASSET, not a secret store.** `pubspec.yaml` declares it as a Flutter asset,
  so it ships verbatim in the bundle and is downloadable at `/assets/.env`. Being gitignored makes it
  LOOK safe — it is the opposite. Only browser-public values (`SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_CLIENT_ID`) may live there. Server secrets (GROQ_API_KEY,
  service_role) go in Supabase Edge Function secrets. Need a 4th key? Stop and ask.
- `.env` is gitignored but REQUIRED to build, so any clean clone / CI job must materialize it first.
- Pin the CI Flutter version to one whose bundled Dart satisfies `pubspec`'s `sdk:` constraint —
  Flutter 3.44.0 ships Dart 3.12.0 and fails `^3.12.2`; 3.44.7 works.
- The VPS deploy key is `rrsync`-restricted and chroots to `/home/ibrahim/lifeos`: rsync destinations
  are RELATIVE to that root (`staging/`, not `~/lifeos/staging/`, which becomes a literal `~` path).
- Web and native take DIFFERENT persistence paths: web = `TaskRepositoryImpl.remoteOnly` (straight to
  Supabase), native = Drift local-first then sync. **A new Task column must be added to the Drift table
  AND `_taskToCompanion`/`_taskFromEntry`, or it silently vanishes on native while working fine on web.**
- Always confirm you're in `C:\Users\Zaid\Desktop\life-os` (a stale clone exists at Documents\github\life-os).
- VERIFY worker/agent reports independently: `git status`, `flutter analyze`, read the diff.

## Pending manual step
(none open — job_applications duplicate-cleanup was run 2026-07-21; future dupes are blocked by the
partial unique indexes from migration 010.)

## For WORKER agents (Zed CC) — read this before every task
You execute ONE well-scoped task from a planner-written prompt, then report. You make NO product
decisions. Standing rules (so prompts can stay short — these always apply even if the prompt omits them):
- **Confirm the working dir is `C:\Users\Zaid\Desktop\life-os`** — a stale clone exists at
  `Documents\github\life-os`; never edit that one.
- **Stay in scope.** Do only what the prompt asks. Do NOT touch `supabase/`, `.sql` migrations, secrets,
  or unrelated features unless the task explicitly says so.
- **Token discipline:** Grep to the target before reading; never Read a file >~400 lines without an
  offset/limit; NEVER re-read a file you just edited "to verify" (Edit fails loudly if it didn't apply).
- **Idempotent migrations only** if you ever write SQL (`DROP ... IF EXISTS`, `IF NOT EXISTS`).
- **Verify before reporting:** run `flutter analyze` (must be error-free) and `git status --short`.
- **Do NOT commit** unless the prompt tells you to — leave changes staged for the planner to review.
- **Report back:** full `flutter analyze` output, `git status --short`, and a one-line note per file
  changed. If something is ambiguous or you'd exceed scope, STOP and report — don't guess.
- Re-read "Hard-won gotchas" above; they still apply.

## Worker prompt template (planner reuse)
> **You are a WORKER agent** (Sonnet, in Zed) — execute this ONE task exactly, make no product
> decisions, then report. This prompt is self-contained; do not assume any prior context.
> **Task:** <one deliverable, imperative>. **Working dir:** `C:\Users\Zaid\Desktop\life-os`.
> **Do:** <specific files/changes, with known touchpoints>.
> **Do NOT touch:** <explicit out-of-scope list, always incl. `supabase/` unless intended>.
> **Acceptance criteria:** `flutter analyze` error-free; <feature-specific checks>; correct files changed.
> **Report:** `flutter analyze` output + `git status --short` + one line per changed file. Do NOT commit.
