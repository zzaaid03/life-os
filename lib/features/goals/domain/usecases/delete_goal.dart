/// Use case: Delete a goal.
library;

import 'package:life_os/features/goals/data/repositories/goal_repository.dart';

/// Soft-deletes a goal.
class DeleteGoal {
  /// Creates a [DeleteGoal].
  const DeleteGoal(this._repository);
  final GoalRepository _repository;

  /// Executes the use case.
  Future<void> call(String id) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.delete(id);
  }
}
