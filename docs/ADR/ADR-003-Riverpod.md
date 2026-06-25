# ADR-003: Riverpod for State Management

## Status

Accepted

## Date

2025-06-25

## Context

Life OS requires a state management solution that:

- Scales from simple UI state to complex async data flows
- Supports dependency injection for testability
- Provides compile-time safety (no runtime provider errors)
- Handles authentication state globally
- Manages feature-specific state (habits, entries, goals)
- Supports offline-first data synchronization
- Is approachable for new contributors

We evaluated the major Flutter state management solutions against these requirements.

## Decision

**Riverpod** has been selected as the state management solution for Life OS.

## Alternatives Considered

### Provider

- **Pros**: Simple, officially recommended by Flutter team (historically), large community
- **Cons**: Runtime errors for missing providers, `BuildContext` dependency limits use outside widgets, no compile-time safety, limited support for complex async flows, being superseded by Riverpod
- **Rejected because**: Provider's lack of compile-time safety and `BuildContext` dependency would cause bugs at scale. Riverpod is its spiritual successor with all the same patterns plus safety.

### BLoC

- **Pros**: Strong separation of concerns, event-driven, well-documented, popular in enterprise Flutter apps
- **Cons**: Heavy boilerplate (separate Event, State, and BLoC classes per feature), steep learning curve, over-engineered for simple state, requires additional packages for DI
- **Rejected because**: The boilerplate-to-value ratio is too high for this project. Most Life OS features have straightforward state needs (load data, display data, mutate data). BLoC's event-driven model adds ceremony without proportional benefit.

### GetX

- **Pros**: All-in-one (routing, DI, state management), minimal boilerplate, high performance claims
- **Cons**: Breaks Flutter conventions, encourages anti-patterns (business logic in UI), poor testability, controversial in the Flutter community, monolithic approach
- **Rejected because**: GetX's "do everything" philosophy conflicts with Clean Architecture principles. Its patterns make testing difficult and encourage tight coupling.

### Riverpod (Selected)

- **Pros**: Compile-time safety (no runtime `ProviderNotFoundException`), no `BuildContext` dependency, multiple provider types for different use cases (Provider, StateNotifierProvider, FutureProvider, StreamProvider), built-in DI, excellent testability with provider overrides, active maintenance by the creator of Provider
- **Cons**: Steeper learning curve than Provider, more concepts to learn, annotation-based code generation (`@riverpod`) adds another tool, smaller community than Provider/BLoC
- **Selected because**: Riverpod provides the best balance of safety, flexibility, and testability. Its compile-time guarantees eliminate an entire class of runtime errors. The provider override system makes testing trivial. The variety of provider types maps well to Life OS's diverse state needs.

## Provider Architecture

### Provider Types Used

| Provider Type | Use Case | Example |
|---------------|----------|---------|
| `Provider` | Singleton services | `SupabaseClient`, `AppDatabase` |
| `StateNotifierProvider` | Mutable state with actions | `AuthNotifier`, feature notifiers |
| `FutureProvider` | Async data that loads once | Configuration, user profile |
| `StreamProvider` | Reactive data streams | Auth state changes, real-time sync |

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

### Testing Pattern

```dart
// Override providers for tests
ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(mockRepository),
  ],
  child: MyApp(),
);
```

## Consequences

### Positive

- Compile-time safety prevents provider-not-found errors in production
- No `BuildContext` dependency enables state access in services and repositories
- Provider overrides make testing straightforward and isolated
- Multiple provider types match different state patterns naturally
- Active development and growing ecosystem

### Negative

- Learning curve for team members new to Riverpod
- Some concepts (`Ref`, `WidgetRef`, family providers) require study
- Annotation-based code generation (`@riverpod`) is optional but adds complexity
- Migration path from Provider requires refactoring (not applicable since we start fresh)

### Neutral

- Riverpod 3.x is in development with breaking changes; we pin to 2.x for stability
- The `riverpod` package must be listed as a direct dependency alongside `flutter_riverpod` for `package:` imports

## References

- [Riverpod Documentation](https://riverpod.dev)
- [Riverpod vs Provider Comparison](https://riverpod.dev/docs/from_provider)
- [Riverpod Testing Guide](https://riverpod.dev/docs/cookbooks/testing)