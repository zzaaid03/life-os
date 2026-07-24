# Life OS

Your life, beautifully organized.

**Life OS** is a premium, open-source life management application built with Flutter. Its headline feature is AI that reads your Gmail, extracts tasks automatically, and keeps your job applications up to date — on top of that it gives you a unified timeline, AI-assisted goal breakdown, and a daily AI briefing to keep you organized.

---

> **Just want to look around?** Tap **"Try it — no sign-up"** on the welcome screen to explore a fully-seeded sandbox — no account, no Gmail, nothing to install.

## Features

- **Instant Demo — no sign-up** — Explore the full app with realistic seeded data (a job-seeker persona, live-feeling AI features) directly from the welcome screen, with zero account or Gmail access required.
- **AI Inbox Scan** — Reads your Gmail and automatically extracts tasks and job-application updates
- **Job Application Tracker** — Manual add/edit/delete with a 5-stage status pipeline (applied, viewed, interview, rejected, accepted)
- **AI Goal Breakdown** — Turn a goal into AI-suggested tasks with derived progress tracking
- **AI Daily Brief** — A daily AI-generated summary of what matters today
- **Timeline & Calendar** — Unified timeline with a month calendar view of your tasks
- **Search** — Full-text search across all your data
- **Offline-Capable (mobile)** — Tasks work offline via local SQLite and sync when you reconnect; some data (goals, jobs, profile) is currently online-only
- **Cloud Sync** — Real-time sync across devices via Supabase
- **Dark Mode** — Beautiful light and dark themes
- **Authentication** — Email/password and Google sign-in

---

## Roadmap

*Indicative direction, not a commitment to dates.*

- [x] Web app — live in production
- [x] AI inbox scan, job tracker, goal breakdown, daily brief
- [x] **Mobile apps (Android & iOS)** — built and running on device; app-store publishing still to come
- [ ] Public availability — currently in closed testing while Google completes verification of the Gmail access scope
- [ ] Account-level settings sync (theme and onboarding preferences are currently stored per-device)
- [ ] Push notifications and reminders

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.44+ |
| Language | Dart 3.12+ |
| State Management | Riverpod |
| Routing | GoRouter |
| Backend | Supabase |
| Local Database | Drift (SQLite) |
| Architecture | Feature-First Clean Architecture |

---

## Getting Started

### Prerequisites

- Flutter SDK 3.44+
- Dart 3.12+
- A Supabase project (free tier works)

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/your-username/life-os.git
   cd life-os
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure environment variables**

   Copy `.env.example` to `.env`:

   ```bash
   cp .env.example .env
   ```

   Fill in your Supabase credentials:

   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_PUBLISHABLE_KEY=your_publishable_key
   GOOGLE_CLIENT_ID=your_google_client_id
   ```

4. **Run the app**

   ```bash
   flutter run
   ```

---

## Project Structure

```
lib/
├── core/
│   ├── config/       # App-wide configuration
│   ├── theme/        # Design system (colors, typography, spacing)
│   ├── router/       # GoRouter configuration
│   └── services/     # Supabase, Drift, and other services
├── shared/
│   └── widgets/      # Reusable UI components
├── features/
│   ├── auth/         # Authentication feature
│   ├── home/         # Home dashboard
│   ├── tasks/        # Task management
│   ├── goals/        # AI goal breakdown
│   ├── jobs/         # Job application tracker
│   ├── inbox/        # AI inbox scan
│   ├── calendar/     # Calendar view
│   ├── timeline/     # Timeline view
│   ├── search/       # Global search
│   ├── settings/     # App settings
│   ├── demo/         # No-sign-up demo/sandbox mode
│   └── onboarding/   # First-run tour & what's new
└── main.dart         # Entry point
```

---

## Architecture

Life OS follows **Feature-First Clean Architecture**:

- **Data Layer** — Repositories, models, data sources
- **Domain Layer** — Business logic, use cases, providers
- **Presentation Layer** — Screens, widgets, UI state

Each feature is self-contained with its own data, domain, and presentation layers.

---

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

---

## License

Life OS is open-source software licensed under the Apache License, Version 2.0.