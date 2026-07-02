# ROADMAP.md

## Current Version: 1.1.0 (Identity)

The foundation has been laid. The project structure, architecture, design system, authentication scaffolding, and routing are in place.

---

## Milestone 1: Authentication & Onboarding ✅

- [x] Project initialization
- [x] Folder structure and architecture
- [x] Design system (colors, typography, spacing, icons, animations)
- [x] Theme configuration (light, dark, system)
- [x] GoRouter with all routes and auth guard
- [x] Supabase configuration (env-based)
- [x] Auth architecture (models, repository, providers)
- [x] Splash, onboarding, and login screens
- [x] Offline database architecture (Drift)
- [x] Strict linting and code quality setup

---

## Milestone 2: Identity — UX, Authentication & First Experience ✅

- [x] Premium splash screen with custom animations
- [x] Minimal welcome screen
- [x] Complete Google OAuth sign-in flow
- [x] Complete email/password sign-in flow
- [x] Sign-up screen with validation
- [x] Password reset flow with confirmation UI
- [x] Session persistence and auto-restore
- [x] Profile creation (single question flow)
- [x] Permission screens (notifications, calendar, files)
- [x] Home first experience with greeting + setup progress
- [x] Floating bottom navigation with glass effect
- [x] Beautiful empty states for all tabs
- [x] Smooth animations throughout
- [x] Accessibility (semantic labels, tooltips, screen readers)
- [x] UX documentation
- [x] Zero analyzer warnings
- [ ] Session persistence
- [ ] Auth error handling and user feedback
- [ ] Auth integration tests

---

## Milestone 3: Data Foundation ✅

- [x] Universal entity design (9 entities with base properties)
- [x] Supabase migrations (002: tasks, notes, goals, habits, habit_entries, journal_entries, tags, entity_tags, attachments, sync_queue)
- [x] Data models for all entities (Task, Note, Goal, Habit, HabitEntry, JournalEntry, Tag, Attachment)
- [x] Repository interfaces for all entities (8 repositories)
- [x] Use case skeletons (30 use cases across 6 features)
- [x] Sync engine design document (SYNC_ENGINE.md)
- [x] Data model documentation (DATA_MODEL.md)
- [x] Unit tests for entity serialization and value equality
- [x] RLS policies on all tables
- [x] Proper indexes and foreign keys
- [x] Soft deletes on all tables
- [x] Zero analyzer warnings

---

## Milestone 4: App Shell & Dashboard ✅

- [x] Production app shell with ShellRoute
- [x] Floating bottom navigation (glass effect, animated labels)
- [x] Floating action button (FAB) for quick create
- [x] Home dashboard with personalized greeting
- [x] Quick actions grid (New Task, Note, Habit, Goal)
- [x] Dashboard cards with beautiful empty states
- [x] Reusable widgets (DashboardCard, SectionHeader, QuickActionButton, EmptyStateWidget, AnimatedGreeting)
- [x] Responsive layout (max-width centering for tablet/desktop/web)
- [x] Settings screen with account info and preferences
- [x] Search screen with search field
- [x] Subtle fade-in and slide-up animations
- [x] Accessibility (semantics, tap targets, dark mode)
- [x] Zero analyzer warnings

---

## Milestone 5: Timeline Feature (v1.3.0)

- [ ] Timeline UI with infinite scroll
- [ ] Entry creation and editing
- [ ] Rich text support
- [ ] Media attachments
- [ ] Entry categories and tags
- [ ] Timeline search and filters

---

## Milestone 5: Life Dashboard (v1.4.0)

- [ ] Habit tracking UI
- [ ] Goal setting and progress tracking
- [ ] Health metrics integration
- [ ] Mood tracking
- [ ] Personal analytics and insights
- [ ] Customizable dashboard widgets

---

## Milestone 6: Search & Discovery (v1.5.0)

- [ ] Full-text search across all data
- [ ] Advanced filters
- [ ] Saved searches
- [ ] Search suggestions
- [ ] Recent searches

---

## Milestone 7: Settings & Customization (v1.6.0)

- [ ] Theme switching (light/dark/system)
- [ ] Notification preferences
- [ ] Data export (JSON, CSV)
- [ ] Account management
- [ ] Privacy settings
- [ ] Appearance customization

---

## Milestone 8: Platform Expansion (v2.0.0)

- [ ] iOS release
- [ ] Android release
- [ ] Web release
- [ ] Desktop support (macOS, Windows, Linux)
- [ ] Cross-platform sync

---

## Milestone 9: Advanced Features (v2.5.0)

- [ ] AI-powered insights
- [ ] Natural language entry parsing
- [ ] Smart reminders
- [ ] Integration with health platforms (Apple Health, Google Fit)
- [ ] Calendar integration
- [ ] API for third-party integrations

---

## Milestone 10: Community & Ecosystem (v3.0.0)

- [ ] Plugin system
- [ ] Community themes
- [ ] Public API
- [ ] Developer documentation
- [ ] Contribution workflow
- [ ] Community governance model

---

*This roadmap is a living document. Priorities may shift based on community feedback and real-world usage.*