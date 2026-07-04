/// Offline-first implementation of [TaskRepository].
///
/// Reads always hit the local Drift database for instant feedback.
/// Writes are applied locally first with an appropriate [SyncStatus],
/// then a background sync is triggered to push changes to Supabase.
///
/// On web (where Drift is not available), use [TaskRepositoryImpl.remoteOnly]
/// which reads and writes directly to Supabase.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/data/entity.dart';
import 'package:life_os/core/sync/sync_service.dart';
import 'package:life_os/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:life_os/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Offline-first implementation of [TaskRepository].
class TaskRepositoryImpl implements TaskRepository {
  /// Creates a [TaskRepositoryImpl] with the given data sources and
  /// [SyncQueue].
  TaskRepositoryImpl({
    required this._local,
    required this._remote,
    required this._syncQueue,
  });

  /// Creates a remote-only [TaskRepositoryImpl] for web platforms
  /// where Drift (local SQLite) is not available.
  ///
  /// All reads and writes go directly to Supabase.
  const TaskRepositoryImpl.remoteOnly({
    required this._remote,
    required this._syncQueue,
  }) : _local = null;

  final TaskLocalDataSource? _local;
  final TaskRemoteDataSource _remote;
  final SyncQueue _syncQueue;

  @override
  Future<Task?> getById(String id) async {
    final local = _local;
    if (local != null) {
      debugPrint('[TaskRepo] getById($id) → local (Drift)');
      return local.getById(id);
    }
    debugPrint('[TaskRepo] getById($id) → remote (Supabase)');
    return _remote.getById(id);
  }

  @override
  Future<List<Task>> getAll(String userId) async {
    final local = _local;
    if (local != null) {
      debugPrint('[TaskRepo] getAll($userId) → local (Drift)');
      final tasks = await local.getAll(userId);
      debugPrint('[TaskRepo] getAll local returned ${tasks.length} tasks');
      return tasks;
    }
    debugPrint('[TaskRepo] getAll($userId) → remote (Supabase)');
    final tasks = await _remote.getAll(userId);
    debugPrint('[TaskRepo] getAll remote returned ${tasks.length} tasks');
    for (final t in tasks) {
      debugPrint(
        '[TaskRepo]   id=${t.id} title="${t.title}" '
        'status=${t.status} dueDate=${t.dueDate} '
        'deletedAt=${t.deletedAt}',
      );
    }
    return tasks;
  }

  @override
  Future<Task> create(Task task) async {
    final now = DateTime.now();
    final newTask = task.copyWith(
      syncStatus: SyncStatus.synced,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );

    final local = _local;
    if (local != null) {
      debugPrint('[TaskRepo] create → local (Drift): id=${task.id}');
      final localTask = newTask.copyWith(syncStatus: SyncStatus.pendingCreate);
      await local.insert(localTask);
      _syncQueue.enqueue(task.userId);
      return localTask;
    }

    debugPrint('[TaskRepo] create → remote (Supabase): id=${task.id}');
    await _remote.upsert(newTask);
    debugPrint('[TaskRepo] create remote succeeded: id=${newTask.id}');
    return newTask;
  }

  @override
  Future<Task> update(Task task) async {
    final updated = task.copyWith(
      syncStatus: SyncStatus.pendingPush,
      version: task.version + 1,
      updatedAt: DateTime.now(),
    );

    final local = _local;
    if (local != null) {
      debugPrint('[TaskRepo] update → local (Drift): id=${task.id}');
      await local.update(updated);
      _syncQueue.enqueue(task.userId);
      return updated;
    }

    debugPrint('[TaskRepo] update → remote (Supabase): id=${task.id}');
    final remoteUpdated = updated.copyWith(syncStatus: SyncStatus.synced);
    await _remote.upsert(remoteUpdated);
    return remoteUpdated;
  }

  @override
  Future<void> delete(String id) async {
    final local = _local;
    if (local != null) {
      debugPrint('[TaskRepo] delete → local (Drift): id=$id');
      final existing = await local.getById(id);
      if (existing == null) return;
      await local.softDelete(id);
      _syncQueue.enqueue(existing.userId);
      return;
    }

    debugPrint('[TaskRepo] delete → remote (Supabase): id=$id');
    await _remote.delete(id);
  }

  @override
  Future<void> purge(String id) async {
    final local = _local;
    if (local != null) {
      await local.purge(id);
    }
    await _remote.delete(id);
  }

  /// Synchronizes local and remote task stores for [userId].
  Future<void> sync(String userId) async {
    final local = _local;
    if (local == null) return; // No sync needed on web
    final syncService = SyncService(localTasks: local, remoteTasks: _remote);
    await syncService.syncTasks(userId);
  }
}
