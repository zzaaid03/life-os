/// Habit repository interface.
library;

import 'package:life_os/features/habits/data/models/habit.dart';

/// Abstract repository for Habit operations.
abstract class HabitRepository {
  /// Fetches a single habit by [id].
  Future<Habit?> getById(String id);

  /// Fetches all habits for the given [userId].
  Future<List<Habit>> getAll(String userId);

  /// Creates a new habit.
  Future<Habit> create(Habit habit);

  /// Updates an existing habit.
  Future<Habit> update(Habit habit);

  /// Soft-deletes a habit by [id].
  Future<void> delete(String id);

  /// Hard-deletes a habit by [id] (permanent removal).
  Future<void> purge(String id);
}
