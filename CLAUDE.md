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

## Session handoff (2026-07-22, late — QA-CORRECTNESS ROUND)
- **WORKFLOW DIRECTIVE (unchanged):** ALL work stays on `staging`; do NOT merge to `main` / deploy
  stable until Zaid explicitly says so. Actions, not questions.
- **GIT STATE:** `staging` @ `958dee4` (pushed, clean tree; 5 commits ahead of the evening handoff's
  `41ffd71`). `main` still @ `f620639` (untouched). Everything below is **staging only**.
- **QA-CORRECTNESS ROUND — the previously-"still-outstanding" bugs are now ALL FIXED (commits
  `294a7ee`..`958dee4`). Bugs 2–5 Zaid-tested 100%; #1 (dashboard) + #6 (calendar) PENDING his visual
  test (pushed, awaiting CI + his check):**
  1. ✅ **Derived-progress raw reads (Bug A)** — home goal card + timeline now route through
     `goalTaskCountProvider`/`goalProgressProvider` (derived % when ≥1 linked task, else manual
     `goal.progress`), mirroring goals_screen. `294a7ee`.
  2. ✅ **Archived denominator (Bug B)** — added `t.status != TaskStatus.archived` to BOTH goal
     providers; also fixes the delete-dialog linked-task count. `294a7ee`. *(Zaid: 100%.)*
  3. ✅ **Timezone (Bug C)** — all goal DateTimes normalized to **store-UTC / display-local**
     (`.toLocal()` on reads, `.toUtc().toIso8601String()` on writes) across `goal.dart` (target/synced/
     created/updated/deleted) + `goal_breakdown_service.dart` (suggestedDueDate/targetDate). `5dd42c0`.
     *(Zaid: 100%. NB: pre-existing rows may render one day off ONCE on first load, then stay consistent — expected, not a bug.)*
  4. ✅ **Dead `goalId` param removed** from `TaskEditorSheet` (no call site supplied it; goal-linked
     path builds its Task at `goal_breakdown_screen.dart:217`). `2f3566f`. *(Zaid: 100%.)*
  5. ✅ **Explicit "Delete goal" button** in `_GoalEditorDialog` (edit mode only), reuses the swipe
     path's confirm+delete+refresh via a shared `_deleteWithConfirm`; swipe still single-confirms. `2f3566f`. *(Zaid: 100%.)*
  6. ✅ **Dashboard: Goals surfaced higher** — moved the goals block up to right after "Focus for Today"
     (was dead-last under a "Life" heading), renamed the header "Life"→"Goals". `c54056c`. **PENDING Zaid visual test.**
  7. ✅ **Timeline = calendar-only + task titles in cells** — removed the old chronological event list
     and its now-dead helpers (`_groupByDay`/`_DayHeader`/`_TimelineTile`); redesigned the
     `table_calendar` in `calendar/presentation/widgets/calendar_view.dart`: taller cells
     (`rowHeight:82`), each day cell shows task TITLES as text (up to 2 + "+N") instead of dots,
     days-with-tasks tinted (`primary@12%`, selected @25%+border, today border) via `calendarBuilders`;
     `eventLoader`/marker knobs removed; the tap-a-day task list below is retained. `958dee4`. **PENDING Zaid visual test.**
- **NEXT:** once Zaid OKs #1 + #6 → the QA/clean-code phase is fully closed. Then his open call is:
  (a) **merge staging→main / deploy stable** — REQUIRES the SW-cache fix FIRST (see evening handoff), or
  (b) **start the mobile track**. Nothing new is locked.
- All other cautions from the evening handoff below still apply (edge-fns NOT staging-isolated;
  SW-cache to-do before stable; TELL IBRAHIM the rsync `~` bug; Node-20 CI bump).

## Session handoff (2026-07-22, evening — ROADMAP CLEARED)
- **WORKFLOW DIRECTIVE (still active):** ALL work stays on `staging`. Do NOT merge `staging → main`
  or deploy the web bundle to stable until Zaid EXPLICITLY says "merge"/"move to stable". Staging is
  the only surface. He wants ACTIONS, not questions — decide and produce.
- **GIT STATE:** `staging` @ `d623d68` (pushed, clean tree). `main` still @ `f620639` (untouched —
  none of this round is on `main`). Everything below is live on **staging only**.
