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

*Initial release — foundation established.*