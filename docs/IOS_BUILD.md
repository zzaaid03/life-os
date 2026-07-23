# iOS build runbook — free provisioning on a borrowed Mac

Goal: get Life OS running on Zaid's **physical iPhone**, at **zero cost**, using a Mac that
does **not** have a paid Apple Developer account.

This is a self-contained runbook. Follow it top to bottom. If you are an AI agent assisting
with this, read the whole file before running anything, and read "Rules for agents" first.

---

## What this is and is not

We are using **Xcode free provisioning** (a "Personal Team"), which lets any ordinary Apple ID
build and install onto a physically connected device.

**TestFlight is NOT available on this route.** TestFlight requires a paid Apple Developer
Program membership ($99/year). There is no free tier for it. Do not spend time looking for a
workaround — there isn't one.

Free provisioning limits, all of which are expected and none of which are bugs:

- **Provisioning profiles expire 7 days after issuance.** After a week the app stops launching
  on the phone until it is rebuilt and reinstalled from the Mac.
- Max **3 registered devices**, and up to **10 App IDs** at a time, each on the same 7-day clock.
- Capabilities like push notifications and iCloud are unavailable. **Life OS uses none of them**,
  so this does not affect us.

Our Google sign-in uses a plain custom URL scheme (`com.lifeos.app://login-callback`), which
needs no entitlement — so **sign-in works normally on free provisioning**.

---

## Prerequisites — install these BEFORE the session

Xcode is a very large download and is the most common way to lose an afternoon. Install it in
advance, not on the day.

1. **Xcode** — from the Mac App Store. Launch it once after installing and let it finish
   "installing components", then accept the licence:
   ```bash
   sudo xcodebuild -license accept
   ```
2. **Flutter SDK** — must be **3.44.4 or newer**. Do not use 3.44.0: it ships Dart 3.12.0 and
   this project's `pubspec.yaml` requires `^3.12.2`, so it fails to build.
   ```bash
   flutter --version   # confirm >= 3.44.4
   ```
3. **CocoaPods**:
   ```bash
   sudo gem install cocoapods
   ```
4. **Git**, and a USB cable for the iPhone.

Then confirm the toolchain:
```bash
flutter doctor
```
The **Xcode** line must be `[√]`. A missing Android toolchain or Chrome on this machine is fine
and irrelevant — we only care about Xcode here.

---

## Step 1 — get the code

```bash
git clone https://github.com/<owner>/life-os.git
cd life-os
git checkout staging
```

Use the `staging` branch. The mobile fixes (deep link, iOS URL scheme, app name) are there.

---

## Step 2 — create `.env` (THE MOST COMMON FAILURE)

**`.env` is gitignored, so cloning does NOT bring it, and the build fails without it.**
You must recreate it by hand at the repo root.

It contains exactly three values:

```
SUPABASE_URL=...
SUPABASE_PUBLISHABLE_KEY=...
GOOGLE_CLIENT_ID=...
```

Copy the values from Zaid's Windows machine at `C:\Users\Zaid\Desktop\life-os\.env`.

These three are **browser-public** values — they already ship inside the public web bundle and
are downloadable by anyone at `/assets/.env`. Typing them on a borrowed Mac leaks nothing.

**Never put any other key in this file.** Server secrets (Groq API key, Supabase service_role)
live in Supabase Edge Function secrets and must never appear here. If something seems to need a
fourth value, stop and ask Zaid.

**Delete the cloned repo from the borrowed Mac when finished.**

---

## Step 3 — dependencies

```bash
flutter pub get
```

CocoaPods runs automatically during the first iOS build. If it fails, run it manually:

```bash
cd ios && pod install && cd ..
```

---

## Step 4 — signing (the only genuinely fiddly part)

Open the **workspace**, not the project:

```bash
open ios/Runner.xcworkspace
```

> Opening `Runner.xcodeproj` instead is a classic mistake — it builds without the CocoaPods
> dependencies and fails confusingly.

In Xcode:

