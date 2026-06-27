# UX.md

## User Journey

The Life OS onboarding experience follows a carefully designed flow that reduces cognitive load at every step.

---

## Screen Flow

```
App Launch
    ↓
Splash Screen (2.2s, auto-advance)
    ↓
┌──────────────────────┐
│ Session exists?       │
└──────────────────────┘
    ↓ Yes              ↓ No
  Home            Welcome Screen
                        ↓
                  Login Screen
                        ↓
              ┌─────────────────┐
              │ First login?     │
              └─────────────────┘
                  ↓ Yes        ↓ No
          Create Profile      Home
                  ↓
          Permission Screens
          (Notifications → Calendar → Files)
                  ↓
                Home
```

---

## Motion Principles

### 1. Purposeful Animation

Every animation in Life OS serves a purpose:
- **Fade** — Welcoming entrance, calming presence
- **Scale** — Drawing attention to important elements
- **Slide** — Natural progression through content

### 2. Duration Philosophy

| Speed | Duration | Usage |
|-------|----------|-------|
| Fast | 150ms | Micro-interactions (toggles, taps) |
| Standard | 250ms | Most transitions |
| Slow | 350ms | Emphasis, reveals, welcome moments |
| Page | 300ms | Screen transitions |

### 3. Easing Philosophy

- **easeOut** — Elements coming to rest (default for entrances)
- **easeInOut** — Screen transitions
- **easeIn** — Elements leaving

No bouncy, playful animations during the onboarding flow. The tone is calm and premium.

---

## Permission Philosophy

Life OS never asks for a permission without explaining why.

### Permission Flow

1. **Explain** what the permission enables
2. **Show** the benefit to the user
3. **Ask** for permission
4. **Accept** "Not now" gracefully

Each permission has its own dedicated screen with:
- A clear, benefit-focused headline
- One or two sentences of explanation
- A prominent "Allow" button
- A subtle "Not now" option

### Permission Order

1. **Notifications** — Gentle reminders for habits and goals
2. **Calendar** — Integrate events into the timeline
3. **Files** — Attach photos to journal entries

Permissions are asked one at a time. Progress is shown via a three-dot indicator at the top of each screen.

---

## Empty State Philosophy

Empty states are opportunities, not voids.

### Principles

- Never display "No Data" or "Nothing here"
- Use warm, inviting language
- Make the user feel welcomed, not abandoned

### Empty State Copy

| Screen | Message |
|--------|---------|
| Timeline | "Your journey begins today." |
| Life | "I'm here whenever you need me." |
| Search | "Search your life." |
| Settings | "Everything, your way." |

---

## Cognitive Load Reduction

### One Question at a Time

The profile creation screen asks exactly one question: "What should Life call you?"

No email collection (already provided during authentication).
No avatar selection (can be added later).
No preferences (defaults work well).

### Google Sign-In First

Google is the primary authentication action because:
- One tap vs. filling a form
- No password to remember
- Instant for most users

Email/password is secondary for users who prefer it or don't use Google.

### Automatic Session Restore

Users never log in twice unnecessarily. If a valid session exists:
- Skip the entire auth flow
- Go directly to Home
- Load profile data in the background

---

## Design System Adherence

All screens follow the Life OS design system strictly:
- Colors from `AppColors`
- Spacing from `AppSpacing`
- Radius from `AppRadius`
- Typography from `AppTypography`
- Icons from `AppIcons`
- Animations from `AppAnimations`

No one-off styles. No hardcoded values. The design system is the single source of truth.

---

## Accessibility

- All interactive elements have semantic labels
- Minimum tap target: 44x44 logical pixels (exceeded by our 52px button height)
- Dynamic text size support via `MediaQuery.textScaler`
- Dark mode support throughout the entire flow
- Screen reader-friendly navigation via `Semantics` widgets
- Back buttons include `tooltip` for clarity

---

## Technical Implementation

### State-Driven Navigation

The router redirect logic handles the flow automatically:
- `AuthStatus.unknown` → Splash
- `AuthStatus.unauthenticated` → Welcome
- `AuthStatus.authenticated` + no profile → Create Profile
- `AuthStatus.authenticated` + profile exists → Home

### Animation Architecture

Animations use `flutter_animate` with custom `AnimationController` for the splash screen. Screen-level animations use the declarative `.animate()` extension for consistency.

---

*Last updated: June 2025 — Milestone 2 completion.*