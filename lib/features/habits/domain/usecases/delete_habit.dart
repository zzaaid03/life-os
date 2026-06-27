/// Use case: Delete a habit.
library;

import 'package:life_os/features/habits/data/repositories/habit_repository.dart';

/// Soft-deletes a habit.
class DeleteHabit {
  /// Creates a [DeleteHabit].
  const DeleteHabit(this._repository);
  final HabitRepository _repository;

  /// Executes the use case.
  Future<void> call(String id) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.delete(id);
  }
}
