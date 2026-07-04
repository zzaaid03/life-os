/// Offline-first implementation of [TaskRepository].
///
/// Reads always hit the local Drift database for instant feedback.
/// Writes are applied locally first with an appropriate [SyncStatus],
/// then a background sync is triggered to push changes to Supabase.
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

  final TaskLocalDataSource _local;
  final TaskRemoteDataSource _remote;
  final SyncQueue _syncQueue;

  @override
  Future<Task?> getById(String id) => _local.getById(id);

  @override
  Future<List<Task>> getAll(String userId) => _local.getAll(userId);

  @override
  Future<Task> create(Task task) async {
    final now = DateTime.now();
    final newTask = task.copyWith(
      syncStatus: SyncStatus.pendingCreate,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    await _local.insert(newTask);
    _syncQueue.enqueue(task.userId);
    return newTask;
  }

  @override
  Future<Task> update(Task task) async {
    final updated = task.copyWith(
      syncStatus: SyncStatus.pendingPush,
      version: task.version + 1,
      updatedAt: DateTime.now(),
    );
    await _local.update(updated);
    _syncQueue.enqueue(task.userId);
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final existing = await _local.getById(id);
    if (existing == null) return;
    await _local.softDelete(id);
    _syncQueue.enqueue(existing.userId);
  }

  @override
  Future<void> purge(String id) => _local.purge(id);

  /// Synchronizes local and remote task stores for [userId].
  ///
  /// Delegates to the [SyncService] which pushes pending local
  /// changes and pulls remote updates.
  Future<void> sync(String userId) async {
    final syncService = SyncService(localTasks: _local, remoteTasks: _remote);
    await syncService.syncTasks(userId);
  }
}
