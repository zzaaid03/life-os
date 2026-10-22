/// Reads the saved workout plan and asks the `workout-plan` function for a new one.
library;

import 'package:life_os/core/services/supabase_service.dart';
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
}

/// Provides the [WorkoutPlanRepository].
final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>((ref) {
  return SupabaseWorkoutPlanRepository(ref.watch(supabaseClientProvider));
});
