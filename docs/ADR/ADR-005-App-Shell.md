# ADR-005: App Shell Architecture

## Status

Accepted

## Date

2025-06-27

## Context

Life OS needs a permanent application shell that wraps all main app screens (Home, Timeline, Life, Search, Settings) with:

- A floating bottom navigation bar
- A floating action button (FAB) for quick creation
- Responsive content centering for tablet/desktop
- Consistent navigation state across all tabs

Previously, each screen individually embedded its own `FloatingNavBar` as a `bottomNavigationBar`. This caused:

1. **Navigation bar rebuilt on every screen transition** — losing animation continuity
2. **No shared FAB** — each screen would need its own
3. **Inconsistent state** — the nav bar's active state was manually passed as a string per screen
4. **No responsive centering** — content stretched edge-to-edge on tablets/desktops

## Decision

**Use GoRouter's `ShellRoute` with a shared `AppShell` widget.**

The main app routes (Home, Timeline, Life, Search, Settings) are nested inside a `ShellRoute` whose builder wraps the child in an `AppShell` widget. The `AppShell` provides:

- `FloatingNavBar` — reads the current location from `GoRouterState` for active state
- `FloatingActionButton.large` — centered FAB for quick create
- `ConstrainedBox(maxWidth: 600)` — centers content on larger screens
- `SafeArea` — proper insets on all platforms

## Alternatives Considered

### Per-Screen Nav Bar (Previous Approach)

- **Rejected because**: Nav bar rebuilds on every transition, no shared FAB, manual active-state passing, no responsive centering.

### Custom Navigator with IndexedStack

- **Rejected because**: Loses GoRouter's declarative routing, deep linking, and URL-based navigation. Would require reimplementing back button handling and browser URL sync.

### BottomNavigationBar (Material Default)

- **Rejected because**: Doesn't match the premium, Apple-inspired design language. No glass effect, no floating behavior, no custom animations.

## Architecture

```
GoRouter
├── Auth routes (splash, welcome, login, signUp, forgotPassword)
├── Onboarding routes (createProfile, permissions)
└── ShellRoute (AppShell)
    ├── /home → HomeScreen (dashboard)
    ├── /timeline → TimelineScreen
    ├── /life → LifeScreen
    ├── /search → SearchScreen
    └── /settings → SettingsScreen
```

### AppShell Composition

```
AppShell
├── Scaffold
│   ├── body: SafeArea → Center → ConstrainedBox(600) → child
│   ├── floatingActionButton: FAB.large (centered, "Coming Soon")
│   └── bottomNavigationBar: FloatingNavBar (reads GoRouterState)
```

## Reusable Components

| Widget | Purpose |
|--------|---------|
| `AppShell` | Wraps all main screens with nav + FAB + responsive centering |
| `DashboardCard` | Premium card with optional header (icon, title, trailing) |
| `SectionHeader` | Section title with optional "See all" action |
| `QuickActionButton` | Compact icon+label button for the quick actions grid |
| `EmptyStateWidget` | Consistent empty states (compact and full variants) |
| `AnimatedGreeting` | Time-based greeting with fade-in animation |
| `ComingSoonDialog` | Reusable dialog for unimplemented features |

## Empty State Philosophy

Every empty state in Life OS follows three rules:

1. **Never say "No Data"** — use warm, encouraging language
2. **Always include an icon** — visual anchor for the section
3. **Always include a subtitle** — a gentle call to action

The `EmptyStateWidget` supports both `compact` (inline in cards) and full (centered in screen) variants.

## Consequences

### Positive

- Single navigation instance — smooth transitions, no rebuilds
- Shared FAB across all main screens
- Automatic responsive centering on tablet/desktop/web
- Consistent empty states across the entire app
- Clean separation: screens focus on content, shell handles navigation

### Negative

- All main screens must work within the 600px max-width constraint
- The FAB is always visible on all main screens (may not be desired on Settings)

### Neutral

- Auth and onboarding screens are outside the shell (no nav bar) — this is intentional

## References

- [GoRouter ShellRoute documentation](https://pub.dev/documentation/go_router/latest/go_router/ShellRoute-class.html)
- [Flutter responsive design guidelines](https://docs.flutter.dev/ui/adaptive-responsive)