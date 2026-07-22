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

## Session handoff (2026-07-22)
- **WORKFLOW DIRECTIVE (Zaid, this session):** ALL work happens on `staging` from now on. Do NOT
  merge `staging → main` or deploy the web bundle to stable until Zaid EXPLICITLY says "merge"/"move
  to stable". Until then, staging is the only surface. He wants ACTIONS, not questions — decide and
  produce; don't stall asking things he can answer by testing.
- **CONFIRMED DONE (on `staging` @ `9ba21e6`, NOT on `main`):** goal-delete confirm dialog + cascade
  delete. Zaid tested it and reports it "works 100%". It is still `staging`-only per the directive
  above — `main` remains @ `f620639`. `staging` is 5 commits ahead of `main` (the whole goal-delete
  round). Cancel cancels, cascade deletes linked tasks, unlinked tasks survive — all confirmed.
- **ORPHAN-TASK CLEANUP — done per Zaid (NOT independently verified; planner has no DB access):**
  pre-cascade orphans (live tasks whose goal was soft-deleted) were cleaned via a soft-delete UPDATE
  (`SET deleted_at = NOW()` on `tasks` where `goal_id` → a `goals` row with `deleted_at IS NOT NULL`).
  Soft-delete was chosen to match the app + stay reversible. Zaid said "everything is perfect" after.
- **CONFIRMED REAL BUG — AI manufactures fake job applications (code-verified this session):** two
  friends (now real test users signing in with their OWN Gmail) reported job applications for jobs
  they never applied to ("respawned" every scan). An Explore agent traced it to THREE stacked defects:
  1. **Loose prompt** — `supabase/functions/extract-tasks/index.ts` `SYSTEM_PROMPT` told the model to
     emit a job update for "any email about job applications OR opportunities" and had a catch-all
     forcing ambiguous job-related emails (recruiter nudges, expiring postings) into `status: applied`.
     So alerts/recruiter mail/newsletters became "applications you submitted." No "did the user apply?"
     guard anywhere.
  2. **No review step** — extracted TASKS get an Add/Dismiss confirm; job updates AUTO-PERSIST silently
     (`inbox_scan_provider.dart:117-122` → `job_application_repository.dart:36-103 upsertFromScan`).
  3. **No dedup guard** — tasks are deduped against `processed_emails` (`inbox_scan_provider.dart:96-115`)
     but job updates BYPASS it, so the same email re-surfaces a job row on every scan (= "respawned").
  Idempotency of job rows today: `(user_id, company, role)` if company present, else
  `(user_id, ''  , source_email_id)`, else unconditional insert (can duplicate).
- **THE LOCKED PLAN (Zaid's priority order, all on `staging`):**
  1. **Tighten extraction criteria** (Lever 1) — stricter prompt. ✅ WORKER PROMPT ISSUED this session
     (rewrite the `=== JOB UPDATES ===` block: only the recipient's OWN application lifecycle; explicit
     exclude-list for alerts/recruiters/newsletters; ambiguity → SKIP, never `applied`). AWAITING the
     worker's report — successor's FIRST job is to verify that diff, then deploy + real-scan test.
  2. **Add a review step** (Lever 2) — make job updates reviewable/confirmable like tasks (stop auto-persist).
  3. **Add the dedup guard** (Lever 3) — route job updates through the `processed_emails` check.
  4. **Onboarding / "What's New" system** (upgraded Bucket A) — a first-sign-in guided walkthrough of
     main functions AND a reusable base for announcing future updates to existing users. Needs a design
     spec (bring a proposal; don't ask open-ended). Fold "show signed-in account in UI" in here — it's
     cheap, onboarding-adjacent, and would have pre-empted the OAuth scare.
  5. **Calendar widget in the timeline** (validate scope first — it's a feature).
  6. **Light-mode color tuning.**
  7. **"Log out" vs "Sign out"** — verify actual wording, make consistent.
  8. **"Search your life" tagline** → replace. Planner-banked candidates: "Find anything, instantly." /
     "What are you looking for?" / "Recall anything." / "Your whole life, one search." (Zaid to pick.)
  9. **Bucket C — theme switch reloads the whole page** instead of applying in-session (likely a full
     app rebuild instead of a `ThemeMode` swap via Riverpod). Investigate; may be quick.
- **CAUTION — EDGE FUNCTIONS ARE NOT STAGING-ISOLATED.** There is ONE Supabase project shared by
  staging + stable, so `npx supabase functions deploy extract-tasks` goes LIVE FOR ALL TEST USERS the
  instant it runs — you canNOT trial it on staging only (same reason migrations can't be). The Lever-1
  fix is only-stricter (worst case it misses a real application, which beats inventing fake ones), so
  deploying it is a net-safe improvement — but TELL Zaid it's not staging-isolated before deploying.
- **STILL-OUTSTANDING QA correctness bugs (located earlier, NOT in Zaid's 9-item list — surface when
  relevant, don't drop):** derived progress read RAW at `home_screen.dart:207` & `timeline_provider.dart:93`;
  archived tasks inflate the progress denominator at `goal_provider.dart:167-187` (also skews delete-dialog
  count); timezone naive-local at `goal.dart:115` + `goal_breakdown_service.dart:82`; UTC/local mix at
  `goal_breakdown_service.dart:41`; dead `goalId` param on `TaskEditorSheet` (`:27,149`, belongs at
  `goal_breakdown_screen.dart:150`); goal delete is swipe-only (undiscoverable on desktop — add an explicit
  action in the goal edit sheet).
- **TELL IBRAHIM (still open):** his brief's `rsync ... :~/lifeos/<env>/` FAILS — `rrsync` chroots to
  `/home/ibrahim/lifeos`, so `~` is literal. Correct destination is just `<env>/`.
- **MINOR:** CI `actions/checkout@v4` + `ssh-agent@v0.9.0` still target Node 20 — one-line bump when the
  workflow is next touched.
- **DECISIONS:** due dates mandatory on tasks. Staging + stable deliberately share ONE Supabase project
  (do not re-litigate); therefore NEVER trial a migration OR an edge-function change on staging alone.
  Cascade = DELETE linked tasks on goal delete (implemented in Dart; migration 012's `ON DELETE CASCADE`
  is INERT because goals soft-delete). `daily-brief` deployed & working.

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
