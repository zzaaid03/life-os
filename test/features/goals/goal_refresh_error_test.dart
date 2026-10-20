import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

class _FakeGoalRepository extends Fake implements GoalRepository {
  bool fail = false;

  @override
  Future<List<Goal>> getAll(String userId) async {
    if (fail) throw StateError('offline');
    return [
      Goal(
        id: 'g1',
        userId: userId,
        title: 'Run a 10k',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
  }
}

class _FakeTaskRepository extends Fake implements TaskRepository {}

void main() {
  test('a failed refresh keeps the goals and sets an error', () async {
    final repo = _FakeGoalRepository();
    final notifier = GoalListNotifier(repo, _FakeTaskRepository());

    await notifier.load('user-1');
    expect(notifier.state.goals, hasLength(1));
    expect(notifier.state.error, isNull);

    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.status, GoalListStatus.loaded);
    expect(notifier.state.goals, hasLength(1));
    expect(
      notifier.state.error,
      "Couldn't refresh your goals. Check your connection and try again.",
    );
  });

  test('a later successful refresh clears the error', () async {
    final repo = _FakeGoalRepository();
    final notifier = GoalListNotifier(repo, _FakeTaskRepository());
    await notifier.load('user-1');
    repo.fail = true;
    await notifier.refresh();
    repo.fail = false;
    await notifier.refresh();

    expect(notifier.state.error, isNull);
  });
}
