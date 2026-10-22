/// State for the active workout plan.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/fitness/data/workout_plan_repository.dart';
import 'package:life_os/features/fitness/domain/plan_inputs.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:riverpod/riverpod.dart';

/// State of the active plan. [plan] null with no error means "no plan yet".
class WorkoutPlanState {
  /// Creates a [WorkoutPlanState].
  const WorkoutPlanState({
    this.loaded = false,
    this.loadFailed = false,
    this.plan,
  });

  /// Whether the first load finished (successfully or not).
  final bool loaded;

  /// True when the load failed, so a null [plan] means "unknown", not "none".
  final bool loadFailed;
  final WorkoutPlan? plan;
}

/// Loads the active plan and generates new ones.
class WorkoutPlanNotifier extends StateNotifier<WorkoutPlanState> {
  /// Creates a [WorkoutPlanNotifier].
  WorkoutPlanNotifier(this._repository) : super(const WorkoutPlanState());

  final WorkoutPlanRepository _repository;

  /// Loads the active plan. A failure keeps any plan already shown.
  Future<void> load([String? userId]) async {
    try {
      final plan = await _repository.fetchActivePlan();
      state = WorkoutPlanState(loaded: true, plan: plan);
    } catch (e) {
      debugPrint('Workout plan load failed: $e');
      state = WorkoutPlanState(
        loaded: true,
        loadFailed: true,
        plan: state.plan,
      );
    }
  }

  /// Builds a plan from [inputs], then reloads. Throws on failure so the
  /// screen can say so; [DailyLimitReached] means the daily cap.
  Future<void> generate(PlanInputs inputs) async {
    await _repository.generate(inputs);
    await load();
  }
}

/// Provides the [WorkoutPlanNotifier].
final workoutPlanProvider =
    StateNotifierProvider<WorkoutPlanNotifier, WorkoutPlanState>((ref) {
      final notifier = WorkoutPlanNotifier(
        ref.watch(workoutPlanRepositoryProvider),
      );
      autoLoadOnSignIn(ref, notifier.load);
      return notifier;
    });
