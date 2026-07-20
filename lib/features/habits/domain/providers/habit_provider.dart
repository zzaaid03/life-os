/// Riverpod providers for the habits feature.
///
/// Loads the user's habits together with ~90 days of check-off entries in
/// one pass, computes each habit's current streak and whether it's done
/// today, and exposes check/uncheck + CRUD operations.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/habits/data/models/habit.dart';
import 'package:life_os/features/habits/data/models/habit_entry.dart';
import 'package:life_os/features/habits/data/repositories/supabase_habit_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

/// How far back entries are fetched for streak computation.
const int _kStreakWindowDays = 90;

/// A habit combined with its derived daily state.
class HabitView {
  /// Creates a [HabitView].
  const HabitView({
    required this.habit,
    required this.doneToday,
    required this.streak,
    this.todayEntryId,
  });

  /// The underlying habit.
  final Habit habit;

  /// Whether it has a check-off entry for today.
  final bool doneToday;

  /// Current streak in days (consecutive days ending today, or yesterday
  /// if today isn't checked yet).
  final int streak;

  /// The id of today's entry, when [doneToday].
  final String? todayEntryId;
}

/// The loading status of the habit list.
enum HabitListStatus { loading, loaded, error }

/// State managed by [HabitListNotifier].
class HabitListState {
  /// Creates a [HabitListState].
  const HabitListState({
    this.status = HabitListStatus.loading,
    this.habits = const <HabitView>[],
    this.error,
  });

  /// The current loading status.
  final HabitListStatus status;

  /// The habits with their derived daily state.
  final List<HabitView> habits;

  /// An error message, if loading failed.
  final String? error;
}

/// Loads and mutates the user's habits and their check-offs.
class HabitListNotifier extends StateNotifier<HabitListState> {
  /// Creates a [HabitListNotifier].
  HabitListNotifier(this._habits, this._entries)
    : super(const HabitListState());

  final SupabaseHabitRepository _habits;
  final SupabaseHabitEntryRepository _entries;

  String? _userId;

  /// Loads habits + recent entries and derives streaks.
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.habits.isEmpty) {
      state = const HabitListState(status: HabitListStatus.loading);
    }
    try {
      final since = DateTime.now().subtract(
        const Duration(days: _kStreakWindowDays),
      );
      final habits = await _habits.getAll(userId);
      final entries = await _entries.getRecentForUser(userId, since);

      // Group entry dates per habit for O(1) lookups.
      final datesByHabit = <String, Map<String, String>>{};
      for (final entry in entries) {
        final dateKey = _dateKey(entry.completedDate);
        datesByHabit.putIfAbsent(entry.habitId, () => {})[dateKey] = entry.id;
      }

      final views = habits.map((habit) {
        final dates = datesByHabit[habit.id] ?? const <String, String>{};
        final todayKey = _dateKey(DateTime.now());
        final doneToday = dates.containsKey(todayKey);
        return HabitView(
          habit: habit,
          doneToday: doneToday,
          streak: _currentStreak(dates.keys.toSet()),
          todayEntryId: dates[todayKey],
        );
      }).toList();

      state = HabitListState(status: HabitListStatus.loaded, habits: views);
    } catch (e) {
      if (state.habits.isNotEmpty) {
        state = HabitListState(
          status: HabitListStatus.loaded,
          habits: state.habits,
        );
      } else {
        state = const HabitListState(
          status: HabitListStatus.error,
          error: 'Failed to load habits.',
        );
      }
    }
  }

  /// Reloads for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  /// Creates a habit with [name] and optional [description].
  Future<void> createHabit({required String name, String? description}) async {
    final userId = _userId;
    if (userId == null) return;
    final now = DateTime.now();
    await _habits.create(
      Habit(
        id: const Uuid().v4(),
        userId: userId,
        name: name,
        description: description,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
  }

  /// Updates a habit's fields.
  Future<void> updateHabit(Habit habit) async {
    await _habits.update(habit.copyWith(updatedAt: DateTime.now()));
    await refresh();
  }

  /// Soft-deletes a habit (its entries remain but are no longer shown).
  Future<void> deleteHabit(String id) async {
    await _habits.delete(id);
    await refresh();
  }

  /// Toggles today's check-off for [view]'s habit.
  Future<void> toggleToday(HabitView view) async {
    final userId = _userId;
    if (userId == null) return;

    if (view.doneToday && view.todayEntryId != null) {
      await _entries.delete(view.todayEntryId!);
    } else {
      final now = DateTime.now();
      await _entries.create(
        HabitEntry(
          id: const Uuid().v4(),
          userId: userId,
          habitId: view.habit.id,
          completedDate: DateTime(now.year, now.month, now.day),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await refresh();
  }

  /// Computes the current streak from a set of `yyyy-mm-dd` date keys.
  ///
  /// Counts back from today; if today isn't checked yet the streak may
  /// still be alive ending yesterday, so counting starts there instead.
  static int _currentStreak(Set<String> dateKeys) {
    if (dateKeys.isEmpty) return 0;

    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!dateKeys.contains(_dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (dateKeys.contains(_dateKey(day))) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

/// Provides the [HabitListNotifier] and its [HabitListState].
final habitListProvider =
    StateNotifierProvider<HabitListNotifier, HabitListState>((ref) {
      final habits = ref.watch(habitRepositoryProvider);
      final entries = ref.watch(habitEntryRepositoryProvider);
      final notifier = HabitListNotifier(
        habits as SupabaseHabitRepository,
        entries,
      );

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold-start: load eagerly if the session was already restored.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });
