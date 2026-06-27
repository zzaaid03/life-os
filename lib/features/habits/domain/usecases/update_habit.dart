/// Use case: Update a habit.
library;

import 'package:life_os/features/habits/data/models/habit.dart';
import 'package:life_os/features/habits/data/repositories/habit_repository.dart';

/// Updates an existing habit.
class UpdateHabit {
  /// Creates an [UpdateHabit].
  const UpdateHabit(this._repository);
  final HabitRepository _repository;

  /// Executes the use case.
  Future<Habit> call(Habit habit) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.update(habit);
  }
}
