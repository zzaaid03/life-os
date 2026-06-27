/// Use case: Get a goal by ID.
library;

import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';

/// Fetches a single goal by its ID.
class GetGoal {
  /// Creates a [GetGoal].
  const GetGoal(this._repository);
  final GoalRepository _repository;

  /// Executes the use case.
  Future<Goal?> call(String id) {
    // TODO: Add caching, permission checks, and side effects.
    return _repository.getById(id);
  }
}
