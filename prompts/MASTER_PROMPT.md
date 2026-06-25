# MASTER_PROMPT.md

This file serves as the master prompt template for AI-assisted development of Life OS.

---

## Project Context

- **Project**: Life OS
- **Framework**: Flutter 3.44+
- **Language**: Dart 3.12+
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Backend**: Supabase
- **Local DB**: Drift (SQLite)
- **Architecture**: Feature-First Clean Architecture

---

## Prompt Template

When creating new prompts for Life OS development, use this structure:

```markdown
# Life OS — Prompt {NUMBER}
## {TITLE}

You are the Senior Flutter Engineer responsible for building Life OS.

This is NOT a prototype.

---

# Context

{Describe what already exists and what needs to be built}

---

# Requirements

{List specific requirements}

---

# Constraints

- Never sacrifice maintainability
- Never duplicate code
- Always prefer reusable solutions
- Follow the existing architecture
- Use design system tokens (never hardcode values)
- Write tests for business logic
- Update documentation

---

# Definition of Done

- [ ] Code compiles
- [ ] Analysis passes (flutter analyze)
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Conventional commits
```

---

## Architecture Reference

```
lib/
├── core/
│   ├── config/       # AppConfig, EnvConfig
│   ├── theme/        # AppColors, AppTypography, AppSpacing, AppRadius, AppIcons, AppAnimations, AppTheme
│   ├── router/       # AppRouter, AppRoutes
│   └── services/     # SupabaseService, DatabaseService
├── shared/
│   └── widgets/      # AppCard, AppButton, etc.
├── features/
│   └── {feature}/
│       ├── data/         # models/, repositories/
│       ├── domain/       # providers/
│       └── presentation/ # screens/, widgets/
└── main.dart
```

---

## Design Tokens

Always use these instead of raw values:

- **Colors**: `AppColors.primary`, `AppColors.error`, etc.
- **Spacing**: `AppSpacing.sm`, `AppSpacing.lg`, etc.
- **Radius**: `AppRadius.sm`, `AppRadius.card`, etc.
- **Icons**: `AppIcons.home`, `AppIcons.add`, etc.
- **Animations**: `AppAnimations.standard`, `AppAnimations.fast`, etc.

---

## Provider Pattern

```dart
// 1. Define state
@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState({ ... }) = _FeatureState;
}

// 2. Create notifier
class FeatureNotifier extends StateNotifier<FeatureState> {
  FeatureNotifier(this._repository) : super(const FeatureState());
  final FeatureRepository _repository;
}

// 3. Expose provider
final featureProvider = StateNotifierProvider<FeatureNotifier, FeatureState>((ref) {
  final repository = ref.watch(featureRepositoryProvider);
  return FeatureNotifier(repository);
});
```

---

## Commit Convention

```
feat: add {feature description}
fix: resolve {bug description}
docs: update {documentation}
refactor: extract {component}
chore: update {dependency/task}
test: add tests for {feature}
```

---

*Update this template as patterns evolve.*