/// Offline-first implementation of [TaskRepository].
///
/// Reads always hit the local Drift database for instant feedback.
/// Writes are applied locally first with an appropriate [SyncStatus],
/// then a background sync is triggered to push changes to Supabase.
///
/// On web (where Drift is not available), use [TaskRepositoryImpl.remoteOnly]
/// which reads and writes directly to Supabase.
library;

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
    if (local != null) return local.getById(id);
    return _remote.getById(id);
  }

  @override
  Future<List<Task>> getAll(String userId) async {
    final local = _local;
    if (local != null) return local.getAll(userId);
    return _remote.getAll(userId);
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
      final localTask = newTask.copyWith(syncStatus: SyncStatus.pendingCreate);
      await local.insert(localTask);
      _syncQueue.enqueue(task.userId);
      return localTask;
    }

    // Web: write directly to remote
    await _remote.upsert(newTask);
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
      await local.update(updated);
      _syncQueue.enqueue(task.userId);
      return updated;
    }

    // Web: write directly to remote
    final remoteUpdated = updated.copyWith(syncStatus: SyncStatus.synced);
    await _remote.upsert(remoteUpdated);
    return remoteUpdated;
  }

  @override
  Future<void> delete(String id) async {
    final local = _local;
    if (local != null) {
      final existing = await local.getById(id);
      if (existing == null) return;
      await local.softDelete(id);
      _syncQueue.enqueue(existing.userId);
      return;
    }

    // Web: soft-delete on remote
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
  ///
  /// Delegates to the [SyncService] which pushes pending local
  /// changes and pulls remote updates.
  Future<void> sync(String userId) async {
    final local = _local;
    if (local == null) return; // No sync needed on web
    final syncService = SyncService(localTasks: local, remoteTasks: _remote);
    await syncService.syncTasks(userId);
  }
}
