/// Read-only history queries for the weekly review.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/fitness/domain/personal_best.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A week never comes close to this many sets.
const int _windowSetsLimit = 1000;

// Most exercises we look up a prior best for.
const int _maxExercises = 20;

/// The sets of one window and the best set before it for each exercise.
class WorkoutWindow {
  /// Creates a [WorkoutWindow].
  const WorkoutWindow({required this.sets, required this.priorBests});

  /// Sets logged inside the window, oldest first.
  final List<LoggedSet> sets;

  /// Best earlier set by [setGroupKey]. An exercise with no earlier set (or
  /// past the cap) is absent.
  final Map<String, LoggedSet> priorBests;
}

/// Reads logged sets for reporting.
abstract class WorkoutHistoryRepository {
  /// Sets logged in `[startUtc, endUtc)` plus each exercise's prior best.
  Future<WorkoutWindow> fetchWindow(DateTime startUtc, DateTime endUtc);
}

/// Supabase-backed [WorkoutHistoryRepository].
class SupabaseWorkoutHistoryRepository implements WorkoutHistoryRepository {
  /// Creates a [SupabaseWorkoutHistoryRepository].
  const SupabaseWorkoutHistoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WorkoutWindow> fetchWindow(DateTime startUtc, DateTime endUtc) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');

    final rows = await _client
        .from('workout_sets')
        .select('*, workout_sessions(day_title, started_at)')
        .eq('user_id', userId)
        .gte('logged_at', startUtc.toUtc().toIso8601String())
        .lt('logged_at', endUtc.toUtc().toIso8601String())
        .order('logged_at')
        .limit(_windowSetsLimit);
    final sets = [for (final r in rows) LoggedSet.fromJson(r)];

    final groups = <String, LoggedSet>{};
    for (final s in sets) {
      groups.putIfAbsent(setGroupKey(s.exerciseName, s.kind), () => s);
    }
    final picked = groups.values.take(_maxExercises).toList();
    final priors = await Future.wait([
      for (final s in picked) _priorBest(userId, s, startUtc),
    ]);
    final priorBests = <String, LoggedSet>{};
    for (var i = 0; i < picked.length; i++) {
      final prior = priors[i];
      if (prior != null) {
        priorBests[setGroupKey(picked[i].exerciseName, picked[i].kind)] = prior;
      }
    }
    return WorkoutWindow(sets: sets, priorBests: priorBests);
  }

  Future<LoggedSet?> _priorBest(
    String userId,
    LoggedSet like,
    DateTime beforeUtc,
  ) async {
    final query = _client
        .from('workout_sets')
        .select()
        .eq('user_id', userId)
        .eq('exercise_name', like.exerciseName)
        .eq('kind', like.kind)
        .lt('logged_at', beforeUtc.toUtc().toIso8601String());
    final ordered = like.kind == 'time'
        ? query.order('hold_seconds', ascending: false, nullsFirst: false)
        : query
              .order('weight_kg', ascending: false, nullsFirst: false)
              .order('reps', ascending: false, nullsFirst: false);
    final rows = await ordered.limit(1);
    return rows.isEmpty ? null : LoggedSet.fromJson(rows.first);
  }
}

/// Provides the [WorkoutHistoryRepository].
final workoutHistoryRepositoryProvider = Provider<WorkoutHistoryRepository>((
  ref,
) {
  return SupabaseWorkoutHistoryRepository(ref.watch(supabaseClientProvider));
});
