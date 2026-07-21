/// Drift-backed local data source for tasks.
///
/// Provides offline-first CRUD operations against the local SQLite
/// database via Drift. Conversion between Drift [TaskEntry] rows and
/// the [Task] domain model is handled by [_taskFromEntry] and
/// [_taskToCompanion].
library;

import 'package:drift/drift.dart';
import 'package:life_os/core/data/entity.dart';
import 'package:life_os/core/services/app_database.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// Local data source for [Task] records backed by Drift.
class TaskLocalDataSource {
  /// Creates a [TaskLocalDataSource] with the given [AppDatabase].
  TaskLocalDataSource(this._db);

  final AppDatabase _db;

  /// Fetches a single task by [id], or `null` if not found.
  Future<Task?> getById(String id) async {
    final entry = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null) return null;
    return _taskFromEntry(entry);
  }

  /// Fetches all non-deleted tasks for the given [userId].
  Future<List<Task>> getAll(String userId) async {
    final entries =
        await (_db.select(_db.tasks)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .get();
    return entries.map(_taskFromEntry).toList();
  }

  /// Fetches non-deleted tasks for [userId] filtered by [status].
  Future<List<Task>> getByStatus(String userId, TaskStatus status) async {
    final entries =
        await (_db.select(_db.tasks)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull())
              ..where((t) => t.status.equals(status.name)))
            .get();
    return entries.map(_taskFromEntry).toList();
  }

  /// Inserts a new task row.
  Future<void> insert(Task task) async {
    await _db
        .into(_db.tasks)
        .insert(_taskToCompanion(task), mode: InsertMode.insertOrReplace);
  }

  /// Updates an existing task row.
  Future<void> update(Task task) async {
    await (_db.update(
      _db.tasks,
    )..where((t) => t.id.equals(task.id))).write(_taskToCompanion(task));
  }

  /// Soft-deletes a task by setting `deleted_at` to now.
  Future<void> softDelete(String id) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pendingPush'),
      ),
    );
  }

  /// Permanently removes a task row from the database.
  Future<void> purge(String id) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  /// Fetches all tasks for [userId] that are not yet synced.
  Future<List<Task>> getPendingSync(String userId) async {
    final entries =
        await (_db.select(_db.tasks)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.syncStatus.isNotIn(const ['synced'])))
            .get();
    return entries.map(_taskFromEntry).toList();
  }

  /// Converts a Drift [TaskEntry] row into a [Task] model.
  ///
  /// Drift stores [DateTime] columns as epoch microseconds, while
  /// [Task.fromJson] expects ISO 8601 strings. We build the JSON map
  /// in the format [Task.fromJson] expects, converting dates to ISO
  /// 8601 strings along the way.
  Task _taskFromEntry(TaskEntry entry) {
    return Task.fromJson({
      'id': entry.id,
      'user_id': entry.userId,
      'title': entry.title,
      'description': entry.description,
      'due_date': entry.dueDate?.toIso8601String(),
      'completed_at': entry.completedAt?.toIso8601String(),
      'priority': entry.priority,
      'status': entry.status,
      'parent_task_id': entry.parentTaskId,
      'goal_id': entry.goalId,
      'sort_order': entry.sortOrder,
      'synced_at': entry.syncedAt?.toIso8601String(),
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
      'deleted_at': entry.deletedAt?.toIso8601String(),
      'sync_status': entry.syncStatus,
      'version': entry.version,
    });
  }

  /// Converts a [Task] model into a Drift [TasksCompanion] for writes.
  TasksCompanion _taskToCompanion(Task task) {
    final json = task.toJson();
    return TasksCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      title: Value(json['title'] as String),
      description: Value(json['description'] as String?),
      dueDate: Value(
        (json['due_date'] as String?) != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
      ),
      completedAt: Value(
        (json['completed_at'] as String?) != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      ),
      priority: Value(json['priority'] as int),
      status: Value(json['status'] as String),
      parentTaskId: Value(json['parent_task_id'] as String?),
      goalId: Value(json['goal_id'] as String?),
      sortOrder: Value((json['sort_order'] as num).toDouble()),
      syncedAt: Value(
        (json['synced_at'] as String?) != null
            ? DateTime.parse(json['synced_at'] as String)
            : null,
      ),
      createdAt: Value(DateTime.parse(json['created_at'] as String)),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(
        (json['deleted_at'] as String?) != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
      ),
      syncStatus: Value(json['sync_status'] as String),
      version: Value(json['version'] as int),
    );
  }
}

/// Extension exposing the [SyncStatus] of a [TaskEntry] row.
///
/// Convenience for callers that work directly with Drift rows.
extension TaskEntrySyncStatusX on TaskEntry {
  /// The parsed [SyncStatus] of this row.
  SyncStatus get syncStatusEnum => SyncStatus.values.firstWhere(
    (s) => s.name == syncStatus,
    orElse: () => SyncStatus.synced,
  );
}
