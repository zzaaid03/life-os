# ADR-004: Passkeys Web SDK — Browser Close Prevention

## Status

Accepted

## Date

2025-06-27

## Context

When running Life OS on the web (`flutter run -d chrome`), the browser tab opened and immediately closed with no error message. Investigation revealed that the `passkeys_web` plugin — a transitive dependency of `supabase_flutter` → `gotrue` → `passkeys` → `passkeys_web` — calls `window.close()` at startup if the `PasskeyAuthenticator` JavaScript object is not found in the browser environment.

The Flutter web toolchain auto-registers all web plugins found in the dependency tree. Since `passkeys` is a hard dependency of `gotrue` (Supabase's auth library) with no configuration opt-out, the `passkeys_web` plugin always loads during web startup.

## Decision

**Include the `bundle.js` script** from the `passkeys_web` package in `web/index.html` to satisfy the `PasskeyAuthenticator` check, preventing the `window.close()` call.

Additionally, **add global startup error handling** in `main.dart` so that if any fatal initialization error occurs (Supabase unreachable, .env missing, any unexpected exception), the user sees a friendly error screen instead of a blank page or crashed tab.

## Alternatives Considered

### Dependency Override (Rejected)

Override the `passkeys` package in `pubspec.yaml` with a fork that strips out web dependencies.

- **Rejected because**: Requires maintaining a forked package, tracking upstream changes, resolving merge conflicts on every `pub upgrade`. Fragile and adds ongoing maintenance burden for a problem that has a zero-maintenance solution.

### Conditional Plugin Exclusion (Not Possible)

Dart/Flutter does not support conditionally excluding a federated plugin based on build configuration. All web plugins in the dependency tree are auto-registered.

### Removing passkeys from gotrue (Not Possible)

`passkeys` is a hard dependency of `gotrue` (part of the `GoTrueClient` API surface). We cannot remove it without forking `gotrue` and `supabase_flutter`, which would be even more maintenance-intensive.

### Including bundle.js (Selected)

- **Pros**: Zero ongoing maintenance, works with upstream, leaves passkey support available if wanted in future, standard approach documented by the passkeys_web package
- **Cons**: Adds 13.5 KB to the web bundle; passkeys remain available as an auth method even though we don't expose them in the UI
- **Selected because**: This is the intended integration pattern from the package authors. The bundle is static and never needs updating. It solves the crash with no code changes and no maintenance burden.

## Consequences

### Positive

- No runtime crash on web startup
- No maintenance burden — bundle.js never changes
- Passkey support available in the future without additional setup
- Email/password and Google OAuth continue to work as before

### Negative

- 13.5 KB added to web payload (negligible)
- Another external JS file to track in version control
- Passkey auth method is technically available even though we don't expose it in the UI (not a security risk — passkeys require explicit user action)

### Neutral

- If Supabase ever makes passkeys truly optional at the gotrue level, we can remove bundle.js and the script tag

## Additional Measure: Startup Error Handling

To prevent silent crashes from any initialization failure (not just passkeys), `main.dart` now wraps the entire startup sequence in a try-catch. If any exception occurs before `runApp()`, a minimal MaterialApp renders a friendly error screen with:

- The Life OS logo
- A clear error message
- The actual error text (for user reporting)
- A "Retry" button that reloads the page (on web) or restarts (on native)

This ensures the user always sees *something* — never a white screen or a silently closed tab.

## References

- [passkeys_web package](https://pub.dev/packages/passkeys_web)
- [bundle.js release](https://github.com/corbado/flutter-passkeys/releases/download/2.4.0/bundle.js)
- [Supabase Flutter issue: passkeys_web crashes on web](https://github.com/supabase/supabase-flutter/issues)