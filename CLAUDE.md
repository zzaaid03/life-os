# Life OS — Project Context (for CC agents in Zed)

Life OS: a Flutter + Supabase AI life-management app. Killer feature = AI reads the user's Gmail,
extracts tasks, and tracks job applications. **Follow the global agent workflow in ~/.claude/CLAUDE.md**
(planner/worker roles, rounds, onboarding/offboarding, token discipline, novice guardrails).

## Stack & layout
Flutter 3.44 / Dart 3.12, Riverpod, GoRouter, Drift (local), Supabase (backend + AI Edge Functions
using Groq, model `llama-3.3-70b-versatile`). Feature-first architecture — mirror `lib/features/tasks/`
for new features. Supabase project ref: `ganbmkphtzdvxxnmprku`. CLI via `npx supabase`.
**CHANGED 2026-07-23 — the old "no Docker, unlinked CLI" note is OBSOLETE:** the CLI is now LINKED to
the shared production project (`supabase/.temp/linked-project.json`, gitignored) and Docker IS
installed. Two consequences: (1) `npx supabase db push` and `functions deploy` now hit PRODUCTION in
one command, no confirmation, no undo — treat both as destructive and NEVER delegate them to a worker;
(2) `npx supabase start` can run a LOCAL stack, so a migration can finally be rehearsed offline before
touching the shared project. There is still no `supabase/config.toml` — do NOT create one casually: a
later `supabase config push` could overwrite hosted auth settings, including the OAuth redirect
allow-list that mobile sign-in depends on. Runs on Chrome for dev (`flutter run -d chrome`);
**Android and iOS both now build and run on a real device (2026-07-23).**

## Current state (2026-07-27, late) — `staging` @ `f386c3e`, `main` @ `8d925c7` — SLICE 2a SHIPPED, SLICE 1 DIAGNOSED

**`staging` is 10 commits ahead of `main`, pushed, clean. Everything below is staging-only.**
**Two production changes were made this round and are LIVE for all 8 accounts: the `goal-breakdown`
edge function was deployed twice, and migrations 013 + 014 were applied.** No merge to `main`.

### ⚠️ ZAID'S STANDING WORKFLOW PREFERENCES — apply these from your first message
- **He wants workers running IN PARALLEL, always.** Give each a DISJOINT file set, say so explicitly
  in the prompt, and write any shared contract (model shape, repository signature) VERBATIM into
  every prompt that touches it. This round ran 4 parallel lanes, then 4 parallel fixes, then 2 more.
  It worked: zero clobbering across 10 worker runs. **If something genuinely cannot be split, say so
  and keep it serial** rather than forcing it.
- **Live/device testing happens AT THE END, not per slice.** Do not block a round waiting for him to
  test on a phone. Build, verify by reading diffs, commit, and batch the manual testing.
- He is direct about UX ("the nav bar looks like shit"). Treat that as precise signal, not venting.

### SLICE 1 (goal-breakdown personalization) — DIAGNOSED, FIX DEPLOYED, AWAITING RETEST
**Full detail is in `_planning/V2_SCOPE.md` under "SLICE 1 VERDICT". Read it. Summary:**
The plumbing was never broken. Instrumenting the function (echoing the assembled block + counts +
per-query errors) proved it with real data: `jobAppsCount: 36`, `blockLength: 973`, all
`queryErrors` null. **The MODEL was ignoring the context.** It was handed an open task reading
`Pay outstanding balance to McFIT` (a gym) next to a fitness goal and still answered "Research
local gyms near your location".

**Deployed fix (`dbb3ad8`, LIVE):** context block moved AFTER the goal, the soft "use it silently"
aside replaced with a numbered procedure stating generic advice is a failure, plus a required
`usedContext` field listing which facts the model actually let change a task.

**➡️ FIRST ACTION FOR THE SUCCESSOR: Zaid has the retest result. Ask for `context.usedContext`.**
- Non-empty (e.g. names the McFIT task) → prompt was the lever, slice 1 CLOSED as a win.
- Empty against a ~973-char block → **STOP tuning prompt wording.** The honest conclusion is the
  model can't be conditioned this way. Options are a stronger model, or assembling the breakdown in
  code the way `daily-brief` was rewritten. **Do not spend more than one further round on wording.**

**An early diagnostic run showed `jobAppsCount: 0` and looked like a broken query. It was Zaid's
OTHER account, which genuinely has no applications. He has two. Always confirm WHICH ACCOUNT a
diagnostic came from before believing it.**

### SLICE 2a (file storage) — BUILT, MIGRATIONS APPLIED TO PRODUCTION
Upload a file, re-encode images client-side, store it, mark it private. **There is deliberately NO
browse list and NO Files tab** — see the UX reversal below.
- **Schema is LIVE on the shared project:** `013_user_files.sql` (metadata table, 4 RLS policies,
  grants to `authenticated, service_role`, indexes, `updated_at` trigger) and
  `014_user_files_bucket.sql` (private `user-files` bucket, 10 MB server-side cap, 4 policies on
  `storage.objects` matching `(storage.foldername(name))[1] = auth.uid()::text`).
- **Verified before push** on a throwaway local stack (`supabase start` in a TEMP dir, NOT the repo,
  so no `config.toml` was added): 15 assertions across two users covering read isolation both ways,
  cross-user insert/delete, upload under another user's prefix, reading a known path, and the
  attachment check constraint. Both migrations re-apply cleanly.
- **Verified after push against production:** `user_files` returns `42501 permission denied` to
  `anon` (proves the table exists AND anon is locked out — a missing table returns `42P01`); the
  public storage endpoint refuses the bucket while an authenticated list returns `200 []` (proves
  the bucket exists AND is private). **Do not follow Postgres's hint to `GRANT ... TO anon`.**
- **Thumbnails are a ~2 KB base64 JPEG stored ON THE ROW** (`thumbnail_base64`), generated
  client-side at pick time. This is an EGRESS decision, not a style one: `Image.network` with
  `cacheWidth` downloads the FULL image and only shrinks the decode, so list thumbnails from signed
  URLs would have pulled tens of MB per load against 5 GB/month shared across all testers.
- Files are network-only (no Drift, no offline sync), same deliberate choice as goals.

### ⚠️ UX REVERSAL MID-ROUND — do not rebuild the old design
Zaid tested slice 2a and **rejected the browse list**: "the user adds the file and if he wants it he
has to use the search to see it". He also rejected the six-item nav bar (the centre-docked (+) FAB
covered two tabs). **Both were fixed in `f386c3e`:** the Files tab and `files_screen.dart` are gone,
the nav bar is byte-identical to its five-item form (verified: `git diff 190a05f` on that file is
empty), and uploading is now the third entry in the (+) chooser via `add_file_sheet.dart`.
**`_planning/V2_SCOPE.md` decision #3 has been rewritten to match.**

**CONSEQUENCE: there is currently NO way to see or delete an uploaded file.** The upload sheet says
so: "Once you add a file you can't remove it from the app yet. Only add something you're happy to
keep." Zaid accepted this knowingly. **Delete belongs on the file's search result in 2b.**

**GOTCHA the successor will hit:** `fileListProvider` (`files/domain/providers/file_provider.dart`)
now has NO consumer, so its notifier is never created and never loads a user id. **Anything calling
`fileListProvider.notifier.upload()` will throw `Cannot upload before a user is loaded`.** The
upload sheet correctly calls `fileRepositoryProvider.upload(...)` with `userId` from `authProvider`
instead. Either wire that provider up in 2b or delete it.

### NEXT: SLICE 2b — make files findable (REQUIRED, not optional)
AI labels each file once at upload (respecting the per-file private toggle), results wired into the
EXISTING `search_screen.dart`. **Add delete to the file's search result.** Search is now the only
path to an uploaded file, so until 2b ships, uploads are write-only.

