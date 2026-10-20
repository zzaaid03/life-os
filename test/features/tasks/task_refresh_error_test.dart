import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/sync/sync_service.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';

class _FakeTaskRepository extends Fake implements TaskRepository {
  bool fail = false;

  @override
  Future<List<Task>> getAll(String userId) async {
    if (fail) throw StateError('offline');
    return [
      Task(
        id: 't1',
        userId: userId,
        title: 'Buy milk',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
  }
}

class _FakeSyncService extends Fake implements SyncService {
  @override
  Future<void> syncTasks(String userId) async {}
}

void main() {
  test('a failed refresh keeps the tasks and sets an error', () async {
    final repo = _FakeTaskRepository();
    final notifier = TaskListNotifier(repo, _FakeSyncService());

    await notifier.loadTasks('user-1');
    expect(notifier.state.tasks, hasLength(1));
    expect(notifier.state.error, isNull);

    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.status, TaskListStatus.loaded);
    expect(notifier.state.tasks, hasLength(1));
    expect(
      notifier.state.error,
      "Couldn't refresh your tasks. Check your connection and try again.",
    );
  });

  test('refresh re-reads after the first load finished', () async {
    final repo = _FakeTaskRepository();
    final notifier = TaskListNotifier(repo, _FakeSyncService());
    await notifier.loadTasks('user-1');
    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.error, isNotNull);
  });
}
