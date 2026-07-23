/// In-memory demo repository for [Goal]s.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';

/// Stateful in-memory [GoalRepository] backing the sandbox demo mode.
class DemoGoalRepository implements GoalRepository {
  /// Creates a [DemoGoalRepository] seeded with demo data.
  DemoGoalRepository() : _goals = buildDemoGoals();

  final List<Goal> _goals;

  @override
  Future<Goal?> getById(String id) async {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  @override
  Future<List<Goal>> getAll(String userId) async {
    return _goals
        .where((g) => g.userId == userId && g.deletedAt == null)
        .toList();
  }

  @override
  Future<Goal> create(Goal goal) async {
    _goals.add(goal);
    return goal;
  }

  @override
  Future<Goal> update(Goal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
    }
    return goal;
  }

  @override
  Future<void> delete(String id) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(deletedAt: DateTime.now());
    }
  }

  @override
  Future<void> purge(String id) async {
    _goals.removeWhere((g) => g.id == id);
  }
}
