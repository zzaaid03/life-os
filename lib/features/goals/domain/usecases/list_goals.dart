/// Use case: List all goals for a user.
library;

import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';

/// Fetches all goals for a given user.
class ListGoals {
  /// Creates a [ListGoals].
  const ListGoals(this._repository);
  final GoalRepository _repository;

  /// Executes the use case.
  Future<List<Goal>> call(String userId) {
    // TODO: Add filtering, sorting, and pagination.
    return _repository.getAll(userId);
  }
}
