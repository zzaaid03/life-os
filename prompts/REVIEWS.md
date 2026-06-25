# REVIEWS.md

This file tracks code review feedback and architectural decisions made during development.

---

## Review Log

### Review #1 — Foundation (2025-06-25)

**Reviewer**: Senior Flutter Engineer (AI)
**Scope**: Full project foundation

#### Decisions Made

1. **Riverpod over BLoC** — Riverpod provides better compile-time safety and simpler syntax for this project's scale.

2. **Drift over Hive** — Drift offers type-safe SQL, proper migrations, and complex query support needed for relational data.

3. **GoRouter over Navigator 2.0** — GoRouter provides declarative routing with built-in auth guards.

4. **Feature-First over Layer-First** — Self-contained features scale better for a project expected to grow for years.

5. **Inter font over SF Pro** — Inter is open-source, widely available, and equally readable.

6. **No state persistence library yet** — Will evaluate `flutter_secure_storage` vs `shared_preferences` when implementing session persistence.

#### Concerns

- Drift's web support is limited — web users will rely on Supabase directly
- Need to evaluate sync conflict resolution strategy before Milestone 3
- Google sign-in requires platform-specific setup (not yet configured)

#### Action Items

- [ ] Configure Google Sign-In for Android and iOS
- [ ] Set up Supabase project and run initial migrations
- [ ] Implement session persistence
- [ ] Add integration tests for auth flow

---

## Future Reviews

Add new review entries as architectural decisions are made or reviewed.

Format:

```markdown
### Review #{N} — {Title} ({Date})

**Reviewer**: {Name/Role}
**Scope**: {What was reviewed}

#### Decisions Made
- ...

#### Concerns
- ...

#### Action Items
- [ ] ...
```

---

*Reviews are critical for maintaining architectural integrity over time.*