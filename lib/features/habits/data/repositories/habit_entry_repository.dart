/// Habit Entry repository interface.
library;

import 'package:life_os/features/habits/data/models/habit_entry.dart';

/// Abstract repository for HabitEntry operations.
abstract class HabitEntryRepository {
  /// Fetches a single habit entry by [id].
  Future<HabitEntry?> getById(String id);

  /// Fetches all entries for the given [habitId].
  Future<List<HabitEntry>> getByHabit(String habitId);

  /// Fetches entries for a habit within a date range.
  Future<List<HabitEntry>> getByDateRange(
    String habitId,
    DateTime start,
    DateTime end,
  );

  /// Creates a new habit entry.
  Future<HabitEntry> create(HabitEntry entry);

  /// Updates an existing habit entry.
  Future<HabitEntry> update(HabitEntry entry);

  /// Soft-deletes a habit entry by [id].
  Future<void> delete(String id);

  /// Hard-deletes a habit entry by [id] (permanent removal).
  Future<void> purge(String id);
}
