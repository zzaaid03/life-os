# CONTRIBUTING.md

## Welcome!

Thank you for your interest in contributing to Life OS. This document outlines the process for contributing to the project.

---

## Code of Conduct

- Be respectful and inclusive
- Assume good intent
- Provide constructive feedback
- Focus on the code, not the person

---

## Getting Started

### Prerequisites

- Flutter SDK 3.44+
- Dart 3.12+
- Git
- A Supabase account (free tier)

### Setup

1. Fork the repository
2. Clone your fork:

   ```bash
   git clone https://github.com/your-username/life-os.git
   cd life-os
   ```

3. Add the upstream remote:

   ```bash
   git remote add upstream https://github.com/original-owner/life-os.git
   ```

4. Install dependencies:

   ```bash
   flutter pub get
   ```

5. Configure environment:

   ```bash
   cp .env .env.local
   # Edit .env.local with your Supabase credentials
   ```

6. Run the app:

   ```bash
   flutter run
   ```

---

## Development Workflow

### Branch Naming

- `feat/short-description` — New features
- `fix/short-description` — Bug fixes
- `docs/short-description` — Documentation
- `refactor/short-description` — Code refactoring
- `chore/short-description` — Maintenance tasks

### Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add habit tracking dashboard
fix: resolve sync conflict on duplicate entries
docs: update architecture documentation
refactor: extract shared card widget
chore: update dependencies
```

### Pull Request Process

1. Create a branch from `main`
2. Make your changes
3. Ensure all tests pass: `flutter test`
4. Ensure analysis passes: `flutter analyze`
5. Format your code: `dart format lib/`
6. Write or update tests for your changes
7. Update documentation if needed
8. Submit a pull request with a clear description
9. Address review feedback

---

## Code Style

We follow strict Dart linting rules defined in `analysis_options.yaml`.

Key points:

- Use `final` whenever possible
- Prefer `const` constructors
- Use single quotes for strings
- Include trailing commas for multi-line constructs
- Document public APIs with `///`
- Use `package:` imports (not relative)

Run before committing:

```bash
dart format lib/
flutter analyze
flutter test
```

---

## Architecture Guidelines

- Follow Feature-First Clean Architecture
- New features go in `lib/features/{feature_name}/`
- Shared code goes in `lib/core/` or `lib/shared/`
- Use Riverpod for state management
- Use GoRouter for navigation
- Repository pattern for data access
- Never hardcode values — use design tokens

See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.

---

## Testing

- **Unit tests** for business logic and providers
- **Widget tests** for UI components
- **Integration tests** for critical flows

Run tests:

```bash
flutter test                    # All tests
flutter test test/features/     # Feature tests only
```

---

## Documentation

- Update README.md if adding major features
- Document new design tokens in DESIGN_SYSTEM.md
- Update CHANGELOG.md with your changes
- Add JSDoc-style comments (`///`) for public APIs

---

## Questions?

Open an issue on GitHub or start a discussion.

---

*Thank you for contributing to Life OS!*