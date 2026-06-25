# Life OS

Your life, beautifully organized.

**Life OS** is a premium, open-source life management application built with Flutter. It combines habit tracking, journaling, goal setting, and personal analytics into one beautifully designed experience.

---

## Features

- **Timeline** — Chronological view of your life events, habits, and journal entries
- **Life Dashboard** — Track goals, habits, health metrics, and personal growth
- **Search** — Full-text search across all your data
- **Offline First** — Works seamlessly without internet using local SQLite storage
- **Cloud Sync** — Real-time sync across devices via Supabase
- **Dark Mode** — Beautiful light and dark themes
- **Authentication** — Email/password and Google sign-in

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

   Copy `.env` to your local `.env` file (it's already gitignored):

   ```bash
   cp .env .env.local
   ```

   Fill in your Supabase credentials:

   ```
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
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
│   ├── timeline/     # Timeline view
│   ├── life/         # Life management
│   ├── search/       # Global search
│   └── settings/     # App settings
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

Life OS is open-source software licensed under the MIT license.