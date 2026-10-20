/// Generic sync engine for Life OS entities.
///
/// Currently supports tasks. The sync engine is offline-first:
/// it pushes pending local changes to Supabase and pulls remote
/// updates back into local storage. A local row with unsynced edits is
/// never overwritten by a pull: the pending local change wins.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/sync/sync_state.dart';
import 'package:life_os/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:life_os/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  ///
  /// [syncState], if given, is updated at the start and end of each run.
  SyncService({
    required this._localTasks,
    required this._remoteTasks,
    this._syncState,
  });

  final TaskLocalDataSource _localTasks;
  final TaskSyncRemote _remoteTasks;
  final SyncStateNotifier? _syncState;

  static const int _pageSize = 500;
  static const Duration _overlap = Duration(seconds: 60);

  Future<void>? _inFlight;
  bool _rerun = false;
  String _requestedUserId = '';

  static String _watermarkKey(String userId) => 'tasks_sync_watermark_$userId';

  /// Synchronizes tasks for the given [userId].
  ///
  /// Only one run happens at a time. A call made while a run is in flight
  /// returns that run's Future and asks for exactly one more run when it
  /// ends, so edits made during the run are not left waiting.
  ///
  /// Failures are logged and recorded in the sync state; this does not
  /// throw for them.
  Future<void> syncTasks(String userId) {
    _requestedUserId = userId;
    final running = _inFlight;
    if (running != null) {
      _rerun = true;
      return running;
    }
    final run = _runLoop().whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<void> _runLoop() async {
    do {
      _rerun = false;
      await _runOnce(_requestedUserId);
    } while (_rerun);
  }

  Future<void> _runOnce(String userId) async {
    _syncState?.started();
    final errors = <String>[];
    await _pushPendingTasks(userId, errors);
    try {
      await _pullRemoteTasks(userId);
    } catch (e) {
      debugPrint('Sync pull failed for user $userId: $e');
      errors.add('Pull failed: $e');
    }
    var pendingCount = 0;
    try {
      pendingCount = await _localTasks.countPending(userId);
    } catch (e) {
      debugPrint('Sync could not count pending tasks: $e');
      errors.add('Could not count pending tasks: $e');
    }
    _syncState?.finished(
      error: errors.isEmpty ? null : errors.join('; '),
      pendingCount: pendingCount,
    );
  }

  Future<void> _pushPendingTasks(String userId, List<String> errors) async {
    final List<Task> pending;
    try {
      pending = await _localTasks.getPendingSync(userId);
    } catch (e) {
      debugPrint('Sync could not read pending tasks: $e');
      errors.add('Could not read pending tasks: $e');
      return;
    }
    for (final task in pending) {
      try {
        await _remoteTasks.upsert(task);
        await _localTasks.markSyncedIfUnchanged(task, DateTime.now());
      } catch (e) {
        // The row stays pending and is retried on the next run.
        debugPrint('Sync push failed for task ${task.id}: $e');
        errors.add('Push failed for task ${task.id}: $e');
      }
    }
  }

  Future<void> _pullRemoteTasks(String userId) async {
    // Web has no local store (reads go straight to the server), so a pull
    // would only download rows that are thrown away.
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _watermarkKey(userId);
    final saved = DateTime.tryParse(prefs.getString(key) ?? '')?.toUtc();
    final since = saved == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : saved.subtract(_overlap);

    DateTime? newest;
    ({DateTime updatedAt, String id})? cursor;
    while (true) {
      final page = await _remoteTasks.getSince(
        userId,
        since,
        cursor: cursor,
        limit: _pageSize,
      );
      for (final remote in page) {
        await _localTasks.applyRemote(remote);
        final updatedAt = remote.updatedAt.toUtc();
        if (newest == null || updatedAt.isAfter(newest)) newest = updatedAt;
      }
      if (page.length < _pageSize) break;
      // Taken from the remote row itself (never a local Drift row), so the
      // server's microseconds survive and the next page starts exactly here.
      cursor = (updatedAt: page.last.updatedAt.toUtc(), id: page.last.id);
    }

    // Every page is applied: only now is it safe to move the watermark.
    if (newest != null && (saved == null || newest.isAfter(saved))) {
      await prefs.setString(key, newest.toIso8601String());
    }
  }
}
