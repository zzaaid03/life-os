/// Use case: Create a goal.
library;

import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';

/// Creates a new goal.
class CreateGoal {
  /// Creates a [CreateGoal].
  const CreateGoal(this._repository);
  final GoalRepository _repository;

  /// Executes the use case.
  Future<Goal> call(Goal goal) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.create(goal);
  }
}
