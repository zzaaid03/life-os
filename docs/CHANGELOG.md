# CHANGELOG.md

All notable changes to Life OS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2025-06-25

### Added

- Initial project foundation with Flutter 3.44
- Feature-First Clean Architecture folder structure
- Design system with Apple-inspired aesthetics (colors, typography, spacing, icons, animations)
- Light and dark theme support with system-following mode
- GoRouter with all application routes (splash, onboarding, login, home, timeline, life, search, settings)
- Authentication guard with redirect logic
- Supabase configuration via environment variables
- Auth architecture (models, repository interface, Supabase implementation, Riverpod providers)
- Offline database architecture with Drift (SQLite)
- Strict linting configuration with 100+ rules
- Splash screen with animated logo
- Onboarding screen with welcome flow
- Login screen with email/password and Google sign-in UI
- Placeholder screens for all features (home, timeline, life, search, settings)
- Shared widget library (AppCard, AppButton)
- Comprehensive documentation (README, VISION, ROADMAP, ARCHITECTURE, DATABASE, DESIGN_SYSTEM, CONSTITUTION, CONTRIBUTING)
- Prompt engineering templates (MASTER_PROMPT, MILESTONES, REVIEWS)
- Environment configuration with .env template

---

## [1.1.0] — 2025-06-27

### Added

- Premium splash screen with custom scale/fade animation (pure white/black background)
- Minimal welcome screen with single call-to-action
- Production-ready Google Sign-In via Supabase (primary action)
- Production-ready email/password authentication (sign in, sign up)
- Password reset flow with email confirmation UI
- Automatic session persistence and restore (skip auth when valid session exists)
- Profile creation screen (single question: "What should Life call you?")
- Profile data model and Supabase repository (profiles table with RLS)
- Supabase migration 001: create profiles table with automatic trigger
- Permission screens (notifications, calendar, files) — each with explanation and "Not now"
- Home screen with personalized greeting and setup progress card
- Floating bottom navigation bar with glass effect and animated labels
- Beautiful empty states for Timeline, Life, Search, and Settings
- Sign out functionality in Settings
- Reusable AuthErrorBanner widget for consistent error display
- UX.md documentation (user journey, motion principles, permission philosophy)
- Architecture Decision Records for Supabase, Clean Architecture, and Riverpod

### Changed

- Onboarding screen replaced with minimal Welcome screen
- Login screen redesigned: Google as primary, email as secondary
- Splash screen now respects session state (auto-skip to home)
- Router redirect logic updated for profile and onboarding flow
- Supabase service now manages client instance lifecycle
- Shared widgets barrel now exports FloatingNavBar

### Fixed

- Package identifier standardized to com.lifeos.app across all platforms
- Environment key renamed to SUPABASE_PUBLISHABLE_KEY
- AuthException error handling for login and signup
- Profile model constructor ordering for lint compliance

---

*Initial release — foundation established.*