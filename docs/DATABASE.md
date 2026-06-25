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
2. Copy your project URL and anon key to `.env`
3. Run migrations (to be created in future milestones)

### Schema (Planned)

```sql
-- Users (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Entries (journal, notes, thoughts)
CREATE TABLE entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  title TEXT,
  content TEXT,
  entry_type TEXT NOT NULL, -- 'journal', 'note', 'thought'
  mood TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habits
CREATE TABLE habits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  frequency TEXT NOT NULL, -- 'daily', 'weekly', 'monthly'
  color TEXT,
  icon TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habit completions
CREATE TABLE habit_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id UUID REFERENCES habits(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  completed_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(habit_id, completed_date)
);

-- Goals
CREATE TABLE goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  target_date DATE,
  progress REAL DEFAULT 0,
  status TEXT DEFAULT 'active', -- 'active', 'completed', 'archived'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Row-Level Security (RLS)

All tables will have RLS policies ensuring users can only access their own data:

```sql
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own entries"
  ON entries FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own entries"
  ON entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entries"
  ON entries FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own entries"
  ON entries FOR DELETE
  USING (auth.uid() = user_id);
```

---

## Drift (SQLite)

### Purpose

- Instant local reads (no network latency)
- Offline functionality
- Full CRUD without internet
- Type-safe queries with Dart

### Architecture

```dart
@DriftDatabase(tables: [Entries, Habits, Goals, ...])
class AppDatabase extends _$AppDatabase {
  // DAOs and queries defined here
}
```

### Tables (Planned)

Tables will mirror the Supabase schema for seamless sync:

- `entries` — Journal entries and notes
- `habits` — Habit definitions
- `habit_completions` — Daily habit tracking
- `goals` — Goal tracking
- `sync_queue` — Pending sync operations

### Migration Strategy

Drift migrations will be versioned:

```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async { await m.createAll(); },
    onUpgrade: (m, from, to) async {
      if (from < 2) { /* migration logic */ }
    },
  );
}
```

---

## Sync Architecture

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

1. **Writes**: Save to Drift → Add to sync queue → Push to Supabase
2. **Reads**: Always from Drift (instant)
3. **Conflict Resolution**: Last-write-wins based on `updated_at`
4. **Background Sync**: Periodic sync when online

---

## Data Models

All models use `freezed` for immutability and `json_serializable` for serialization:

```dart
@freezed
class Entry with _$Entry {
  const factory Entry({
    required String id,
    required String userId,
    String? title,
    required String content,
    required EntryType type,
    String? mood,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Entry;

  factory Entry.fromJson(Map<String, dynamic> json) => _$EntryFromJson(json);
}
```

---

*Database schemas will be implemented in Milestone 3.*