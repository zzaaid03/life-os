/// Use case: Update a goal.
library;

import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';

/// Updates an existing goal.
class UpdateGoal {
  /// Creates an [UpdateGoal].
  const UpdateGoal(this._repository);
  final GoalRepository _repository;

  /// Executes the use case.
  Future<Goal> call(Goal goal) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.update(goal);
  }
}
