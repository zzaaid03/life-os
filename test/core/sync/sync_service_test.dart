import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/data/entity.dart';
import 'package:life_os/core/services/app_database.dart';
import 'package:life_os/core/sync/sync_service.dart';
import 'package:life_os/core/sync/sync_state.dart';
import 'package:life_os/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:life_os/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = 'user-1';
const _watermarkKey = 'tasks_sync_watermark_$_user';

Task _task(
  String id, {
  String title = 'Task',
  DateTime? updatedAt,
  int version = 1,
  SyncStatus syncStatus = SyncStatus.synced,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 1, 1);
  return Task(
    id: id,
    userId: _user,
    title: title,
    createdAt: at,
    updatedAt: at,
    version: version,
    syncStatus: syncStatus,
  );
}

class _FakeRemote implements TaskSyncRemote {
  final List<Task> rows = [];
  final List<String> failUpsertIds = [];
  final List<String> upserted = [];
  final List<DateTime> sinceCalls = [];
  int firstPageCalls = 0;
  int pageCalls = 0;

  /// Runs after a page is built, before it is returned (1-based call number).
  void Function(int call)? onPageServed;

  /// If set, the next upsert waits for this before returning.
  Completer<void>? upsertGate;

  /// If set, the next first-page pull waits for this before returning.
  Completer<void>? pullGate;

  @override
  Future<Task> upsert(Task task) async {
    final gate = upsertGate;
    if (gate != null) {
      upsertGate = null;
      await gate.future;
    }
    if (failUpsertIds.contains(task.id)) throw StateError('boom ${task.id}');
    upserted.add(task.id);
    return task;
  }

  @override
  Future<List<Task>> getSince(
    String userId,
    DateTime since, {
    ({DateTime updatedAt, String id})? cursor,
    required int limit,
  }) async {
    sinceCalls.add(since);
    if (cursor == null) {
      firstPageCalls++;
      final gate = pullGate;
      if (gate != null) {
        pullGate = null;
        await gate.future;
      }
    }
    final sorted = rows.toList()
      ..sort((a, b) {
        final byTime = a.updatedAt.compareTo(b.updatedAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    final page = sorted
        .where((t) {
          if (cursor == null) return !t.updatedAt.isBefore(since);
          final byTime = t.updatedAt.compareTo(cursor.updatedAt);
          return byTime > 0 || (byTime == 0 && t.id.compareTo(cursor.id) > 0);
        })
        .take(limit)
        .toList();
    pageCalls++;
    onPageServed?.call(pageCalls);
    return page;
  }
}

void main() {
  late AppDatabase db;
  late TaskLocalDataSource local;
  late _FakeRemote remote;
  late SyncStateNotifier syncState;
  late SyncService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = TaskLocalDataSource(db);
    remote = _FakeRemote();
    syncState = SyncStateNotifier();
    service = SyncService(
      localTasks: local,
      remoteTasks: remote,
      syncState: syncState,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('a pending local edit is not overwritten by a pull', () async {
    await local.insert(
      _task(
        't1',
        title: 'local edit',
        version: 2,
        syncStatus: SyncStatus.pendingPush,
      ),
    );
    // The upsert fails, so the row stays pending while the pull runs.
    remote.failUpsertIds.add('t1');
    remote.rows.add(
      _task('t1', title: 'remote', updatedAt: DateTime.utc(2030, 1, 1)),
    );

    await service.syncTasks(_user);

    final row = await local.getById('t1');
    expect(row!.title, 'local edit');
    expect(row.syncStatus, SyncStatus.pendingPush);
  });

  test('an edit made during a push stays pending afterwards', () async {
    await local.insert(
      _task('t1', title: 'first', syncStatus: SyncStatus.pendingPush),
    );
    final gate = Completer<void>();
    remote.upsertGate = gate;

    final run = service.syncTasks(_user);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // The user edits while the upsert is on the wire.
    await local.update(
      _task(
        't1',
        title: 'second',
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, 5),
        version: 2,
        syncStatus: SyncStatus.pendingPush,
      ),
    );
    gate.complete();
    await run;

    final row = await local.getById('t1');
    expect(row!.title, 'second');
    expect(row.syncStatus, SyncStatus.pendingPush);
    expect(syncState.state.pendingCount, 1);
  });

  test('1201 remote rows across 3 pages all land locally', () async {
    for (var i = 0; i < 1201; i++) {
      remote.rows.add(
        _task(
          'r$i',
          updatedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
        ),
      );
    }

    await service.syncTasks(_user);

    expect((await local.getAll(_user)).length, 1201);
    expect(remote.sinceCalls.length, 3);
    expect(syncState.state.lastError, isNull);
  });

  test(
    'a row updated between pages does not make a later page skip one',
    () async {
      for (var i = 0; i < 1201; i++) {
        remote.rows.add(
          _task(
            'r$i',
            updatedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
          ),
        );
      }
      // After page 1 is served, r0 is updated on the server and jumps to the
      // end of the ordering. With offset paging, page 2 would skip r500.
      remote.onPageServed = (call) {
        if (call != 1) return;
        remote.rows[0] = _task(
          'r0',
          title: 'edited',
          updatedAt: DateTime.utc(2027, 1, 1),
        );
      };

      await service.syncTasks(_user);

      final all = await local.getAll(_user);
      expect(all.length, 1201);
      expect(all.map((t) => t.id).toSet().length, 1201);
      expect((await local.getById('r500'))!.id, 'r500');
      expect((await local.getById('r0'))!.title, 'edited');
      expect(remote.pageCalls, 3);
      expect(syncState.state.lastError, isNull);
    },
  );

  test(
    'watermark is the max pulled updated_at; next pull starts 60s earlier',
    () async {
      final newest = DateTime.utc(2026, 5, 5, 12, 0, 30);
      remote.rows
        ..add(_task('a', updatedAt: DateTime.utc(2026, 5, 5, 12)))
        ..add(_task('b', updatedAt: newest));

      await service.syncTasks(_user);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_watermarkKey), newest.toIso8601String());
      expect(
        remote.sinceCalls.first,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      await service.syncTasks(_user);
      expect(
        remote.sinceCalls.last.toUtc(),
        newest.subtract(const Duration(seconds: 60)),
      );
    },
  );

  test('three concurrent sync calls cause exactly two runs', () async {
    final gate = Completer<void>();
    remote.pullGate = gate;

    final a = service.syncTasks(_user);
    final b = service.syncTasks(_user);
    final c = service.syncTasks(_user);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    gate.complete();
    await Future.wait([a, b, c]);

    expect(remote.firstPageCalls, 2);
  });

  test(
    'a failing push leaves that task pending, others push, error set',
    () async {
      await local.insert(_task('ok1', syncStatus: SyncStatus.pendingCreate));
      await local.insert(_task('bad', syncStatus: SyncStatus.pendingPush));
      await local.insert(_task('ok2', syncStatus: SyncStatus.pendingPush));
      remote.failUpsertIds.add('bad');

      await service.syncTasks(_user);

      expect((await local.getById('ok1'))!.syncStatus, SyncStatus.synced);
      expect((await local.getById('ok2'))!.syncStatus, SyncStatus.synced);
      expect((await local.getById('bad'))!.syncStatus, SyncStatus.pendingPush);
      expect(remote.upserted, containsAll(['ok1', 'ok2']));
      expect(syncState.state.lastError, contains('bad'));
      expect(syncState.state.lastSuccessAt, isNull);
      expect(syncState.state.pendingCount, 1);
      expect(syncState.state.isSyncing, isFalse);
    },
  );
}