- **THE ENTIRE 9-ITEM LOCKED PLAN IS DONE + Zaid-tested on staging this session:**
  1. ✅ **Tighten job-extraction prompt** (`extract-tasks/index.ts`) — DEPLOYED to the shared Supabase
     project (live for all test users; it's only-stricter so net-safe). Recipient's-own-application-only
     + exclude-list (alerts/recruiters/newsletters) + ambiguity→SKIP; `applied` no longer a catch-all.
  2. ✅ **Job-update review step (Option B)** — job updates matching an EXISTING application auto-apply
     silently; brand-NEW applications now surface as Add/Dismiss cards (no more silent auto-persist).
     `job_application_repository.applyKnownAndCollectNew` + `_findExistingId`; card UI in `inbox_scan_screen`.
  3. ✅ **Dedup guard** — job updates now filtered through `processed_emails` like tasks (combined
     `getProcessedIds`/`markProcessed`), so they stop "respawning" every scan.
  4. ✅ **Onboarding / "What's New" engine** — new `lib/features/onboarding/`: versioned `kReleases`
     list drives BOTH first-run tour AND future What's-New (bump a version + append a `Release` to
     announce). SharedPreferences-backed `acknowledgedVersion` (local, `loaded` guard). Modal carousel
     shown after sign-in on home; re-openable via Settings → About → "What's new". (Show-signed-in-account
     was ALREADY done — Settings → Account shows the email — so no rebuild.)
  5. ✅ **Apple-style month calendar in Timeline** — new `lib/features/calendar/`, uses `table_calendar`
     (dependency added), tasks-by-due-date dots + selected-day list, theme-driven (light+dark).
  6. ✅ **Smooth theme switch (was the #9 full-page-reload bug)** — ROOT CAUSE was `createRouter` called
     inside `LifeOSApp.build()` and `ref.watch`ing auth/profile, so ANY rebuild (incl. theme) rebuilt the
     GoRouter and reset navigation. FIX: `routerProvider = Provider<GoRouter>(createRouter)` (built once);
     redirects re-run via a `refreshListenable` (ValueNotifier bumped by `ref.listen` on auth+profile);
     `main.dart` now `ref.watch(routerProvider)`. Auth redirects re-verified by Zaid on staging.
  6b. ✅ **Light-mode color tuning** (folded into #6) — the `(+)` chooser text was unreadable: light
     `ColorScheme` set `primaryContainer` but not `onPrimaryContainer` (fell back to a washed default).
     Fixed by `onPrimaryContainer: AppColors.primaryDark` in `app_theme.dart`; also softened the sheet's
     modal `barrierColor` to black@32% for a lighter light-mode dim. (If Zaid ever wants the chooser
     tiles bolder, switch them to solid `primary` bg + white `onPrimary` text — one-line, offered & declined.)
  7. ✅ **"Sign Out" → "Log out"** (`settings_screen.dart`).
  8. ✅ **Tagline** → "What are you looking for?" (+ hint "Search anything…") in `search_screen.dart`.
  9. ✅ (== #6 above.)
- **CAUTION — EDGE FUNCTIONS / MIGRATIONS ARE NOT STAGING-ISOLATED.** ONE Supabase project is shared by
  staging + stable, so `npx supabase functions deploy` and any migration go LIVE FOR ALL TEST USERS
  instantly. The extract-tasks deploy (#1) was net-safe (only-stricter). Always TELL Zaid before deploying.
- **PRODUCTION SERVICE-WORKER CACHE — TO-DO before/at merge-to-stable:** Flutter web installs a service
  worker that serves the OLD bundle first and updates only in the background — so users see stale UI until
  a SECOND visit (bit us HARD this session: repeated "nothing changed" that was pure cache; only
  clear-site-data / truly-fresh incognito showed new builds). When merging to stable, add a cache-busting
  step (e.g. version-stamp `index.html`/asset URLs, or a SW update-and-reload prompt) so real users get
  updates on first load. Not urgent while staging-only, but MUST be handled before public launch.
- **STILL-OUTSTANDING QA correctness bugs — ✅ ALL FIXED in the 2026-07-22 LATE round (see the
  QA-CORRECTNESS handoff section above for commit-by-commit detail): derived-progress raw reads,
  archived denominator, timezone naive-local, dead `goalId` param, swipe-only goal delete.** (Line
  numbers in the old bullets were already stale — the fixes were re-mapped fresh before editing.)
- **TELL IBRAHIM (still open):** his brief's `rsync ... :~/lifeos/<env>/` FAILS — `rrsync` chroots to
  `/home/ibrahim/lifeos`, so `~` is literal. Correct destination is just `<env>/`.
- **MINOR:** CI `actions/checkout@v4` + `ssh-agent@v0.9.0` still target Node 20 — one-line bump when the
  workflow is next touched.
- **DECISIONS:** due dates mandatory on tasks. Staging + stable deliberately share ONE Supabase project
  (do not re-litigate); therefore NEVER trial a migration OR an edge-function change on staging alone.
  Cascade = DELETE linked tasks on goal delete (implemented in Dart; migration 012's `ON DELETE CASCADE`
  is INERT because goals soft-delete). `daily-brief` deployed & working. Onboarding/theme prefs are LOCAL
  (SharedPreferences) — per-device, re-shows if cache cleared; upgrade to a server flag when mobile lands.

## Roadmap
1. **Pre-mobile refinement** (split worker rounds): ✅ Notes+Habits removed. ✅ Daily Brief made
   specific + Habits-free (`6c91fdd`). ✅ Due dates mandatory on tasks. ✅ `(+)` FAB Add Task/Add Goal
   chooser. ✅ AI Goal Breakdown shipped (with 3 known bugs — see handoff).
   **TODO: full QA / clean-code pass — never done, still outstanding.** This was the last planned item
   of this phase before hosting was prioritised ahead of it.
2. **Web hosting** ✅ DONE 2026-07-21 — live on prod + staging with CI (see "Hosting / deploy").
3. **Fix the 3 known Goal Breakdown bugs** ✅ DONE 2026-07-21, live @ `f620639`. Mobile is unblocked.
   **QA + polish round ✅ DONE on `staging` @ `d623d68` (NOT on `main`), Zaid-tested 2026-07-22 eve:**
   goal-delete cascade; the whole job-extraction fake-application bug (prompt + review step + dedup);
   onboarding/What's-New engine; Apple-style Timeline calendar; smooth theme switch (router-rebuild fix);
   light-mode chooser readability; "Log out" wording; new search tagline. See handoff for details.
   **QA-correctness bugs ✅ ALL FIXED on `staging` @ `958dee4` (2026-07-22 late):** derived-progress
   raw reads, archived denominator, timezone (store-UTC/display-local), dead `goalId` param, explicit
   goal-delete button — PLUS dashboard goals surfaced higher and Timeline redesigned to a calendar-only
   view with task titles inside day cells (#1/#6 pending Zaid's visual test). See the QA-CORRECTNESS
   handoff section for commit-by-commit detail. **QA/clean-code phase effectively closed pending #1/#6 sign-off.**
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
