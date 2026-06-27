# DATABASE.md

## Overview

Life OS uses a **dual-database architecture**:

1. **Supabase (PostgreSQL)** — Cloud database for sync and backup
2. **Drift (SQLite)** — Local database for offline-first access

---

## Supabase (PostgreSQL)

### Purpose

- Primary source of truth for synced data
- Real-time subscriptions for multi-device sync
- Authentication and user management
- Row-Level Security (RLS) for data protection

### Setup

1. Create a project at [supabase.com](https://supabase.com)
2. Copy your project URL and publishable key to `.env`
3. Run migrations in order from `supabase/migrations/`

### Migrations

| Migration | File | Description |
|-----------|------|-------------|
| 001 | `001_create_profiles.sql` | Profiles table with auto-create trigger |
| 002 | `002_create_entity_tables.sql` | All core entity tables (tasks, notes, goals, habits, journal, tags, attachments, sync_queue) |

**How to apply**:

```bash
# Via Supabase SQL Editor — paste and run each migration
# Or via Supabase CLI:
supabase db push
```

---

## Universal Entity Design

Every table in Life OS shares a common set of columns for consistent sync, audit, and soft-delete behavior.

### Base Columns (on every table)

| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID` | Client-generated UUID v4 (PK) |
| `user_id` | `UUID` | FK to `profiles(id)` |
| `created_at` | `TIMESTAMPTZ` | Creation timestamp |
| `updated_at` | `TIMESTAMPTZ` | Last modification timestamp |
| `deleted_at` | `TIMESTAMPTZ` | Soft-delete timestamp (NULL = active) |
| `sync_status` | `TEXT` | One of: synced, pendingPush, pendingCreate, pendingPull, conflict, failed |
| `version` | `INTEGER` | Monotonically increasing for conflict detection |

### Schema Tables

| Table | Rows | Description |
|-------|------|-------------|
| `profiles` | 1 per user | User profile (extends auth.users) |
| `tasks` | N per user | Actionable items with priorities and status |
| `notes` | N per user | Free-form notes with pinning |
| `goals` | N per user | Long-term objectives with progress |
| `habits` | N per user | Recurring behaviors |
| `habit_entries` | N per habit | Daily completion records |
| `journal_entries` | N per user | Personal journal with mood tracking |
| `tags` | N per user | Categorization labels |
| `entity_tags` | N per entity | Junction table for entity-tag relationships |
| `attachments` | N per entity | Files linked to any entity (polymorphic) |
| `sync_queue` | N per user | Pending sync operations |

See [DATA_MODEL.md](DATA_MODEL.md) for the complete entity catalog with field details and relationships.

---

## Row-Level Security (RLS)

Every table has RLS enabled with four standard policies:

```sql
ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own {table}"      ON {table} FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own {table}"    ON {table} FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own {table}"    ON {table} FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own {table}"    ON {table} FOR DELETE USING (auth.uid() = user_id);
```

This ensures **database-level** data isolation — users can never access another user's data, even if the client code has a bug.

---

## Indexes

Every table includes:

- `(user_id)` — For user-scoped queries
- `(sync_status, updated_at)` — For efficient sync engine queries
- Feature-specific indexes (e.g., `(status)` on tasks, `(entry_date)` on journal entries)

---

## Drift (SQLite)

### Purpose

- Instant local reads (no network latency)
- Offline functionality
- Full CRUD without internet
- Type-safe queries with Dart

### Architecture

The connection provider is set up in `lib/core/services/database_service.dart`. Individual feature DAOs and table definitions will be added as each feature's business logic is implemented.

```dart
final databaseConnectionProvider = Provider<QueryExecutor>((ref) {
  return openDatabaseConnection();
});
```

### Tables (To Be Implemented Per Feature)

Tables will mirror the Supabase schema for seamless sync. Table definitions (Drift `Table` classes) will be created alongside each feature's repository implementation in future milestones.

---

## Sync Architecture

See [SYNC_ENGINE.md](SYNC_ENGINE.md) for the complete sync engine design.

### Offline-First Pattern

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│   UI     │────▶│  Drift   │────▶│ Supabase │
│          │     │ (Local)  │     │ (Cloud)  │
└──────────┘     └──────────┘     └──────────┘
     ▲                │                 │
     │                │                 │
     └────────────────┴─────────────────┘
              Read from local first
```

### Sync Strategy

1. **Writes**: Save to Drift → Set `syncStatus = pendingPush` → Background push to Supabase
2. **Reads**: Always from Drift (instant)
3. **Conflict Resolution**: Optimistic concurrency via `version` field; last-write-wins default
4. **Background Sync**: Periodic pull + push when online, debounced

---

## Data Models

All models implement the `Entity` interface and use:
- `equatable` for value equality
- Manual `fromJson`/`toJson` for serialization (no code generation required for foundation models)

```dart
class Task extends Equatable implements Entity {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    // ... entity base properties
  });
}
```

---

*Last updated: June 2025 — Milestone 3 completion.*