### STILL UNVERIFIED, HIGHEST-STAKES ITEM
**No two REAL accounts have confirmed they cannot see each other's files.** RLS is proven by local
rehearsal and production probes, but not by two humans. **Before any friend stores a passport: Zaid
uploads one file, a friend uploads one file, each confirms they see only their own.** A rehearsal
does not substitute for this.

### Smaller open items (none urgent)
- Delete the pre-fix duplicate "Android Developer" job row from the Jobs tab (manual, cosmetic).
- Brand icon round 2 (in-app header lockup on the welcome screen) — still never started.
- `remove_alpha_ios: true` before any App Store submission.
- Roadmap item 5, Google OAuth verification — still the long pole to public launch, mostly Zaid's
  manual Cloud Console work.
- Zaid's iPhone build expires every ~7 days on free provisioning and needs an Ibrahim rebuild.

## SUPERSEDED — Current state (2026-07-27) — `staging` @ `6585483`, `main` @ `8d925c7` — V2 KICKOFF, SLICE 1 LIVE
**`staging` is 3 commits ahead of `main`, pushed, clean.** v1 is stable and feature-complete with no
open bugs; this session started **Life OS v2** as a design round first and a build round second.

**The full v2 scope, every locked decision, and every rejected idea live in `_planning/V2_SCOPE.md`
(gitignored, planner-only). READ IT before planning anything v2.** Summary of what's decided:
v2 = (1) the AI learns Zaid's habits/lifestyle, (2) file storage. Learning is **silent by default
plus a read-only "What Life knows about you" mirror in Settings** (so a wrong inference is
diagnosable, without any confirmation-card UI). Files: **AI may read them, with a per-file "private,
never send to AI" toggle**; **client-side image re-encode before upload**; 10 MB cap; network-only;
Files tab for browsing, **retrieval via the existing Search tab**; web+Android+iOS, camera deferred.

**SLICE 1 SHIPPED AND DEPLOYED: goal breakdown is now personalized (`6585483`).** The
`goal-breakdown` edge function's prompt only ever contained `Goal: <title>` + description, so the AI
knew literally nothing about the user and every breakdown came out generic. It now reads the caller's
own rows server-side (open tasks, tasks completed in last 30 days, job applications, other active
goals) and assembles a factual context block in TypeScript, same approach as `daily-brief`.
**Deployed to the shared project with Zaid's authorization (exit 0). No Dart changed, so no client
rebuild and the web bundle is untouched. Demo mode unaffected.**

**⚠️ SLICE 1'S RESULT IS INCONCLUSIVE AND THIS IS THE FIRST THING TO RESOLVE.** Zaid tested it:
output quality is **unchanged**. He attributes that to the AI not knowing enough about him yet, which
is plausible (slice 1 built the *channel*, not the *content*). **But because a failed context query
degrades silently to an omitted section, "not enough data about me" and "the queries are returning
nothing" are INDISTINGUISHABLE from the UI.** Zaid was asked for his open-task / job-application /
active-goal counts to tell these apart and **had not answered when the session ended.** Get those
numbers. If they're healthy and output still didn't change, the plumbing is broken. **Do not build
more personalization on top of slice 1 until this is resolved.**

**NEW CAPABILITY, USE IT: Deno 2.9.4 is now installed** (winget, `DenoLand.Deno`). Edge functions can
finally be verified before they reach production: `deno check supabase/functions/<name>/index.ts`
typechecks, and pure helper functions can be extracted to a temp file outside the repo and actually
executed. Both were done for slice 1 and the execution test proved a claim that had only ever been
asserted (all-empty input really does produce a byte-identical request). **Always typecheck an edge
function before asking Zaid to authorize a deploy, and check an untouched function as a control so a
clean result is meaningful rather than vacuous.**

**NEXT: slice 2 (file storage), split 2a (storage that works) then 2b (AI labelling + search).**
There is an OPEN AMBIGUITY on that split recorded in `_planning/V2_SCOPE.md` that must be resolved
with Zaid first. **Slice 2a needs a migration + a Storage bucket + RLS in TWO separate places (the
metadata table AND the bucket policies) — rehearse it on a local `npx supabase start` stack before
touching the shared project.** RLS is now load-bearing for real: ~8 real accounts (Zaid ×2 plus 5-7
friends, each added to the Google OAuth test-user list so each has their OWN account and user_id),
and slice 2 stores passports and rental contracts. Zaid confirmed per-user email isolation already
works correctly in production, which is the same machinery files will depend on.

**Zaid wants to run WORKERS IN PARALLEL from here.** Parallel workers MUST be given
non-overlapping file sets or they will clobber each other; the planner has to define the shared
interfaces (model shape, repository signatures) up front so independent workers can build against
them.

## SUPERSEDED — Current state (2026-07-25) — `main` AND `staging` @ `7b3a73e` — ONBOARDING GATE FIXED, JOB-DUPLICATE BUG FIXED
**Both branches pushed, clean, no divergence.** Merged to `main` and confirmed LIVE — `curl` against
`https://lifeos.deadthrone.dev` verified the served bundle is `flutter_bootstrap.js?v=7b3a73e`, not
just a green CI run. Zaid device-tested after deploy (web + iPhone) and confirmed everything works:
demo mode, sign-in, no onboarding loop. Ibrahim rebuilt the iPhone via free Xcode provisioning on
`main`@`7b3a73e` per `docs/IOS_BUILD.md` — confirmed working. **This round closes BOTH open findings
from the previous handoff (see SUPERSEDED block below) plus a new bug Zaid hit live.**

**1. New users skipping `/create-profile` — FIXED (`6fc2a39`).** Root cause was confirmed exactly as
suspected: `handle_new_user()` (migration 001, unchanged) auto-creates a `profiles` row synchronously
at signup, so the router's `profile == null` gate never fired. **Also code-confirmed the Google
sub-case was real** (not just suspected): the trigger's `COALESCE` only checks `display_name`, Google
populates `full_name`/`name`, so Google signups got a `profiles.display_name` = email-prefix — junk,
silently never corrected. **Fix:** new `lib/features/onboarding/domain/onboarding_provider.dart` —
`onboardingProvider`, a per-user-ID SharedPreferences flag (`onboarding_completed_$userId`) mirroring
the existing `announcements_provider.dart` pattern (same `loaded`-guard idiom, race-guarded on
`state.userId != userId` after each await). Router's create-profile gate
(`app_router.dart`) now reads `onboarding.loaded && !onboarding.completed`, **critically excludes demo
mode** (`!isDemo`, checked via `isDemoModeProvider` — demo users have no flag and must never be routed
to create-profile), instead of `profileState.profile == null`. `create_profile_screen.dart` calls
`markCompleted(userId)` right after a successful upsert. **Decision (Zaid, this round): show
`/create-profile` for EVERYONE (both email + Google), not just providers missing a name** — simplest,
lowest-risk, and the upsert overwrites Google's junk fallback name as a side effect. Known
accepted behavior: existing users see the name screen once per browser (pre-filled, harmless) —
consistent with the already-documented "onboarding prefs are LOCAL/per-device" decision.
2. **What's New carousel — CONFIRMED NOT A BUG, closed with no code.** Zaid retested on a fresh
   browser with a new account and the carousel appeared correctly. The per-browser (not per-account)
   SharedPreferences gate was exactly as diagnosed in the previous handoff — expected behavior.
