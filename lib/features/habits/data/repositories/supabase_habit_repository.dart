/// Supabase implementations of [HabitRepository] and [HabitEntryRepository].
///
/// Remote-only CRUD against the `habits` and `habit_entries` tables
/// (RLS-scoped per user). Habit deletes are soft; entry check-offs are
/// hard-deleted when un-checked (an entry either exists for a date or not).
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/habits/data/models/habit.dart';
import 'package:life_os/features/habits/data/models/habit_entry.dart';
import 'package:life_os/features/habits/data/repositories/habit_entry_repository.dart';
import 'package:life_os/features/habits/data/repositories/habit_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [HabitRepository].
class SupabaseHabitRepository implements HabitRepository {
  /// Creates a [SupabaseHabitRepository].
  const SupabaseHabitRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'habits';

  @override
  Future<Habit?> getById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Habit.fromJson(response);
  }

  @override
  Future<List<Habit>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('is_archived', false)
        .isFilter('deleted_at', null)
        .order('created_at');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Habit.fromJson)
        .toList();
  }

  @override
  Future<Habit> create(Habit habit) async {
    final response = await _client
        .from(_table)
        .insert(habit.toJson())
        .select()
        .single();
    return Habit.fromJson(response);
  }

  @override
  Future<Habit> update(Habit habit) async {
    final response = await _client
        .from(_table)
        .update(habit.toJson())
        .eq('id', habit.id)
        .select()
        .single();
    return Habit.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from(_table)
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  @override
  Future<void> purge(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

/// Supabase-backed [HabitEntryRepository].
class SupabaseHabitEntryRepository implements HabitEntryRepository {
  /// Creates a [SupabaseHabitEntryRepository].
  const SupabaseHabitEntryRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'habit_entries';

  @override
  Future<HabitEntry?> getById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return HabitEntry.fromJson(response);
  }

  @override
  Future<List<HabitEntry>> getByHabit(String habitId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('habit_id', habitId)
        .isFilter('deleted_at', null)
        .order('completed_date', ascending: false);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(HabitEntry.fromJson)
        .toList();
  }

  @override
  Future<List<HabitEntry>> getByDateRange(
    String habitId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('habit_id', habitId)
        .isFilter('deleted_at', null)
        .gte('completed_date', _dateOnly(start))
        .lte('completed_date', _dateOnly(end))
        .order('completed_date', ascending: false);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(HabitEntry.fromJson)
        .toList();
  }

  /// Fetches all recent entries for [userId] (across habits) since [since].
  ///
  /// One round-trip for the whole habit list — used to compute streaks.
  Future<List<HabitEntry>> getRecentForUser(
    String userId,
    DateTime since,
  ) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .gte('completed_date', _dateOnly(since))
        .order('completed_date', ascending: false);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(HabitEntry.fromJson)
        .toList();
  }

  @override
  Future<HabitEntry> create(HabitEntry entry) async {
    final response = await _client
        .from(_table)
        .insert(entry.toJson())
        .select()
        .single();
    return HabitEntry.fromJson(response);
  }

  @override
  Future<HabitEntry> update(HabitEntry entry) async {
    final response = await _client
        .from(_table)
        .update(entry.toJson())
        .eq('id', entry.id)
        .select()
        .single();
    return HabitEntry.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    // Check-off entries are removed outright when un-checked; the
    // UNIQUE(habit_id, completed_date) constraint would otherwise block
    // re-checking the same day.
    await purge(id);
  }

  @override
  Future<void> purge(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Provides the [HabitRepository].
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseHabitRepository(client);
});

/// Provides the [SupabaseHabitEntryRepository].
final habitEntryRepositoryProvider = Provider<SupabaseHabitEntryRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseHabitEntryRepository(client);
});
