/// Generic sync engine for Life OS entities.
///
/// Currently supports tasks. Designed to be extended to every
/// entity that implements [Entity]. The sync engine is offline-first:
/// it pushes pending local changes to Supabase and pulls remote
/// updates back into local storage, resolving conflicts with a
/// last-write-wins strategy based on `updated_at`.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/data/entity.dart';
import 'package:life_os/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:life_os/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// A minimal queue interface used by repositories to trigger sync.
///
/// In a future iteration this will be backed by a persistent queue
/// (e.g. a Drift table) so pending operations survive app restarts.
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
    // No-op: sync is triggered manually for now.
  }
}

/// Generic sync service coordinating local and remote data sources.
///
/// For now it handles [Task] entities. The [syncTasks] method pushes
/// pending local changes to Supabase, pulls remote updates since the
/// last sync, and resolves conflicts using last-write-wins.
class SyncService {
  /// Creates a [SyncService] with the given data sources.
  SyncService({required this._localTasks, required this._remoteTasks});

  final TaskLocalDataSource _localTasks;
  final TaskRemoteDataSource _remoteTasks;

  /// In-memory cache of the last sync timestamp per user.
  ///
  /// Persisted to SharedPreferences in a future iteration.
  final Map<String, DateTime> _lastSyncTimestamps = <String, DateTime>{};

  /// Synchronizes tasks for the given [userId].
  ///
  /// 1. Pushes all locally pending tasks to Supabase.
  /// 2. Pulls remote tasks updated since the last sync.
  /// 3. Resolves conflicts using last-write-wins on `updated_at`.
  Future<void> syncTasks(String userId) async {
    debugPrint('[SyncService] syncTasks($userId) START');
    await _pushPendingTasks(userId);
    await _pullRemoteTasks(userId);
    debugPrint('[SyncService] syncTasks($userId) END');
  }

  /// Pushes all locally pending tasks to Supabase.
  Future<void> _pushPendingTasks(String userId) async {
    final pending = await _localTasks.getPendingSync(userId);
    debugPrint('[SyncService] PUSH: ${pending.length} pending tasks');
    for (final task in pending) {
      try {
        debugPrint(
          '[SyncService]   pushing id=${task.id} '
          'title="${task.title}" syncStatus=${task.syncStatus}',
        );
        await _remoteTasks.upsert(task);
        final synced = task.copyWith(
          syncStatus: SyncStatus.synced,
          syncedAt: DateTime.now(),
        );
        await _localTasks.update(synced);
        debugPrint('[SyncService]   pushed + marked synced: id=${task.id}');
      } catch (e) {
        debugPrint('[SyncService]   PUSH FAILED for id=${task.id}: $e');
      }
    }
  }

  /// Pulls remote tasks updated since the last sync and merges them.
  Future<void> _pullRemoteTasks(String userId) async {
    final lastSync =
        _lastSyncTimestamps[userId] ?? DateTime.fromMillisecondsSinceEpoch(0);
    debugPrint('[SyncService] PULL: lastSync=$lastSync');
    final remoteTasks = await _remoteTasks.getSince(userId, lastSync);
    debugPrint('[SyncService] PULL: got ${remoteTasks.length} remote tasks');
    for (final remote in remoteTasks) {
      debugPrint(
        '[SyncService]   remote task: id=${remote.id} '
        'title="${remote.title}" updatedAt=${remote.updatedAt}',
      );

      final local = await _localTasks.getById(remote.id);

      if (local == null) {
        debugPrint('[SyncService]   → no local match, inserting locally');
        await _localTasks.insert(
          remote.copyWith(syncStatus: SyncStatus.synced),
        );
        continue;
      }

      debugPrint(
        '[SyncService]   → local exists: updatedAt=${local.updatedAt} '
        'syncStatus=${local.syncStatus}',
      );

      if (remote.updatedAt.isAfter(local.updatedAt)) {
        debugPrint('[SyncService]   → remote newer, updating local');
        await _localTasks.update(
          remote.copyWith(syncStatus: SyncStatus.synced),
        );
      } else {
        debugPrint('[SyncService]   → local newer or equal, skipping');
      }
    }

    _lastSyncTimestamps[userId] = DateTime.now();
  }
}
