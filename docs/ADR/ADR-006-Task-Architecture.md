# ADR-006: Task Architecture

## Status

Accepted

## Date

2025-06-27

## Context

Tasks are the first fully functional feature in Life OS. The implementation must establish the pattern that all future features (Habits, Notes, Goals, Journal) will follow. The architecture must support:

- Offline-first operation (create, edit, complete tasks without internet)
- Background synchronization with Supabase
- Conflict resolution using version fields
- Integration with the dashboard, search, and timeline
- Clean separation between data sources, repository, and presentation

## Decision

**Implement tasks using the existing Feature-First Clean Architecture with a three-layer data source pattern.**

### Data Layer

```
TaskLocalDataSource (Drift)  ←→  TaskRepositoryImpl  ←→  TaskRemoteDataSource (Supabase)
                                         ↓
                                  SyncService (background)
```

- **Reads**: Always from local Drift database (instant, offline)
- **Writes**: Always to local first, then queue for background sync
- **Sync**: Push pending changes to Supabase, pull remote updates, resolve conflicts

### Repository Pattern

`TaskRepositoryImpl` implements the `TaskRepository` interface:
- `getById` / `getAll` → local only
- `create` → local insert with `syncStatus = pendingCreate`
- `update` → local update with `syncStatus = pendingPush`, version++
- `delete` → local soft-delete with `syncStatus = pendingPush`
- `sync` → push + pull + conflict resolution

### Sync Engine

`SyncService` is a generic service that currently handles tasks but is designed to support all entities:

1. **Push**: Get all tasks with `syncStatus != synced`, upsert to Supabase, mark as `synced`
2. **Pull**: Get all tasks from Supabase where `updated_at > lastSyncTimestamp`, upsert to local
3. **Conflict**: If both local and remote changed, compare `updatedAt` — last-write-wins
4. **Version tracking**: Each mutation increments `version`, used for optimistic concurrency

### State Management

`TaskListNotifier` (StateNotifier) manages the task list state:
- Loads tasks on authentication
- Exposes `createTask`, `updateTask`, `deleteTask`, `completeTask`, `refresh`, `sync`
- Derived providers: `todayTasksProvider`, `upcomingTasksProvider`, `completedTasksProvider`

### Presentation

- **TaskListScreen**: Three sections (Today, Upcoming, Completed) with swipe actions
- **TaskDetailScreen**: Full task view with edit/delete/complete actions
- **TaskEditorSheet**: Bottom sheet for create/edit with validation
- **Reusable widgets**: TaskCard, TaskCheckbox, TaskPriorityChip, TaskDueDateBadge, TaskSection, TaskEmptyState

### Dashboard Integration

The home dashboard's "Focus for Today" card watches `todayTasksProvider` and shows:
- Up to 3 task summaries with completion checkboxes
- Task count badge
- Completion progress bar
- Empty state with "Create first task" action when no tasks exist

### Timeline Integration

Completed tasks automatically appear in the Timeline screen by watching `completedTasksProvider`. No manual duplication — the same data source feeds both screens.

## Alternatives Considered

### Direct Supabase reads (no local cache)

- **Rejected**: Violates the offline-first constitution principle. Users would see "no internet" errors.

### BLoC pattern for state management

- **Rejected**: ADR-003 already established Riverpod. Switching patterns mid-project would create inconsistency.

### Real-time subscriptions instead of pull sync

- **Considered for future**: Real-time would reduce pull latency but adds complexity. Current pull-on-demand is sufficient for MVP.

## Consequences

### Positive

- Tasks work fully offline
- Sync is automatic and non-blocking
- The same pattern can be reused for Habits, Notes, Goals, Journal
- Dashboard and Timeline update reactively via Riverpod providers
- Clean test boundaries (repository interface, data source separation)

### Negative

- Two data sources (local + remote) require conversion logic
- Sync conflicts are possible (mitigated by last-write-wins)
- Drift code generation adds build step complexity

### Neutral

- The `SyncService` is currently task-specific but designed for generalization
- SharedPreferences persistence for `lastSyncTimestamp` is a future enhancement

## Task Lifecycle

```
Created (pendingCreate) → Synced → Updated (pendingPush) → Synced → Completed (pendingPush) → Synced → Deleted (pendingPush) → Synced
```

Each state transition:
1. Writes to local Drift database
2. Updates `syncStatus` and `version`
3. Triggers background sync (non-blocking)
4. UI updates immediately from local state

## Future Extension for Subtasks

The `Task` model already includes `parentTaskId` for subtask relationships. The Drift table and Supabase migration both support this field. Subtask UI can be added in a future milestone without schema changes.

## References

- [ADR-002: Feature-First Clean Architecture](ADR-002-Clean-Architecture.md)
- [ADR-003: Riverpod](ADR-003-Riverpod.md)
- [Sync Engine Design](../SYNC_ENGINE.md)
- [Data Model](../DATA_MODEL.md)