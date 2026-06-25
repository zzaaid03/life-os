# ARCHITECTURE.md

## Overview

Life OS follows **Feature-First Clean Architecture** — a layered architecture that organizes code by feature rather than by type, while maintaining clear separation of concerns.

---

## Architecture Layers

```
┌─────────────────────────────────────────┐
│         PRESENTATION LAYER              │
│  Screens, Widgets, UI State             │
├─────────────────────────────────────────┤
│           DOMAIN LAYER                  │
│  Providers, Use Cases, Business Logic   │
├─────────────────────────────────────────┤
│            DATA LAYER                   │
│  Repositories, Models, Data Sources     │
├─────────────────────────────────────────┤
│          INFRASTRUCTURE                 │
│  Supabase, Drift, Services              │
└─────────────────────────────────────────┘
```

---

## Feature Structure

Each feature follows this internal structure:

```
features/
└── {feature_name}/
    ├── data/
    │   ├── models/          # Data models (freezed)
    │   ├── repositories/    # Repository interfaces + implementations
    │   └── datasources/     # Remote and local data sources
    ├── domain/
    │   ├── providers/       # Riverpod providers (state notifiers)
    │   └── usecases/        # Business logic use cases
    └── presentation/
        ├── screens/         # Full screen widgets
        └── widgets/         # Feature-specific widgets
```

---

## Core Module

The `core/` module contains cross-cutting concerns shared across all features:

```
core/
├── config/       # App-wide constants and configuration
├── theme/        # Design system tokens and theme definitions
├── router/       # GoRouter configuration and route definitions
└── services/     # Infrastructure services (Supabase, Drift)
```

---

## Shared Module

The `shared/` module contains reusable widgets and utilities:

```
shared/
└── widgets/      # Reusable UI components (buttons, cards, etc.)
```

---

## Data Flow

### Unidirectional Data Flow

```
User Action → Provider (StateNotifier) → Repository → Data Source
                    ↓
              State Update
                    ↓
               UI Rebuild
```

### Authentication Flow

```
App Launch → Splash → Check Auth State
                          ↓
              ┌───────────┴───────────┐
              ↓                       ↓
        Authenticated          Unauthenticated
              ↓                       ↓
           Home                  Onboarding → Login
```

---

## State Management

Life OS uses **Riverpod** for state management:

- **StateNotifierProvider** — For complex state with actions (e.g., `AuthNotifier`)
- **Provider** — For services and repositories (e.g., `SupabaseClient`, `AppDatabase`)
- **FutureProvider** — For async data that loads once
- **StreamProvider** — For reactive data streams

### Provider Hierarchy

```
supabaseClientProvider (Provider<SupabaseClient>)
    ↓
authRepositoryProvider (Provider<AuthRepository>)
    ↓
authProvider (StateNotifierProvider<AuthNotifier, AuthState>)
    ↓
createRouter(ref) — Uses authProvider for redirect guards
```

---

## Routing

GoRouter handles all navigation with:

- **Declarative routes** — All routes defined in `app_router.dart`
- **Authentication guard** — Redirect logic based on `authProvider`
- **Deep linking** — Supported by GoRouter out of the box
- **Error handling** — Custom 404 page for unknown routes

---

## Offline Architecture

Life OS is **offline-first**:

1. **Writes** go to local Drift database first
2. **Sync** pushes changes to Supabase when online
3. **Reads** come from local database for instant access
4. **Conflict resolution** — Last-write-wins with server timestamps

```
User Action → Local DB (Drift) → Background Sync → Supabase
                  ↓
            UI Updates Instantly
```

---

## Dependency Injection

Riverpod serves as the DI container. All dependencies are:

- **Provided** through Riverpod providers
- **Overridable** for testing via `ProviderScope.overrides`
- **Lazy** — Created only when first accessed

---

## Testing Strategy

| Layer | Test Type | Tool |
|-------|-----------|------|
| Data | Unit tests for repositories | mocktail |
| Domain | Unit tests for providers | mocktail + Riverpod |
| Presentation | Widget tests | flutter_test |
| Integration | End-to-end flows | integration_test |

---

## Key Design Decisions

1. **Feature-First over Layer-First** — Features are self-contained, making it easy to add, remove, or modify features without touching unrelated code.

2. **Repository Pattern** — Abstracts data sources behind interfaces, enabling easy swapping of implementations (e.g., Supabase → Firebase).

3. **Riverpod over BLoC** — Riverpod provides compile-time safety, better testability, and simpler syntax for this project's needs.

4. **Drift over Hive** — Drift provides type-safe SQL, migrations, and complex queries. Hive is simpler but less powerful for relational data.

5. **GoRouter over Navigator 2.0** — GoRouter provides declarative routing with built-in auth guards and deep linking support.

---

*This document should be updated whenever architectural decisions change.*