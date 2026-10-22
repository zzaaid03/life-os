/// Reads and writes workout sessions and the sets logged in them.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A session holds at most 20 sets per exercise and a day at most 20 exercises.
const int _setsLimit = 400;

/// Session and set storage.
abstract class WorkoutSessionRepository {
  /// Opens a session for a plan day and returns it.
  Future<WorkoutSession> startSession({
    required String planId,
    required String dayTitle,
    required int dayPosition,
  });

  /// One session by id, or null when it does not exist.
  Future<WorkoutSession?> fetchSession(String id);

  /// The sets logged in a session, by set number.
  Future<List<LoggedSet>> fetchSets(String sessionId);

  /// Logs one set and returns the saved row.
  Future<LoggedSet> logSet({
    required String sessionId,
    required String exerciseName,
    required String kind,
    required int setNumber,
    required SetValues values,
  });

  /// Rewrites the numbers of a logged set.
  Future<LoggedSet> updateSet(String id, SetValues values);

  /// Removes a logged set.
  Future<void> deleteSet(String id);

  /// Sets `ended_at` on a session.
  Future<void> finishSession(String id);

  /// Removes a session (used for an empty one).
  Future<void> deleteSession(String id);

  /// The newest session of [planId] with at least one logged set, or null.
  Future<WorkoutSession?> fetchLastSessionWithSets(String planId);

  /// An unfinished session of [planId] started at or after [since], or null.
  Future<WorkoutSession?> fetchOpenSession(String planId, DateTime since);

  /// For each name, the sets of its most recent session, by set number.
  /// [excludeSessionId] keeps the session being worked on out of the answer.
  /// Names with no history are absent from the map.
  Future<Map<String, List<LoggedSet>>> fetchLastValues(
    List<String> names, {
    String? excludeSessionId,
  });
}

/// Supabase-backed [WorkoutSessionRepository].
class SupabaseWorkoutSessionRepository implements WorkoutSessionRepository {
  /// Creates a [SupabaseWorkoutSessionRepository].
  const SupabaseWorkoutSessionRepository(this._client);

  final SupabaseClient _client;

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  // RLS can make a write touch 0 rows without an error.
  Map<String, dynamic> _one(List<Map<String, dynamic>> rows, String what) {
    if (rows.isEmpty) throw StateError('Could not save $what: no row changed');
    return rows.first;
  }

  Map<String, dynamic> _setColumns(SetValues v) => {
    'reps': v.reps,
    'weight_kg': v.weightKg,
    'hold_seconds': v.holdSeconds,
  };

  @override
  Future<WorkoutSession> startSession({
    required String planId,
    required String dayTitle,
    required int dayPosition,
  }) async {
    final rows = await _client.from('workout_sessions').insert({
      'user_id': _userId(),
      'plan_id': planId,
      'day_title': dayTitle,
      'day_position': dayPosition,
    }).select();
    return WorkoutSession.fromJson(_one(rows, 'the workout'));
  }

  @override
  Future<WorkoutSession?> fetchSession(String id) async {
    final rows = await _client
        .from('workout_sessions')
        .select()
        .eq('id', id)
        .limit(1);
    return rows.isEmpty ? null : WorkoutSession.fromJson(rows.first);
  }

  @override
  Future<List<LoggedSet>> fetchSets(String sessionId) async {
    final rows = await _client
        .from('workout_sets')
        .select()
        .eq('session_id', sessionId)
        .order('set_number')
        .limit(_setsLimit);
    return [for (final r in rows) LoggedSet.fromJson(r)];
  }

  @override
  Future<LoggedSet> logSet({
    required String sessionId,
    required String exerciseName,
    required String kind,
    required int setNumber,
    required SetValues values,
  }) async {
    final rows = await _client.from('workout_sets').insert({
      'user_id': _userId(),
      'session_id': sessionId,
      'exercise_name': exerciseName,
      'kind': kind,
      'set_number': setNumber,
      ..._setColumns(values),
    }).select();
    return LoggedSet.fromJson(_one(rows, 'the set'));
  }

  @override
  Future<LoggedSet> updateSet(String id, SetValues values) async {
    final rows = await _client
        .from('workout_sets')
        .update(_setColumns(values))
        .eq('id', id)
        .select();
    return LoggedSet.fromJson(_one(rows, 'the set'));
  }

  @override
  Future<void> deleteSet(String id) async {
    final rows = await _client
        .from('workout_sets')
        .delete()
        .eq('id', id)
        .select('id');
    _one(rows, 'the change');
  }

  @override
  Future<void> finishSession(String id) async {
    final rows = await _client
        .from('workout_sessions')
        .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select('id');
    _one(rows, 'the workout');
  }

  @override
  Future<void> deleteSession(String id) async {
    final rows = await _client
        .from('workout_sessions')
        .delete()
        .eq('id', id)
        .select('id');
    _one(rows, 'the change');
  }

  @override
  Future<WorkoutSession?> fetchLastSessionWithSets(String planId) async {
    // The inner join keeps only sessions that have at least one set.
    final rows = await _client
        .from('workout_sessions')
        .select('*, workout_sets!inner(id)')
        .eq('plan_id', planId)
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : WorkoutSession.fromJson(rows.first);
  }

  @override
  Future<WorkoutSession?> fetchOpenSession(
    String planId,
    DateTime since,
  ) async {
    final rows = await _client
        .from('workout_sessions')
        .select()
        .eq('plan_id', planId)
        .isFilter('ended_at', null)
        .gte('started_at', since.toUtc().toIso8601String())
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : WorkoutSession.fromJson(rows.first);
  }

  @override
  Future<Map<String, List<LoggedSet>>> fetchLastValues(
    List<String> names, {
    String? excludeSessionId,
  }) async {
    if (names.isEmpty) return {};
    var query = _client
        .from('workout_sets')
        .select()
        .inFilter('exercise_name', names);
    if (excludeSessionId != null) {
      query = query.neq('session_id', excludeSessionId);
    }
    final rows = await query
        .order('logged_at', ascending: false)
        .limit(_setsLimit);
    return lastSessionSets([for (final r in rows) LoggedSet.fromJson(r)]);
  }
}

/// From sets sorted newest first, keeps for each exercise name only the sets of
/// the session that holds its newest set, ordered by set number.
Map<String, List<LoggedSet>> lastSessionSets(List<LoggedSet> newestFirst) {
  final sessionOf = <String, String>{};
  for (final s in newestFirst) {
    sessionOf.putIfAbsent(s.exerciseName, () => s.sessionId);
  }
  final out = <String, List<LoggedSet>>{};
  for (final s in newestFirst) {
    if (sessionOf[s.exerciseName] == s.sessionId) {
      out.putIfAbsent(s.exerciseName, () => []).add(s);
    }
  }
  for (final list in out.values) {
    list.sort((a, b) => a.setNumber.compareTo(b.setNumber));
  }
  return out;
}

/// Provides the [WorkoutSessionRepository].
final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>((
  ref,
) {
  return SupabaseWorkoutSessionRepository(ref.watch(supabaseClientProvider));
});