3. **NEW bug, found and fixed same round: AI job-update emails created duplicate applications
   instead of updating status (`7b3a73e`).** Zaid hit this live: an email he'd already scanned/saved
   got rescanned as an "update" and the app added a NEW job row instead of updating the existing one's
   status. **Root cause, confirmed via Zaid's repro:** `_findExistingId` in
   `supabase_job_application_repository.dart` required an EXACT, case-sensitive match on BOTH
   `company` AND `role`. Company matched; **role did not** — the AI extracted the correct role from
   the original "applied" email but hallucinated a different role (`"Android Developer"`) on the
   "viewed"/update email, so the match silently failed and the update surfaced as a new Add/Dismiss
   card instead of auto-applying. **Fix:** match on `company` only, case-insensitively (`.ilike`); if
   multiple applications share a company, disambiguate by role, else surface as a new card rather than
   guess-merging. **Bug-class fix, not just the one instance:** found a SECOND copy of the identical
   exact-match logic in `upsertFromScan` (the Add-button path) — its doc-comment even claimed to use
   "the same identity rules as `_findExistingId`", which the first fix would have silently made false.
   Refactored `upsertFromScan` to delegate to `_findExistingId` so the two paths can no longer diverge.
   **Manual step still open:** the duplicate "Android Developer" row created before this fix is still
   in Zaid's real job-tracker data — needs manual deletion from the Jobs tab (not done this session,
   not blocking).
4. **Task-completion animation** (`a48e5b5`, from the PREVIOUS round) — already verified/committed,
   carried forward as historical context only, no action.

**No migrations, no edge-function deploys this round** — both fixes are pure client-side Dart
(`app_router.dart`, `create_profile_screen.dart`, new `onboarding_provider.dart`,
`supabase_job_application_repository.dart`). Merge to `main` was a straight fast-forward
(`358e18d..7b3a73e`), no merge commit, sole author Zaid Jarrar, no AI attribution.

### NEXT
- **Delete the pre-fix duplicate job-application row** ("Android Developer") from the Jobs tab —
  cosmetic cleanup, not urgent.
- **Round 2 of the brand icon** (in-app header lockup: icon + "LifeOS" wordmark on the welcome
  screen) — flagged as not-yet-started in the previous round, still not started.
