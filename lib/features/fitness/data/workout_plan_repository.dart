/// Reads the saved workout plan and asks the `workout-plan` function for a new one.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/fitness/domain/exercise_draft.dart';
import 'package:life_os/features/fitness/domain/plan_inputs.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when the user already built the maximum plans today.
class DailyLimitReached implements Exception {
  /// Creates a [DailyLimitReached].
  const DailyLimitReached();

  @override
  String toString() => 'DailyLimitReached';
}

/// Plan storage and generation.
abstract class WorkoutPlanRepository {
  /// The active plan, or null when the user has none. Throws on failure.
  Future<WorkoutPlan?> fetchActivePlan();

  /// Builds and saves a plan, returning its id. Throws [DailyLimitReached]
  /// on the daily cap and another error on any other failure.
  Future<String> generate(PlanInputs inputs);

  /// Adds an exercise to a day at [position]. [id] and [note] are only set
  /// when restoring a deleted exercise.
  Future<void> insertExercise({
    required String dayId,
    required int position,
    required ExerciseDraft draft,
    String? id,
    String? note,
  });

  /// Rewrites the editable fields of one exercise.
  Future<void> updateExercise(String id, ExerciseDraft draft);

  /// Hard-deletes one exercise.
  Future<void> deleteExercise(String id);

  /// Rewrites `position` to 0..n-1 following [orderedIds].
  Future<void> reorderExercises(List<String> orderedIds);

  /// Soft-deletes the plan, then removes its days and exercises.
  Future<void> deletePlan(WorkoutPlan plan);
}

/// Supabase-backed [WorkoutPlanRepository].
class SupabaseWorkoutPlanRepository implements WorkoutPlanRepository {
  /// Creates a [SupabaseWorkoutPlanRepository].
  const SupabaseWorkoutPlanRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<WorkoutPlan?> fetchActivePlan() async {
    final rows = await _client
        .from('workout_plans')
        .select('*, workout_plan_days(*, workout_plan_exercises(*))')
        .eq('is_active', true)
        .isFilter('deleted_at', null)
        .limit(1);
    if (rows.isEmpty) return null;
    return WorkoutPlan.fromJson(rows.first);
  }

  @override
  Future<String> generate(PlanInputs inputs) async {
    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke('workout-plan', body: {'inputs': inputs.toJson()})
          .timeout(const Duration(seconds: 90));
    } on FunctionException catch (e) {
      final details = e.details;
      if (e.status == 429 &&
          details is Map &&
          details['error'] == 'daily_limit') {
        throw const DailyLimitReached();
      }
      rethrow;
    }
    final data = response.data;
    final id = data is Map ? data['plan_id'] : null;
    if (id is! String || id.isEmpty) {
      throw StateError('workout-plan returned no plan_id');
    }
    return id;
  }

  @override
  Future<void> insertExercise({
    required String dayId,
    required int position,
    required ExerciseDraft draft,
    String? id,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    await _client.from('workout_plan_exercises').insert({
      'id': ?id,
      'user_id': userId,
      'day_id': dayId,
      'position': position,
      'note': note,
      ...draft.toRow(),
    });
  }

  @override
  Future<void> updateExercise(String id, ExerciseDraft draft) async {
    final rows = await _client
        .from('workout_plan_exercises')
        .update(draft.toRow())
        .eq('id', id)
        .select('id');
    _expectRow(rows, 'update exercise');
  }

  @override
  Future<void> deleteExercise(String id) async {
    final rows = await _client
        .from('workout_plan_exercises')
        .delete()
        .eq('id', id)
        .select('id');
    _expectRow(rows, 'delete exercise');
  }

  // RLS or a missing row makes a write touch 0 rows without an error, which
  // would look like success.
  static void _expectRow(List<dynamic> rows, String what) {
    if (rows.isEmpty) throw StateError('Could not $what: no row changed');
  }

  @override
  Future<void> reorderExercises(List<String> orderedIds) async {
    // There is no unique (day_id, position), so the rows can be written in
    // any order. At most 20 small updates.
    final positions = positionsFor(orderedIds);
    final results = await Future.wait([
      for (final entry in positions.entries)
        _client
            .from('workout_plan_exercises')
            .update({'position': entry.value})
            .eq('id', entry.key)
            .select('id'),
    ]);
    for (final rows in results) {
      _expectRow(rows, 'reorder exercises');
    }
  }

  @override
  Future<void> deletePlan(WorkoutPlan plan) async {
    final rows = await _client
        .from('workout_plans')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'is_active': false,
        })
        .eq('id', plan.id)
        .select('id');
    _expectRow(rows, 'delete plan');
    final dayIds = [for (final d in plan.days) d.id];
    if (dayIds.isEmpty) return;
    await _client
        .from('workout_plan_exercises')
        .delete()
        .inFilter('day_id', dayIds);
    await _client.from('workout_plan_days').delete().eq('plan_id', plan.id);
  }
}

/// Provides the [WorkoutPlanRepository].
final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>((ref) {
  return SupabaseWorkoutPlanRepository(ref.watch(supabaseClientProvider));
});
