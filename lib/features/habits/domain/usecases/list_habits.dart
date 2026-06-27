/// Use case: List all habits for a user.
library;

import 'package:life_os/features/habits/data/models/habit.dart';
import 'package:life_os/features/habits/data/repositories/habit_repository.dart';

/// Fetches all habits for a given user.
class ListHabits {
  /// Creates a [ListHabits].
  const ListHabits(this._repository);
  final HabitRepository _repository;

  /// Executes the use case.
  Future<List<Habit>> call(String userId) {
    // TODO: Add filtering, sorting, and pagination.
    return _repository.getAll(userId);
  }
}