- **`remove_alpha_ios: true`** for `flutter_launcher_icons` — still not added, only matters before a
  real App Store submission (harmless for sideloading, which is all that's happening now).
- No other open findings. Next round starts from a clean slate.

## SUPERSEDED — Current state (2026-07-24) — `main` AND `staging` @ `a48e5b5` — SIGN-UP FUNNEL HARDENED, BRAND ICON SHIPPED
**Both branches pushed, clean, no divergence.** This round: verified/fixed the real-account sign-up
funnel end to end (it was silently broken), shipped the LifeOS brand app icon to all three platforms,
and slowed the task-completion animation. **Two findings are now OPEN — see "NEXT" below.**

**Sign-up funnel — was broken, now fixed, 5 commits:**
1. Real email/password sign-up on production hit `over_email_send_rate_limit` — Supabase's default
   built-in email sender (test-only, very low quota) was exhausted the moment the LinkedIn post (which
   only promotes the no-signup **demo**, not real sign-up) started driving traffic to the site generally.
   **Fixed:** custom SMTP via Resend, connected directly in Supabase's dashboard using **Ibrahim's own
   Resend account** (he also owns DNS for `deadthrone.dev` via Cloudflare) — verified independently via
   `nslookup`: DKIM is live and correct at `resend._domainkey.lifeos.deadthrone.dev`; DMARC is present
   at the organizational root `_dmarc.deadthrone.dev` (correctly covers the subdomain via DMARC
   inheritance — do not ask Ibrahim to duplicate it). **Do not re-verify DNS; it's confirmed live.**
2. With the rate limit gone, a second real bug surfaced: **`signUpWithEmailAndPassword` treated
   `user != null` as fully authenticated even when Supabase's "Confirm email" setting meant
   `response.session` was `null`** (pending confirmation). The router then routed straight into the app
   with no real JWT, and `create_profile_screen.dart`'s write hit `42501 permission denied` under the
   `anon` role. **Fixed** (`a4e343a`): new `AuthStatus.emailConfirmationPending`, checked via
   `response.session`; new `CheckEmailScreen` (`/check-email`) shown instead of a broken authenticated
   state. **Do NOT grant `anon` write access to `profiles`** — that was Postgres's own error-message
   hint and would open the table to unauthenticated writes from anyone; it was correctly never applied.
3. Confirmation links themselves were dead (`http://localhost/?error=...&error_code=otp_expired`) —
   Supabase's **Site URL** (Authentication → URL Configuration) was still the default `localhost`
   placeholder, separate from the OAuth Redirect URLs allow-list. **Fixed by Zaid in the dashboard** —
   confirm it's now `https://lifeos.deadthrone.dev` if this ever regresses.
4. **"Confirm email" is currently back ON** (Zaid re-enabled it to test the fix above) — production
   sign-up now requires real email confirmation, which correctly works end-to-end today.

**Brand app icon shipped (`33cd7ba`):** design pulled from a claude.ai/design project (a "power +
pulse" mark — the universal power-glyph ring with a heartbeat/EKG line replacing the usual vertical
break) via the `DesignSync` MCP tool. Exact CSS geometry was hand-translated to a precise SVG
(`assets/branding/logo_mark.svg`, colors `#294793` bg / `#F7F8FC` mark — converted from the design's
`oklch()` values and independently cross-checked). `flutter_launcher_icons` (new dev dependency) now
generates all Android/iOS/web icon sizes from `assets/branding/logo_mark_1024.png`. Default Flutter
template icon is fully replaced on all platforms. **Known follow-up, not yet done:** add
`remove_alpha_ios: true` to the `flutter_launcher_icons` config before any real App Store submission
(current iOS icons include an alpha channel, which the Store rejects — harmless for sideloading).
**Round 2 (in-app header lockup: icon + "LifeOS" wordmark on the welcome screen) was never started** —
do this once the app-icon look is confirmed fine, and note there's no separate marketing site: the
Flutter web app itself IS `lifeos.deadthrone.dev`, so "website header" = the welcome screen.

**Task-completion animation slowed (`a48e5b5`):** checkbox fill 200ms→350ms, checkmark swap
150ms→250ms (`task_checkbox.dart`); task title now animates its strikethrough/color change via
`AnimatedDefaultTextStyle` instead of snapping instantly (`task_card.dart`) — was jarring next to a
slower checkbox. Cosmetic-only, no logic touched.

**Fresh Android release APK built** (`build/app/outputs/flutter-apk/app-release.apk`, from `a48e5b5` —
rebuild before handing to Zaid if new commits land first) — **still signed with the debug keystore**,
fine for sideloading only. **An Ibrahim prompt was issued** (rebuild + reinstall on Zaid's iPhone via
his Mac's free Xcode provisioning, same flow as `docs/IOS_BUILD.md`) — check with Zaid whether Ibrahim
has run it yet.

### NEXT — two open findings from testing with "Confirm email" back ON, NEITHER fixed yet
Zaid asked to offboard with these handed to the successor. **A previous worker's report (the
task-completion-animation one above) will also be pasted to the successor by Zaid** — it's already
verified and committed here, so treat that report as historical context, not a pending action.

1. **New users skip `/create-profile` ("What should Life call you?") entirely — confirmed root cause,
   NOT yet fixed.** `handle_new_user()` (migration 001, `SECURITY DEFINER` trigger) auto-creates a
   `profiles` row **synchronously at `signUp()` time**, independent of email confirmation, using
   `COALESCE(raw_user_meta_data->>'display_name', email-prefix)`. By the time the router checks
   `profileState.profile == null` (`app_router.dart`) after the confirmation-link cold start, the
   profile already exists, so the check never fires and `/create-profile` is skipped straight to
   `/home`. **This likely also affects Google sign-in** — the trigger's `COALESCE` only checks the
   `display_name` metadata key, but Google populates `full_name`/`name` instead, so Google sign-ups
   probably get an auto-created profile with an **email-prefix fallback name**, silently wrong, never
   corrected because the same skip applies. **Not yet confirmed against a real Google test — verify
   before assuming.** Recommended fix direction (discussed with Zaid, not yet decided/built): a local
   SharedPreferences "onboarding completed" flag **keyed by user ID** (same low-risk, no-migration
   pattern already used for What's New below), checked by the router instead of `profile == null`.
   A schema-flag alternative (new `profiles` column) was also considered but would need a migration on
   the shared Supabase project — tell Zaid before deploying if that direction is chosen instead.
2. **What's New carousel didn't appear — likely NOT a bug, unconfirmed.** Its gate
   (`home_screen.dart` + `announcements_provider.dart`) has **zero dependency** on `/create-profile` —
   it fires independently off a SharedPreferences flag (`announcements_acked_version`) the first time
   `HomeScreen` builds. That flag is **per-browser, not per-account** (an already-accepted, documented
   limitation — see "Onboarding/theme prefs are LOCAL" in the Decisions note below). If Zaid tested the
   new account in the same browser he'd used earlier in the session (when he successfully reached
   `/home` with confirmation OFF), the carousel would correctly stay hidden for the "new" account too —
   this is expected behavior given the current design, not a defect. **Ask Zaid to confirm before
   building anything**; if confirmed, the same per-user-ID-keyed SharedPreferences fix as finding #1
   would resolve this too, in one pass.

## SUPERSEDED — Current state (2026-07-23, late) — `main` AND `staging` @ `2d004f7` — DEMO MODE LIVE IN PRODUCTION
**Both branches are at `2d004f7`, pushed, clean, no divergence.** Production
(https://lifeos.deadthrone.dev) and staging both verified serving `flutter_bootstrap.js?v=2d004f7`.
This merge also finally shipped the whole MOBILE round to production (it had been staging-only).

**DEMO / SANDBOX MODE IS SHIPPED.** Strangers can now explore the app with NO sign-up and NO Gmail
access — critical because Google OAuth is still in Testing mode, so no stranger can sign in at all.
Tap **"Try it — no sign-up"** on the welcome screen → the app enters an ephemeral sandbox.

**How it works (do not re-derive):** `lib/features/demo/demo_mode.dart` holds `demoModeController`
(a `ValueNotifier<bool>`), `enterDemoMode()`/`exitDemoMode()`, `isDemoModeProvider`, and
`buildDemoOverrides()`. `AppBootstrap` in `main.dart` wraps the app in a `ValueListenableBuilder` that
rebuilds `ProviderScope` with a **`ValueKey` keyed to the demo flag** — so entering gives a brand-new
container with fresh seeded state and exiting/reloading wipes it. **Ephemeral is free; there is no
storage and no reset button by design.** 9 providers are overridden: `authRepositoryProviderOverride`,
`profileRepositoryProvider`, task/job/goal repos, `dailyBriefProvider`, `inboxScanServiceProvider`,
`processedEmailsRepositoryProvider`, `goalBreakdownServiceProvider`, `isDemoModeProvider`.
- **The fake auth `userId` MUST equal `demoUserId` (`'demo-user'`) from `demo_seed.dart`** — the demo
  repos filter `getAll(userId)`, so a mismatch silently yields empty lists.
- Seed persona = **"Alex," a PM job-seeker mid-hunt**: 4 jobs (Meridian Financial *interview*, Nimbus
  Labs *applied*, Vertex Design *viewed*, Orbital Systems *rejected*), 9 tasks (overdue/today/upcoming/
  completed), 2 goals with linked tasks. **All dates are relative to `DateTime.now()`** so it never rots.
- **The AI is scripted, not live.** `DemoInboxScanService` waits 2s then returns a canned `ScanResult`
  (2 tasks + a NEW Cascade Robotics application, deliberately absent from the seed so it surfaces as an
  Add/Dismiss review card). `DemoGoalBreakdownService` returns 4 goal-agnostic tasks. `DemoDailyBriefNotifier`
  returns a canned brief. **Zero network in demo — verified**: all three base services are concrete classes
  whose ENTIRE network surface is the one method each demo subclass overrides (no `super.` calls).

**Two production-behaviour changes shipped with this merge (expected, not bugs):** (1) existing WEB
task rows may render **one day off on first load** then stay consistent — the Task store-UTC/display-local
fix reached web for the first time; (2) the Daily Brief on web is now fresher and timezone-correct.

## Session handoff (2026-07-23, late — DEMO MODE ROUND) — SHIPPED TO PRODUCTION
**5 rounds, all planner-verified before commit:** `11fd9f9` extract `JobApplicationRepository` interface
(jobs was the only repo without one) → `5a30ec8` in-memory demo data layer + seed → `e00b76b` enter/exit
demo with fake auth + seeded repos → `3a78838` scripted inbox scan + goal breakdown → `2d004f7` demo
banner + "Try it" as primary welcome CTA. Zaid device-tested rounds 3 and 4 at 100%.

**One production-code deviation worth knowing:** `taskRepositoryProvider` was declared
`Provider<TaskRepositoryImpl>` (concrete) and had to be widened to `Provider<TaskRepository>` (the
interface) so it could be overridden. Verified behaviour-neutral — nothing outside its own files ever
referenced the concrete type.

**⚠️ OPEN / NEXT — the sign-up funnel is UNVERIFIED and this is now the top risk.** The demo is live and
Zaid intends to promote it on LinkedIn. **Google sign-in will NOT work for strangers** (OAuth Testing
mode, only jarrarzaid3@ / zaidgpt3@). Email/password auth IS implemented and reachable, but **nobody has
verified a brand-new email/password account works end-to-end against production** (profile creation, RLS,
first load). **VERIFY THIS BEFORE ANY PUBLIC POST.** If it fails, the demo is the entire experience and the
post's CTA must not imply people can sign up.

**PENDING (not started): Roadmap item 5 — Google OAuth verification.** This is the long pole to public
launch (the `gmail.readonly` sensitive scope makes Google's review slow) and is mostly Zaid's manual work
in the Cloud Console. A planner should prep the submission checklist (scope justification, app homepage,
privacy-policy URL, domain verification, demo video — **the new demo mode makes recording that video
trivial**) since missing requirements silently stall reviews.

**A LinkedIn launch post was drafted for Zaid this session** (drives to the demo, no sign-up promised).
If he asks again, it lives in the session transcript — rewrite fresh rather than guessing at it.

**CI DEPLOY-RACE FIX (`a1614a3`) IS NOW VERIFIED — 2026-07-23. Do not re-test or re-investigate.** A
docs-only commit was deliberately pushed to `main` and `staging` back-to-back (a zero-risk payload). Runs
`30042237169` (main) and `30042239659` (staging) behaved EXACTLY as designed: main went `in_progress`
while staging sat `pending`, i.e. **queued behind it instead of racing**, and BOTH completed `success`.
The `rrsync` "Another instance is running" / exit-12 failure mode is closed. Queuing (~2.5 min for the
second run) is CORRECT behaviour, not a hang.

## SUPERSEDED — Current state (earlier 2026-07-23) — MOBILE WORKS, ALL BUGS CLOSED
**`staging` @ `7cfa7b9`. `main` still @ `4ea20c5`** — the whole mobile round is staging-only and has
NOT been merged to stable. (An earlier handoff said `main` was @ `9aefe8c`; that was wrong — verified
`4ea20c5` on 2026-07-23.) **Zaid device-tested Android + iPhone after this round and reports the app
"works 100%".** Web production is untouched and healthy. Default: work on `staging`, merge
to `main` only when Zaid says so.

**ROADMAP ITEM 4 (MOBILE) IS ESSENTIALLY DONE — the app now runs on Zaid's real Android phone AND his
real iPhone, and he confirmed it works "perfect" apart from the bugs listed below.** This round did:
- A **Drift-vs-model audit** (Opus agent). Result: **zero field-level gaps for Task** — all 17 fields
  agree across domain model / Drift table / both mappers / Supabase, `goalId` included. The feared
  "web-only column silently vanishes on native" bug class DID NOT EXIST. Do not re-run this audit.
- `db07719` — **Android `INTERNET` permission was declared ONLY in the debug manifest**, so release
  builds had no network at all. Added to the main manifest. Plus the OAuth deep-link intent-filter
  (`com.lifeos.app://login-callback`), the matching iOS `CFBundleURLTypes`, and a native `redirectTo`
  in `supabase_auth_repository.dart` (web branch deliberately unchanged). Plus `task.dart`: store-UTC/
  display-local for all DateTimes (Task was still naive-local long after Goal was fixed), `inProgress`
  now encodes as `in_progress` so it round-trips instead of silently reverting to `pending`, and a
  bounds check on the `TaskPriority.values[...]` lookup.
- `c4a9ce3` — app display name is now **"Life OS"** on both platforms (was the raw slug `life_os`).
- `a1614a3` — **CI deploy race fixed** (see below).
- `4d010d7` — `docs/IOS_BUILD.md`, a self-contained iOS free-provisioning runbook.

**Android build facts:** first APK built 2026-07-23 via `flutter build apk --release`, ~60 MB, at
`build/app/outputs/flutter-apk/app-release.apk`. Toolchain setup needed on Zaid's machine was:
Android SDK cmdline-tools + licences + **SDK platform 36 and build-tools 36.0.0** (Flutter 3.44 needs
36; he had only 34/35). The `[!] Visual Studio` line in `flutter doctor` is Windows-desktop-only and
is IRRELEVANT — do not send anyone chasing it. **Release APKs are signed with the DEBUG keystore**
(Flutter's default template, `android/app/build.gradle.kts:29-33`) — fine for sideloading, but Play
Store will reject it and a properly-signed build later will NOT install over it (uninstall first).

**iOS build facts:** running via **Xcode free provisioning** on a borrowed Mac (Zaid's cousin's — he
has NO paid Apple Developer account). **TestFlight is therefore NOT available: it requires the $99/yr
membership. Do not propose TestFlight as a free option.** Free provisioning means the app dies after
**7 days** unless re-installed from the Mac. Full runbook: `docs/IOS_BUILD.md`.

**Supabase dashboard change made this round:** `com.lifeos.app://login-callback` added to
Authentication → URL Configuration → **Redirect URLs**. Verified working — sign-in succeeds on device.

WORKING: AI inbox scan (Gmail read SERVER-SIDE via a stored refresh token → Groq → tasks +
job-application updates), job tracker with manual add/edit/delete, tasks, unified timeline, AI Daily
Brief card, dark mode + theme toggle, 5-status job vocab (applied/viewed/interview/rejected/accepted),
AI Goal Breakdown (goal → Groq → reviewable tasks → saved linked via `tasks.goal_id`, derived progress).
Journal removed. Notes+Habits removed (79e38a1).
BACKEND: Edge Functions deployed: `extract-tasks`, `daily-brief`, `goal-breakdown`. Secrets set:
GROQ_API_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET. Migrations 001–012 applied. Per-user Gmail =
stored refresh token (`google_credentials`) minted server-side. Google OAuth app is still in TESTING
mode (test users only: jarrarzaid3@, zaidgpt3@) — hosted ≠ publicly usable.

## Session handoff (2026-07-23, late — BUGFIX ROUND) — ALL 3 BUGS CLOSED, NOTHING OPEN
**WORKFLOW DIRECTIVE (unchanged):** all work stays on `staging`; do NOT merge to `main` until Zaid
says so. Actions, not questions. **The next round starts from a clean slate — there are no open bugs.**

**GIT STATE:** `staging` @ `7cfa7b9` (pushed, clean). `main` @ `4ea20c5` (untouched). Two commits this
round: `8aa616d` (OAuth tab) and `7cfa7b9` (Daily Brief). Sole author Zaid Jarrar, no agent attribution.

1. ✅ **OAuth browser tab now auto-dismisses** (`8aa616d`). New `oauthTabDismissProvider`
   (`lib/features/auth/domain/providers/`) mirrors `googleCredentialsCaptureProvider`: subscribes to
   `onAuthStateChange` and calls `closeInAppWebView()` on `signedIn`, **native only** (`!kIsWeb`).
   Activated by a `ref.read` in `LifeOSApp.initState`. `url_launcher` promoted to a direct dependency
   (it was already transitive via `supabase_flutter`). The Custom Tab launch mode was deliberately LEFT
   as the platform default — do NOT switch it to `LaunchMode.externalApplication`, that is worse UX.
   Web sign-in untouched. **Zaid device-tested on Android + iPhone: works.**
2. ✅ **Daily Brief rewritten and fixed** (`7cfa7b9`). Three separate defects, all closed:
   - **It was never hallucinating.** HUGO BOSS / amber / Keysight / "Ibrahim Jarrar" were REAL rows in
     `job_applications` — junk created by the AI extractor before the 2026-07-22 tightening. That fix
     stopped new junk but never cleaned existing rows; Zaid deleted them manually from the Jobs tab.
     **Lesson: the brief reads THREE tables (tasks, completed tasks, job_applications). Checking only
     the task list and concluding "hallucination" was wrong.**
   - **Staleness:** `DailyBriefNotifier.loadIfNeeded()` only fired from `home_screen.dart` `initState`,
     which never re-runs (Home is kept alive by the nav shell) — so the brief was fetched exactly once
     per app launch. It now watches `taskListProvider`, compares a sorted `id:status:dueDate`
     signature, and re-fetches behind a **2s debounce** with in-flight serialisation.
   - **Grounding:** the edge function **no longer calls Groq at all.** Every sentence is assembled in
     TypeScript from the caller's own rows (overdue / due today / due soon / highest-priority open task
     / completed-this-week). Standout jobs are cross-referenced against task titles by company name and
     reported by what actually exists: an open next step, a finished one, or "no task is tracking it".
     **It never says a job is "upcoming" — `job_applications` stores NO interview date** (only
     `applied_at`/`updated_at`), so any such claim was unfounded. When nothing is due it says so plainly.
   - **Timezone:** `due_date` is `TIMESTAMPTZ` and the app stores **local midnight converted to UTC**,
     so UTC day boundaries misclassified tasks by a full day (tomorrow → "due today"). The client now
     sends `tzOffsetMinutes`; the function clamps it to ±840, defaults to 0 on a missing/bad body, and
     derives local-midnight boundaries from it. This was caught in planner review, NOT by the worker.
   - **DEPLOYED** to the shared project 2026-07-23 with Zaid's authorization. **Zaid device-tested: works.**
   - **Known limitation, accepted:** company↔task matching is a case-insensitive substring test, so a
     short company name could match an unrelated task title. Not worth fuzzy-matching for one user.
3. ✅ **Native `providerRefreshToken` capture — CLOSED, was never a gap.**
   `googleCredentialsCaptureProvider` (`lib/features/inbox/data/google_credentials_repository.dart`)
   already listens to the raw `onAuthStateChange` stream and upserts the token whenever it sees a new
   one; `main.dart` activates it at startup. The `main.dart` startup block is the WEB path. **Do not
   re-investigate this.**

## Session handoff (2026-07-23 — MOBILE KICKOFF ROUND) — SUPERSEDED, all 3 bugs now fixed (see above)
**WORKFLOW DIRECTIVE:** all work stays on `staging`; do NOT merge to `main` until Zaid says so.
Actions, not questions. **NEXT ROUND = fix these three bugs.** They are the ONLY open items.

1. **OAuth browser tab does not auto-dismiss (mobile, both platforms).** Sign-in itself WORKS — the
   deep link returns, the session is created, the AI inbox scan works 100%. The defect is purely that
   the Google sign-in browser/Custom Tab stays open on top of the app after consent; **the user has to
   manually tap the X to reveal the app underneath.** Diagnosed area, NOT yet fixed:
   `supabase_auth_repository.dart` `signInWithGoogle` — look at `authScreenLaunchMode` on
   `signInWithOAuth` (Custom Tab / in-app webview vs `LaunchMode.externalApplication`) and/or calling
   `closeInAppWebView()` when the auth-state-change fires. **The redirect allow-list is CORRECT and is
   NOT the cause — do not go re-investigate it.** Web must be left byte-identical; it works today.
2. **Daily Brief is wrong and feels worthless (Zaid's words: "doesn't add anything").** Three distinct
   sub-problems, confirmed on device: (a) **it lists tasks that are already completed** — e.g. an
   interview he had already attended and marked done still appears; almost certainly the
   `daily-brief` edge function's task query does not filter out completed/archived status; (b) **it is
   stale** — takes a long time to reflect a newly-added task, so caching/refresh needs looking at;
   (c) **product value** — even when correct it says nothing useful. (a) is a straight bug; (c) needs a
   product conversation with Zaid BEFORE any prompt rewrite. ⚠️ `daily-brief` is an EDGE FUNCTION on
   the SHARED project — deploying goes live for every user instantly, there is no staging copy. One
   careful shot, not an iterate-in-prod loop. TELL ZAID BEFORE DEPLOYING.
3. **(LOW PRIORITY, UNCONFIRMED) Native `providerRefreshToken` capture.** `main.dart:48-67` captures
   the Google refresh token ONLY at startup right after `Supabase.initialize()` — correct for web,
   where the OAuth redirect is consumed during init. On native the callback arrives by deep link while
   the app is ALREADY RUNNING, so that block should never fire. **Zaid tested and reports the AI inbox
   works 100% on mobile, so this is NOT user-visible today** — the most likely explanation is that his
   token was already stored from a previous WEB sign-in on the same account. The gap, if real, would
   only bite an account that has NEVER signed in on web. **Do not spend a round on this. Verify cheaply
   with a fresh account someday**; if it reproduces, the fix is to also capture the token in the
   auth-state-change listener, not only at startup.

**CI DEPLOY RACE — FIXED `a1614a3`.** `deploy.yml`'s `concurrency.group` was keyed on `github.ref`, so
`main` and `staging` runs never queued against each other. The server allows ONE `rrsync` instance per
account, so pushing both branches together (which is exactly what a merge-to-stable does) raced and one
run died with `Another instance of rrsync is running` / exit 12 — this happened TWICE (2026-07-22
16:58, 2026-07-23 10:53). Group is now the constant `deploy-vps`; `cancel-in-progress` stays `false`
(cancelling a `--delete` rsync mid-flight is how you get a half-deleted live bundle). **There was never
a stale lock and nothing needed cleaning on the server — do not ask Ibrahim to kill processes.** Note
our deploy key is `rrsync`-restricted and CANNOT open a shell, so "SSH in and check" is impossible for
us by design. Still unverified against a real two-branch push — the next merge-to-stable is the test;
the second run should QUEUE (~2.5 min), which is correct behaviour, not a hang.

**LOW PRIORITY / KNOWN:** the VPS IP is hardcoded in plaintext at `.github/workflows/deploy.yml:105`
and the repo is PUBLIC, which contradicts the "no infra IPs in commit-visible files" rule. Moving it to
a GitHub secret is easy but only partial — it is already in git history. Real protection remains the
rrsync-restricted key. Zaid was told; filed as low priority, not actioned.

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
- **GIT STATE:** `staging` pushed & clean (6 commits ahead of the evening handoff's `41ffd71`, tip is
  this doc update). `main` still @ `f620639` (untouched). Everything below is **staging only** — but see
  NEXT: Zaid has now authorized starting the merge-to-stable track.
- **QA-CORRECTNESS ROUND — the previously-"still-outstanding" bugs are now ALL FIXED (commits
  `294a7ee`..`958dee4`) and ALL Zaid-tested 100% (incl. #1 dashboard + #6 calendar, confirmed
  2026-07-22 late). THE QA / CLEAN-CODE PHASE IS CLOSED:**
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
     (was dead-last under a "Life" heading), renamed the header "Life"→"Goals". `c54056c`. *(Zaid: confirmed good.)*
  7. ✅ **Timeline = calendar-only + task titles in cells** — removed the old chronological event list
     and its now-dead helpers (`_groupByDay`/`_DayHeader`/`_TimelineTile`); redesigned the
     `table_calendar` in `calendar/presentation/widgets/calendar_view.dart`: taller cells
     (`rowHeight:82`), each day cell shows task TITLES as text (up to 2 + "+N") instead of dots,
     days-with-tasks tinted (`primary@12%`, selected @25%+border, today border) via `calendarBuilders`;
     `eventLoader`/marker knobs removed; the tap-a-day task list below is retained. `958dee4`. *(Zaid: confirmed good.)*
- **NEXT (LOCKED — chosen by Zaid 2026-07-22 late): OPTION (a) — MERGE `staging` → `main` / DEPLOY
  STABLE. ✅ DONE 2026-07-22.** The cache fix landed on `staging` (`7799332`), Zaid authorized the merge,
  `main` fast-forwarded `f620639..7799332` (24 commits, sole author Zaid Jarrar, no agent attribution),
  CI run `29940066260` deployed stable green, and the live bundle at `https://lifeos.deadthrone.dev` was
  verified serving `flutter_bootstrap.js?v=7799332` → `main.dart.js?v=7799332` behind a no-store shell.
  **Option (b) — the MOBILE track — is now the next roadmap item.**
- All other cautions from the evening handoff below still apply (edge-fns NOT staging-isolated;
  Node-20 CI bump). ✅ SW-cache to-do: RESOLVED (see the RESOLVED block below). ✅ TELL IBRAHIM the
  rsync `~` bug: DONE — Ibrahim acknowledged and corrected his brief 2026-07-22.

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
- **PRODUCTION SERVICE-WORKER CACHE — ✅ RESOLVED 2026-07-22 (`7799332`). Two facts here were WRONG in
  the original write-up; do not relearn them:**
  1. **It was never the service worker.** On Flutter 3.44.7 the emitted `flutter_service_worker.js` is an
     ~815-byte SELF-UNREGISTERING STUB (`install→skipWaiting`, `activate→registration.unregister()`) —
     no `RESOURCES` map, no `fetch` handler, no Cache Storage. It caches NOTHING. The staleness was
     ordinary HTTP caching of the root-level entry files.
  2. **Therefore `--pwa-strategy=none` was the WRONG fix** (it was the leading candidate). It suppresses
     the stub — and the stub is the only thing that evicts the REAL caching SW that older Flutter builds
     installed on existing browsers. Removing it would strand those clients permanently. **Keep the stub
     generated. Never add `--pwa-strategy=none`.**
  3. **Caddy was already configured correctly** — Ibrahim serves `index.html`, `flutter_service_worker.js`,
     and `version.json` with `Cache-Control: no-cache, no-store, must-revalidate`, and `/assets/*` with
     immutable 1-year caching. (An agent inferred "no Cache-Control" from Caddy DEFAULTS instead of
     checking the live config — verify with `curl -sI` before blaming server config.)
  4. **The actual gap + the fix:** `main.dart.js` and `flutter_bootstrap.js` live at the bundle ROOT, so
     they match neither Caddy rule and fell through to heuristic caching. `scripts/build-web.sh` (+ the
     `.ps1` twin) now post-build stamps them with the git short SHA: `index.html` → `flutter_bootstrap.js?v=$STAMP`,
     and inside that file → `main.dart.js?v=$STAMP`. Plus `<meta http-equiv="Cache-Control" content="no-cache">`
     in `web/index.html`. Chain: no-store shell → new bootstrap URL → new main.dart.js URL. No link can go stale.
  5. **If you change the build flags, keep `scripts/build-web.sh` and `scripts/build-web.ps1` in sync** —
     CI uses the `.sh`; the `.ps1` is the local-Windows twin and is NOT exercised by CI.
- **`/assets/*` is served immutable for 1 YEAR — and `.env` ships under `/assets/`.** If `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, or `GOOGLE_CLIENT_ID` is ever rotated, returning visitors can hold a stale
  `.env` for up to a year. Rotating a key therefore REQUIRES a coordinated cache-busting plan (ask Ibrahim
  to purge or rename), not just a redeploy.
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
   handoff section for commit-by-commit detail. **QA/clean-code phase CLOSED — Zaid signed off on #1/#6.**
3b. **Cache-bust + MERGE TO STABLE ✅ DONE 2026-07-22 — `main` @ `7799332`.** Entry-asset version
   stamping shipped (`scripts/build-web.sh` + `.ps1`, `web/index.html`), then `staging`→`main`
   fast-forwarded and CI deployed stable green; live bundle verified by `curl`. **Stable is no longer
   the 2026-07-21 snapshot — everything from the QA + polish rounds is now in production.** This merge
   was a pure bundle swap: NO migrations and NO edge-function deploys were part of it.
4. **Mobile app version** (Android/iOS) ✅ **SHIPPED TO DEVICE 2026-07-23 on `staging` @ `4d010d7`**
   (NOT merged to `main`). Runs on Zaid's real Android phone and real iPhone. See the 2026-07-23
   handoff for build facts, the iOS free-provisioning constraints, and the 3 open bugs.
   **✅ ALL 3 BUGS CLOSED 2026-07-23 late on `staging` @ `7cfa7b9`, device-tested by Zaid ("works
   100%"). Roadmap item 4 is COMPLETE. Nothing is open.** See the BUGFIX ROUND handoff above.
   Deliberately OUT of scope for v1 mobile (Zaid's decision 2026-07-23): **goals stay network-only** —
   there is no Drift `Goals` table and no goal sync, so with no signal the goals list is empty and
   creating a goal fails, while tasks keep working offline. Same for tags/attachments/jobs/profile.
   Do not "fix" this without asking; it is a choice, not an oversight.
5. **Public launch**: Google OAuth verification (needed to leave Testing mode). Note the `gmail.readonly`
   sensitive scope makes this a real timeline risk — Google review is slow. Until then only
   jarrarzaid3@ / zaidgpt3@ can sign in, on ANY host.

## Hard-won gotchas (do NOT relearn these)
- **An empty prompt was the old bug; an IGNORED prompt is the new one. Check which you have before
  tuning wording.** Slice 1 fed `goal-breakdown` 973 characters of real context and output did not
  change at all. The instinct is to blame the data or the queries. The instrumented response proved
  every query worked, and that the model was handed `Pay outstanding balance to McFIT` next to a
  fitness goal and still said "research local gyms". **Instrument before theorising, and make the
  model declare what it used** (the `usedContext` field) so "ignored the context" is visible from
  outside instead of being indistinguishable from "had no context".
- **`cacheWidth`/`cacheHeight` on `Image.network` do NOT reduce what is downloaded.** They only
  shrink the decode after the full bytes have arrived. A list of 20 phone photos rendered as 44px
  squares still pulls tens of MB. This shipped in a worker's code with a doc comment calling the
  widget "egress-conscious", which is how a false claim survives review. **For list thumbnails,
  store a tiny preview alongside the metadata; do not fetch the real file.**
- **A `db push` against a project whose migration history is EMPTY will try to re-run everything.**
  The shared project had zero rows in its migration history (migrations 001-012 were applied by
  other means), so `db push --dry-run` showed it would re-apply all 14 files. Migrations 001, 002,
  006 and 007 contain 51 unguarded `CREATE POLICY` statements between them, so it would have failed
  on the first one. **Always run `supabase migration list --linked` and `db push --dry-run` BEFORE a
  real push.** Fixed 2026-07-27 with `supabase migration repair --status applied` for 001-012, which
  writes only to the history table and changes no schema. History is now correct; future pushes are
  one clean command.
- **Rehearse migrations in a TEMP directory, not the repo.** `supabase start` needs a
  `config.toml`, which this repo deliberately does not have (a later `config push` could overwrite
  hosted auth settings including the OAuth redirect allow-list). Run `supabase init` in
  `$env:TEMP\<name>`, copy `supabase/migrations/*.sql` in, and start there. Full isolation, nothing
  added to the repo.
- **`SET LOCAL role` outside a transaction is SILENTLY IGNORED**, so an RLS test harness runs as
  superuser, bypasses RLS, sees every row, and reports a policy failure that does not exist. Wrap
  every RLS assertion in `BEGIN; ... COMMIT;`. **This failure looks exactly like a broken policy** —
  it cost a wrong conclusion before being caught.
- **Verify a deployed table/bucket from OUTSIDE, and pick probes whose failure modes differ.** A
  missing table returns `42P01 relation does not exist`; an existing but protected one returns
  `42501 permission denied`. Those two answers mean opposite things. Likewise a private bucket is
  proven by the public endpoint refusing it AND an authenticated list returning `200 []` — either
  probe alone cannot tell "private" from "does not exist".
- **A provider with no consumer is never created.** Removing the only screen that watched
  `fileListProvider` meant its notifier never initialised and never loaded a user id, so its
  `upload()` would have thrown on the first call. **When you delete a screen, check what its
  providers were keeping alive.**
- **Ask which ACCOUNT a diagnostic came from before believing it.** A `jobAppsCount: 0` reading
  looked like a broken query for a user with 36 applications. It was Zaid's second account, which
  genuinely has none. Staging and production share one Supabase project, so the only variable that
  can produce this is which user signed in.
- **Parallel workers work, if the planner does its job first.** 10 worker runs this round across 4
  simultaneous lanes with zero clobbering. What made it work: writing the shared contract as real
  compiling files BEFORE any worker started (so every lane could pass `flutter analyze` alone), and
  listing each lane's forbidden paths explicitly in its prompt. **Without the pre-written contract,
  three of four lanes could not have compiled independently.**
- **Safe silent degradation makes a feature UNDIAGNOSABLE — always leave a way to tell "working but
  weak" apart from "silently doing nothing".** Slice 1's context queries were deliberately written to
  degrade to an omitted section on any error (good: it can't break goal breakdown). The cost only
  showed up at test time: Zaid reported "same as before", which is the EXACT symptom of both "the AI
  needs more data about me" and "every query returned nothing". Neither the planner nor Zaid could
  distinguish them from the UI. Safe fallbacks are still right; just pair them with something
  observable (a log line, a count echoed in the response, a debug surface) before shipping.
- **An empty prompt is not a bad prompt.** Goal breakdown produced generic tasks for months. The cause
  wasn't prompt wording, it was that the prompt contained only the goal title: the model genuinely knew
  nothing about the user. Before tuning wording, check what data the prompt actually receives.
- **The planner catching what the worker missed is not optional theatre.** Two consecutive workers
  produced clean, honest, `flutter analyze`-passing reports on slice 1; planner diff review still
  found two real grounding defects (counts read from a `.limit()`ed array so 57 open tasks were
  reported as 20, and rows labelled "Recent" with no `ORDER BY`). Both would have shipped facts that
  don't map to real rows, the same class as the old daily-brief "upcoming" bug. **Read the diff, every
  time, even when the report looks perfect.**
- **Use a control when you verify.** When `deno check` passed on the changed edge function, it was run
  again on an untouched one to prove the toolchain was actually exercising anything. A green result
  with no control is not evidence.
- **Statements derived from a `.limit()`ed query are unfounded.** If code says "you have N X" and N
  comes from `rows.length` on a limited query, N is wrong for exactly the users who have the most
  data. Use `{ count: "exact" }` and keep the limit for the examples only.
- **A DB trigger that auto-creates a row at signup time can silently defeat an "is this new?" check.**
  `handle_new_user()` inserts a `profiles` row synchronously at `signUp()`, before email confirmation
  and regardless of it — so `profile == null` is NOT a reliable "needs onboarding" signal, and the
  onboarding screen it gates gets skipped. Suspect this pattern anywhere a DB trigger and app-side
  "first time?" logic both react to the same insert. **FIXED 2026-07-25 (`6fc2a39`):** replaced the
  `profile == null` gate with a local per-user-ID SharedPreferences flag (`onboarding_provider.dart`),
  same pattern as the What's New carousel. Do not re-diagnose this — it's closed.
- **AI-extracted fields drift across emails for the SAME real-world entity — never key an identity
  match on more than one AI-extracted field.** The job-tracker matcher required an exact `company` AND
  `role` match to recognize "this update is about an application I already have." The AI extracted a
  different (hallucinated) role string on a later email for the same job, so the match silently failed
  and a duplicate application was created instead of a status update. **Fixed 2026-07-25 (`7b3a73e`):
  match on the more STABLE field only (company), disambiguate secondary fields in application code with
  a fallback to "don't guess," never in the query.** Same lesson as the Daily Brief grounding fix below —
  don't trust an LLM's output to be consistent across independent calls describing the same thing.
- **A duplicated matching query is a bug waiting to diverge — grep for every copy before declaring a
  fix done.** The job-tracker bug above existed in TWO places (`_findExistingId` and `upsertFromScan`),
  with a doc-comment literally claiming they used "the same identity rules." Fixing only the first one
  found would have left a second, now-inconsistent path live. Always grep the method/pattern name
  across the whole file (or repo) before committing a "fixed" bug, per the bug-CLASS-not-instance rule.
- **`response.user != null` does NOT mean authenticated — check `response.session` too.** With
  Supabase's "Confirm email" ON, `signUp()` returns a `user` but `session: null` until they click the
  link. Code that treats `user != null` as "logged in" will route someone into the app with no real
  JWT, and any write will fail as the `anon` role with a `42501` — and if a novice trusts Postgres's own
  error-message hint (`GRANT ... TO anon`), that opens the table to unauthenticated writes. Never do that.
- **Supabase's default built-in email sender is test-only and WILL exhaust in production** —
  `over_email_send_rate_limit` after a handful of sends. Any real user-facing email flow (confirmation,
  password reset) needs custom SMTP configured before real traffic, not after.
- **"Site URL" (Auth → URL Configuration) is a separate setting from the Redirect URLs allow-list** and
  drives where confirmation/reset links land. Left at its `localhost` default, links are dead
  (`otp_expired`/unreachable) even though sign-in itself and the allow-list are both correct.
- **A DNS/SMTP setup report needs independent verification, same as a worker report.** A partner's
  summary claimed SPF/DKIM/DMARC were all written automatically; `nslookup` against a public resolver
  (1.1.1.1) confirmed DKIM was live but SPF was absent at the claimed hostname — always verify
  externally-owned infra claims the same way a worker's code diff gets verified, don't take the summary
  at face value.
- **`npx supabase functions deploy` NEEDS `--workdir .` from this repo.** CLI 2.109.1 locates the
  project root via `supabase/config.toml`, which this repo deliberately does NOT have, so it resolves
  to the wrong directory, warns `failed to read file: ... no such file or directory`, uploads an empty
  bundle and dies with `Entrypoint path does not exist`. The working command is:
  `npx supabase functions deploy <name> --workdir . --project-ref ganbmkphtzdvxxnmprku`.
  Nothing partial deploys when it fails — it is a pure path-resolution error, so a retry is safe.
  **This is NOT a reason to create `config.toml`** (a later `config push` could overwrite hosted auth
  settings, including the OAuth redirect allow-list mobile sign-in depends on).
- **"The AI hallucinated it" is a hypothesis, not a finding — check EVERY table the feature reads.**
  2026-07-23 the Daily Brief was reported as inventing company names. It was faithfully reporting real
  `job_applications` rows; only the tasks/goals lists had been checked. The real defect was junk data
  plus an ungrounded label ("upcoming" for a table with no date column).
- **A model cannot be prompted into traceability.** When the requirement is "every sentence must map to
  a real row", delete the model and assemble the text in code. `daily-brief` was rewritten this way and
  got faster and free as a side effect. Reach for an LLM for judgement, not for reporting facts.
- **Check the TIMESTAMPTZ boundary math on anything server-side that says "today".** Due dates are
  stored as local midnight converted to UTC, so server-side UTC day boundaries are off by a full day
  for any user east of UTC. Pass the client's `tzOffsetMinutes` and derive boundaries from it.
- **An unawaited `Future` inside a `try` makes the `catch` dead code.** A worker wrapped
  `closeInAppWebView()` in try/catch without awaiting it; the error would have escaped as an unhandled
  async error. `flutter analyze` did NOT flag it — read async code by eye.
- **Get the bug REPRODUCTION from Zaid before diagnosing.** 2026-07-23: "sign-in doesn't return to the
  app" sent a planner down a redirect-allow-list investigation; the actual behaviour was that sign-in
  DID work and only the browser tab failed to auto-close. Different bug, different fix. Ask "what
  exactly did you see?" before theorising.
- **A worker's diagnosis is a lead, not a conclusion — check it.** 2026-07-23 a worker reported the
  Android blocker as "install Android Studio + accept licences". Android Studio was ALREADY installed
  and the SDK already had a `licenses` dir; only cmdline-tools was missing, then only SDK 36. Two
  minutes of `ls` beat acting on the summary. Likewise a pasted CI diagnosis claimed a stale server
  lock needing `ps aux`/SSH — our key cannot open a shell, and the run history showed a live
  cross-branch race instead.
- **Two independent platform configs failing IDENTICALLY points at the shared server, not the clients.**
  (Used to reason about the mobile OAuth bug; the logic was sound even though the report turned out to
  describe a different symptom.)
- **Verify a file PATH before putting it in a worker prompt.** 2026-07-23 a planner wrote
  `domain/entities/task.dart` from an audit's line references; the real path is
  `data/models/task.dart`. The worker caught it, but it could as easily have created a duplicate file.
- **Verify inferred state against the live thing, not defaults/memory.** Twice in the 2026-07-22
  session an agent asserted something false from inference: (1) claimed Caddy sent no Cache-Control
  because that's the framework default — Ibrahim's actual live config already had it right, verify with
  `curl -sI`; (2) a worker "corrected" the README to drop email/password auth, assuming Google-only,
  without grepping — `signInWithPassword`/`signUp` are implemented and reachable via `login_screen.dart`
  + `forgot_password_screen.dart`. Rule: before stating a fact about server config or shipped features,
  check it (curl the host, grep the code) — don't infer from what's typical.
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