1. Select the **Runner** project in the left sidebar, then the **Runner** target.
2. Go to **Signing & Capabilities**.
3. Tick **Automatically manage signing**.
4. **Team** → **Add an Account…** → sign in with **Zaid's own Apple ID** (not the Mac owner's —
   the device registration and certificates should belong to Zaid). Then select the resulting
   **"(Personal Team)"** entry.

### If you get "Failed to register bundle identifier"

The bundle ID `com.lifeos.app` is a globally unique namespace on Apple's side, and free
provisioning will refuse it if anyone else has claimed it.

Fix: change **Bundle Identifier** to something unique, e.g. `com.lifeos.app.zaid`.

**Do NOT change `ios/Runner/Info.plist`.** The OAuth URL scheme is declared independently of
the bundle identifier, so sign-in keeps working with the scheme exactly as it is. Changing it
would break sign-in.

This bundle-ID change is a local, throwaway edit for this machine. **Do not commit it.**

---

## Step 5 — build and run on the device

1. Connect the iPhone by USB. On the phone, tap **Trust This Computer** and enter the passcode.
2. In Xcode's device dropdown (top bar), select the iPhone.
3. Run:
   ```bash
   flutter devices          # confirm the iPhone is listed
   flutter run --release -d <device-id>
   ```
   `--debug` also works; `--release` is noticeably faster to use on the phone.

### "Untrusted Developer" — the app installs but will not launch

Expected on free provisioning. On the **iPhone**:

**Settings → General → VPN & Device Management** → tap the developer profile → **Trust**.

Then launch the app again.

---

## Step 6 — verify it actually works

In this order — the first item is the real unknown:

1. **Google sign-in.** Tap sign in. It should open a browser, let you choose the Google account,
   and then **return into the app**. If it strands you on the Life OS website and never comes
   back, the deep link is not working — see Troubleshooting.
2. **App name** on the home screen reads **Life OS**.
3. **Create a task with a due date** and confirm the date is correct (this verifies the
   store-UTC / display-local fix on a real device).

Two expected behaviours that are **not** bugs:

- **Goals are network-only.** With no signal the goals list is empty and creating a goal fails.
  This is a deliberate v1 scope decision — only tasks work offline.
- Pre-existing tasks may render **one day off exactly once** on first load, then stay correct.

---

## Troubleshooting

**Sign-in opens the browser but never returns to the app**
The redirect URL must be registered server-side. In the Supabase dashboard:
**Authentication → URL Configuration → Redirect URLs** must contain
`com.lifeos.app://login-callback`. (Zaid added this on 2026-07-23; verify if sign-in fails.)
Also confirm `ios/Runner/Info.plist` still has the `CFBundleURLTypes` entry with scheme
`com.lifeos.app`.

**"Only test users can sign in"**
Correct and expected. The Google OAuth app is still in **Testing** mode, so only the two
approved test accounts can sign in — on any platform, phone or web. Not an iOS problem.

**The app stopped working after about a week**
The 7-day provisioning profile expired. Reconnect to the Mac and re-run. There is no way around
this without a paid account.

**Build errors mentioning Pods / module not found**
You probably opened `.xcodeproj` instead of `.xcworkspace`. Close it and open the workspace.

---

## Rules for agents assisting with this

- **Never run `npx supabase db push` or `npx supabase functions deploy`.** The CLI is linked to
  a **shared production project** — those commands go live instantly for all users. There is no
  staging equivalent and no undo.
- **Do not create `supabase/config.toml`.** A later `supabase config push` could overwrite the
  hosted auth configuration, including the OAuth redirect URL sign-in depends on.
- **Do not commit anything from the borrowed Mac** — especially the bundle-identifier change
  from Step 4, which is machine-local.
- **Do not create a signing certificate, keystore, or paid-account resource.** Free provisioning
  only.
- **Do not "fix" `Info.plist`, `AndroidManifest.xml`, or the auth repository.** They were changed
  deliberately in commit `db07719` and are correct.
- If something is ambiguous or would exceed this scope, **stop and ask Zaid** rather than guess.

---

## Cleanup

- Delete the cloned repo (and its `.env`) from the borrowed Mac.
- Optionally remove Zaid's Apple ID from **Xcode → Settings → Accounts**.
- The app stays on the iPhone until its profile expires (~7 days).
