# ADR-002: Feature-First Clean Architecture

## Status

Accepted

## Date

2025-06-25

## Context

Life OS is expected to grow significantly over years of development, with dozens of features spanning authentication, timeline, habits, goals, health tracking, search, settings, and more. The architecture must:

- Scale to hundreds of files without becoming unmaintainable
- Allow features to be developed, tested, and potentially removed independently
- Enable multiple developers to work on different features without merge conflicts
- Keep business logic testable and UI replaceable
- Survive framework and dependency changes with minimal refactoring

We evaluated several architectural patterns against these requirements.

## Decision

**Feature-First Clean Architecture** has been selected.

## Alternatives Considered

### Layer-First (MVC/MVP/MVVM by type)

- **Pros**: Simple to understand, common in tutorials, works for small projects
- **Cons**: Features are scattered across directories (all models in one folder, all screens in another). Adding or removing a feature requires touching 5+ directories. Cross-feature coupling is hard to detect. Does not scale beyond ~20 screens.
- **Rejected because**: Life OS will have 50+ screens. Layer-first would become unmanageable within months.

### BLoC Architecture (with layer-first)

- **Pros**: Strong separation of UI and business logic, well-documented, popular in Flutter community
- **Cons**: Boilerplate-heavy (events, states, blocs per feature), steep learning curve for contributors, over-engineered for simple features
- **Rejected because**: Riverpod provides equivalent separation with less boilerplate. BLoC's event-driven model adds complexity without proportional benefit for this project.

### Feature-First Clean Architecture (Selected)

- **Pros**: Self-contained features, clear boundaries, independent testability, scales linearly, easy to add/remove features, supports team parallelization
- **Cons**: Some code duplication across features (mitigated by `core/` and `shared/` modules), requires discipline to maintain boundaries
- **Selected because**: This architecture directly addresses the project's long-term scaling needs. Each feature owns its data, domain logic, and presentation. The `core/` module provides cross-cutting concerns (theme, routing, services) while `shared/` provides reusable widgets.

## Architecture Layers

```
features/{feature}/
├── data/           # Models, repositories, data sources
├── domain/         # Providers, use cases, business logic
└── presentation/   # Screens, feature-specific widgets
```

### Layer Responsibilities

| Layer | Responsibility | Depends On |
|-------|---------------|------------|
| Presentation | UI rendering, user interaction, local UI state | Domain |
| Domain | Business logic, state management, use cases | Data |
| Data | API calls, database queries, model serialization | Core services |

### Dependency Rule

Dependencies point inward. Presentation depends on Domain. Domain depends on Data. Data depends on Core services. No layer depends on a layer above it.

## Consequences

### Positive

- Features are independently developable and testable
- Adding a new feature requires creating one directory with three sub-layers
- Removing a feature is a single directory deletion
- Team members can own entire features without stepping on each other
- Architecture scales linearly with feature count
- Clear boundaries prevent accidental coupling

### Negative

- More directories and files than layer-first (mitigated by clear naming conventions)
- Requires discipline to keep features truly independent
- Some boilerplate in setting up each feature's layers
- New contributors need to understand the pattern before contributing

### Neutral

- `core/` and `shared/` modules require careful curation to avoid becoming dumping grounds
- Feature boundaries must be actively maintained during code review

## References

- [Clean Architecture by Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Feature-First Architecture Guide](https://docs.flutter.dev/app-architecture)