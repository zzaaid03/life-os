# Life OS — Project Context (for CC agents in Zed)

Life OS: a Flutter + Supabase AI life-management app. Killer feature = AI reads the user's Gmail,
extracts tasks, and tracks job applications. **Follow the global agent workflow in ~/.claude/CLAUDE.md**
(planner/worker roles, rounds, onboarding/offboarding, token discipline, novice guardrails).

## Stack & layout
Flutter 3.44 / Dart 3.12, Riverpod, GoRouter, Drift (local), Supabase (backend + AI Edge Functions
using Groq, model `llama-3.3-70b-versatile`). Feature-first architecture — mirror `lib/features/tasks/`
for new features. Supabase project ref: `ganbmkphtzdvxxnmprku`. CLI via `npx supabase` (no global
install, no Docker). Runs on Chrome for dev (`flutter run -d chrome`).

## Current state (2026-07-21) — origin/main @ f620639 — LIVE IN PRODUCTION
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

## Session handoff (2026-07-21, late evening)
- **DONE (LIVE IN PRODUCTION @ `f620639`):** all 3 known Goal Breakdown bugs from the previous
  handoff are FIXED, verified by diff-trace (not by worker report), and deployed:
  1. Drift now persists `goal_id` — column added to the `Tasks` table, mapped in BOTH
     `_taskToCompanion` and `_taskFromEntry`. Round-trip verified end to end via `Task.toJson()`.
  2. `schemaVersion` bumped 1 → 2 with a `if (from < 2) m.addColumn(tasks, tasks.goalId)` guard.
     This is the repo's first real Drift migration. Native-only; untested until the mobile round.
  3. Goal-save now writes through `taskRepositoryProvider` and AWAITS it, so real task-persistence
     failures reach the screen's catch instead of showing false success.
- **ON `staging`, NOT YET IN PROD — awaiting Zaid's manual test:** goal-delete confirmation dialog
  (`confirmDismiss` on the `Dismissible` in `goals_screen.dart`, names the goal + linked task count)
  and cascade delete (`GoalListNotifier.deleteGoal` now deletes the goal first, then its linked
  tasks). Merge to `main` only after Zaid confirms: Cancel truly cancels, and unlinked tasks survive.
- **RESOLVED DECISION — cascade:** Zaid chose to DELETE linked tasks when a goal is deleted
  (chose "A" over unlink-and-keep, with the tradeoff explained). Do not re-litigate. Note migration
  012's `ON DELETE CASCADE` is INERT — the goal repo soft-deletes (sets `deleted_at`) and never
  issues a SQL DELETE, so the cascade is implemented in Dart, not by the DB.
- **RESOLVED:** `daily-brief` IS deployed and working (Zaid confirmed). Prod smoke-test done by Zaid.
- **NOT A BUG — the "job applications leak" scare:** friends reported seeing each other's job
  applications. Investigated: RLS on `job_applications` is correct (`auth.uid() = user_id` on all
  4 verbs), no migration weakens it, and `getAll` filters by `user_id`. Root cause was that Google
  OAuth was in Testing mode with only Zaid's 2 accounts allowed, so friends signed in AS ZAID.
  Zaid has since added them as test users. **Lesson: verify the isolation layers before believing a
  breach report — and note a shared test account also shares the stored Gmail refresh token.**
- **REMAINING QA-ROUND WORK (all located, none fixed):**
  - Derived progress read RAW at TWO sites: `home_screen.dart:207`, `timeline_provider.dart:93`
    (`goals_screen.dart:154-156` already does it correctly).
  - Archived tasks inflate the progress denominator — `goal_provider.dart:167-187` filters only on
    `goalId`, never excludes `TaskStatus.archived`. Also skews the delete dialog's task count.
  - Timezone: `goal.dart:115` emits naive local `toIso8601String()` into a `DATE` column;
    `goal_breakdown_service.dart:82` sends it naive to the Edge Function, which does `new Date()`
    (JS parses bare dates as UTC) — horizon can shift a day.
  - UTC/local mix: `goal_breakdown_service.dart:41` parses server `...Z` with NO `.toLocal()`, so AI
    task dueDates are `isUtc == true` while hand-made ones are local.
  - `goalId` param on `TaskEditorSheet` (`:27,149`) IS consumed in the create branch but NO call site
    passes it, and the edit branch drops it. `goal_breakdown_screen.dart:150` is where it belongs.
  - **Show the signed-in account in the UI** — would have prevented the entire OAuth scare above.
- **TELL IBRAHIM:** his brief specified `rsync ... :~/lifeos/<env>/`, which FAILS — `rrsync` chroots to
  `/home/ibrahim/lifeos` and resolves paths relative to it, so `~` is taken literally and it tries
  `/home/ibrahim/lifeos/~/lifeos/<env>`. Correct destination is just `<env>/`.
- **MINOR:** CI warns `actions/checkout@v4` + `ssh-agent@v0.9.0` still target Node 20. One-line bump
  whenever the workflow is next touched; not worth its own round.
- **NEXT:** merge staging→main once Zaid's delete test passes, then run the QA round above.
- **DECISIONS:** due dates mandatory on tasks. Staging + stable deliberately share ONE Supabase project
  (Zaid's call — do not re-litigate); therefore NEVER trial a migration on staging.

## Roadmap
1. **Pre-mobile refinement** (split worker rounds): ✅ Notes+Habits removed. ✅ Daily Brief made
   specific + Habits-free (`6c91fdd`). ✅ Due dates mandatory on tasks. ✅ `(+)` FAB Add Task/Add Goal
   chooser. ✅ AI Goal Breakdown shipped (with 3 known bugs — see handoff).
   **TODO: full QA / clean-code pass — never done, still outstanding.** This was the last planned item
   of this phase before hosting was prioritised ahead of it.
2. **Web hosting** ✅ DONE 2026-07-21 — live on prod + staging with CI (see "Hosting / deploy").
3. **Fix the 3 known Goal Breakdown bugs** ✅ DONE 2026-07-21, live @ `f620639`. Mobile is unblocked.
   **QA round IN FLIGHT:** goal-delete confirm + cascade on `staging` awaiting test; the rest of the
   QA list is in the handoff section (derived progress ×2, archived denominator, timezone, UTC mix,
   dead `goalId` param, show-signed-in-account).
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
- **Soft deletes make DB `ON DELETE CASCADE` inert.** Goals and tasks soft-delete (set `deleted_at`)
  and never issue a SQL `DELETE`, so FK cascades declared in migrations NEVER fire from the app. Any
  cascade behaviour must be written in Dart. Don't assume a migration's `ON DELETE` clause is live.
- **A "security breach" report is usually a config problem.** Before believing cross-user data leaks,
  check the isolation layers (RLS policies, `.eq('user_id')`, then `select relrowsecurity from
  pg_class`). While Google OAuth is in Testing mode, only listed test users can sign in — so testers
  end up sharing ONE account, which looks exactly like a leak and also shares that account's stored
  Gmail refresh token. Client-side `.eq()` filters are NOT security; only RLS is (the publishable
  key ships in the public bundle).
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
