/// Generic sync engine for Life OS entities.
///
/// Currently supports tasks. Designed to be extended to every
/// entity that implements [Entity]. The sync engine is offline-first:
/// it pushes pending local changes to Supabase and pulls remote
/// updates back into local storage, resolving conflicts with a
/// last-write-wins strategy based on `updated_at`.
library;

import 'package:life_os/core/data/entity.dart';
import 'package:life_os/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:life_os/features/tasks/data/datasources/task_remote_data_source.dart';

/// A minimal queue interface used by repositories to trigger sync.
abstract class SyncQueue {
  /// Enqueues a sync operation for the given [userId].
  void enqueue(String userId);
}

/// A no-op [SyncQueue] used when sync is not yet wired up.
class NoopSyncQueue implements SyncQueue {
  /// Creates a [NoopSyncQueue].
  const NoopSyncQueue();

  @override
  void enqueue(String userId) {
    // No-op: sync is triggered by the notifier after mutations.
  }
}

/// Generic sync service coordinating local and remote data sources.
class SyncService {
  /// Creates a [SyncService] with the given data sources.
  SyncService({required this._localTasks, required this._remoteTasks});

  final TaskLocalDataSource _localTasks;
  final TaskRemoteDataSource _remoteTasks;

  final Map<String, DateTime> _lastSyncTimestamps = <String, DateTime>{};

  /// Synchronizes tasks for the given [userId].
  ///
  /// 1. Pushes all locally pending tasks to Supabase.
  /// 2. Pulls remote tasks updated since the last sync.
  /// 3. Resolves conflicts using last-write-wins on `updated_at`.
  Future<void> syncTasks(String userId) async {
    await _pushPendingTasks(userId);
    await _pullRemoteTasks(userId);
  }

  Future<void> _pushPendingTasks(String userId) async {
    final pending = await _localTasks.getPendingSync(userId);
    for (final task in pending) {
      try {
        await _remoteTasks.upsert(task);
        final synced = task.copyWith(
          syncStatus: SyncStatus.synced,
          syncedAt: DateTime.now(),
        );
        await _localTasks.update(synced);
      } catch (_) {
        // Sync failures are retried on the next sync cycle.
      }
    }
  }

  Future<void> _pullRemoteTasks(String userId) async {
    final lastSync =
        _lastSyncTimestamps[userId] ?? DateTime.fromMillisecondsSinceEpoch(0);
    final remoteTasks = await _remoteTasks.getSince(userId, lastSync);

    for (final remote in remoteTasks) {
      final local = await _localTasks.getById(remote.id);

      if (local == null) {
        await _localTasks.insert(
          remote.copyWith(syncStatus: SyncStatus.synced),
        );
        continue;
      }

      if (remote.updatedAt.isAfter(local.updatedAt)) {
        await _localTasks.update(
          remote.copyWith(syncStatus: SyncStatus.synced),
        );
      }
    }

    _lastSyncTimestamps[userId] = DateTime.now();
  }
}
