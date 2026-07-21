# Life OS — VPS Deployment Handoff

This doc is for whoever owns the VPS. You don't need to know anything
about Flutter or this codebase beyond what's written here.

## What this is

Life OS is a **static single-page web app** (Flutter compiled to
JavaScript/HTML/CSS). It runs entirely in the browser and talks directly to
a hosted Supabase backend (already deployed elsewhere — not your concern).
There is **no server-side app code, no database, and no Flutter runtime**
on your end. The VPS just serves static files from disk.

Two independent copies of the same app are hosted side by side:

- **Stable** — `lifeos.deadthrone.dev`
- **Staging** — `staging.lifeos.deadthrone.dev`

They share one Supabase backend; the only difference is which build was
deployed and a small "STAGING" banner shown in the staging build.

## How deployment works

The server runs **Caddy**, serving files directly off disk — no
containers, no separate web server process, nothing to restart.
Deployment is just files landing in a directory:

- `~/lifeos/stable/` → served as `lifeos.deadthrone.dev`
- `~/lifeos/staging/` → served as `staging.lifeos.deadthrone.dev`

**GitHub Actions does the deploying.** `.github/workflows/deploy.yml`:

1. Triggers on push to `main` (deploys stable) or `staging` (deploys
   staging), or manually via `workflow_dispatch` with an environment
   choice.
2. Builds the Flutter web bundle in CI (`scripts/build-web.sh <env>`).
3. Rsyncs `build/web/` straight into the matching directory on the VPS
   over SSH, using a key restricted server-side to `rrsync` on
   `~/lifeos` — it cannot open a shell or run any command on the VPS.

There is no image to build, no container to restart, and no manual step
on the VPS side for a normal deploy — new files simply appear and Caddy
serves them.

## Your part: Caddy and TLS

**You own Caddy and certificates.** Point Caddy's site blocks at the two
directories above and issue certs for both hostnames (Caddy's automatic
HTTPS handles this in the usual case). No path rewriting is needed — the
app uses hash-based routing (`/#/route`), so every request is for a static
file or `/`.

## What you do NOT need

- No Flutter SDK, no Dart, no build tooling — CI builds the bundle.
- No `.env` file or secrets on the VPS — the config baked into the build
  (`SUPABASE_URL`, publishable key, Google client ID) is all browser-safe
  and public by design, and is written from GitHub Actions secrets during
  the CI build, not stored on the server.
- No database — Supabase is hosted separately and already running.
- No containers or extra services to restart.

## How an update ships

Push to `main` (or `staging`) and GitHub Actions handles the rest: builds
the bundle in CI, then rsyncs it (with `--delete`, so removed files are
cleaned up) into the matching `~/lifeos/<env>/` directory. Caddy serves
whatever is currently on disk, so the update is live as soon as the rsync
completes — no restart needed on your end.
