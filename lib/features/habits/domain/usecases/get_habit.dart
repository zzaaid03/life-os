/// Use case: Get a habit by ID.
library;

import 'package:life_os/features/habits/data/models/habit.dart';
import 'package:life_os/features/habits/data/repositories/habit_repository.dart';

/// Fetches a single habit by its ID.
class GetHabit {
  /// Creates a [GetHabit].
  const GetHabit(this._repository);
  final HabitRepository _repository;

  /// Executes the use case.
  Future<Habit?> call(String id) {
    // TODO: Add caching, permission checks, and side effects.
    return _repository.getById(id);
  }
}
