/// State for the active workout plan.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/fitness/data/workout_plan_repository.dart';
import 'package:life_os/features/fitness/domain/exercise_draft.dart';
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
  /// screen can say so; [DailyLimitReached] means the daily cap. After any
  /// other failure the plan is reloaded once, because a slow build can still
  /// end in a saved plan (the caller compares plan ids), then the error is
  /// rethrown.
  Future<void> generate(PlanInputs inputs) async {
    try {
      await _repository.generate(inputs);
    } on DailyLimitReached {
      rethrow;
    } catch (_) {
      await load();
      rethrow;
    }
    await load();
  }

  PlanDay? _day(String dayId) {
    final plan = state.plan;
    if (plan == null) return null;
    for (final d in plan.days) {
      if (d.id == dayId) return d;
    }
    return null;
  }

  // Shows [exercises] for a day right away, positions renumbered.
  void _showExercises(String dayId, List<PlanExercise> exercises) {
    final plan = state.plan;
    if (plan == null) return;
    state = WorkoutPlanState(
      loaded: true,
      plan: WorkoutPlan(
        id: plan.id,
        name: plan.name,
        days: [
          for (final d in plan.days)
            if (d.id == dayId)
              PlanDay(
                id: d.id,
                position: d.position,
                title: d.title,
                exercises: [
                  for (var i = 0; i < exercises.length; i++)
                    PlanExercise(
                      id: exercises[i].id,
                      position: i,
                      name: exercises[i].name,
                      kind: exercises[i].kind,
                      sets: exercises[i].sets,
                      restSeconds: exercises[i].restSeconds,
                      repsMin: exercises[i].repsMin,
                      repsMax: exercises[i].repsMax,
                      holdSeconds: exercises[i].holdSeconds,
                      note: exercises[i].note,
                    ),
                ],
              )
            else
              d,
        ],
      ),
    );
  }

  // Runs a write. On failure the plan is reloaded so the screen matches the
  // database, and the error is rethrown for the screen to report.
  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('Workout plan edit failed: $e');
      await load();
      rethrow;
    }
    await load();
  }

  /// Appends a new exercise to a day. Throws [StateError] at the 20 cap.
  Future<void> addExercise(String dayId, ExerciseDraft draft) {
    return _write(() async {
      final count = _day(dayId)?.exercises.length ?? 0;
      if (count >= kMaxExercisesPerDay) {
        throw StateError('A day holds at most $kMaxExercisesPerDay exercises');
      }
      await _repository.insertExercise(
        dayId: dayId,
        position: count,
        draft: draft,
      );
    });
  }

  /// Saves the edited fields of one exercise.
  Future<void> updateExercise(String id, ExerciseDraft draft) {
    return _write(() => _repository.updateExercise(id, draft));
  }

  /// Moves an exercise within a day and saves the new order.
  Future<void> reorderExercises(String dayId, int oldIndex, int newIndex) {
    final day = _day(dayId);
    if (day == null) return Future.value();
    final reordered = reorderItems(day.exercises, oldIndex, newIndex);
    _showExercises(dayId, reordered);
    return _write(
      () => _repository.reorderExercises([for (final e in reordered) e.id]),
    );
  }

  /// Removes an exercise: gone from the screen at once, then deleted and the
  /// rest renumbered. [restoreExercise] reverses it.
  Future<void> removeExercise(String dayId, String exerciseId) {
    final day = _day(dayId);
    if (day == null) return Future.value();
    final rest = [
      for (final e in day.exercises)
        if (e.id != exerciseId) e,
    ];
    _showExercises(dayId, rest);
    return _write(() async {
      await _repository.deleteExercise(exerciseId);
      await _repository.reorderExercises([for (final e in rest) e.id]);
    });
  }

  /// Puts a removed exercise back at [index] with its original id.
  Future<void> restoreExercise(String dayId, PlanExercise e, int index) {
    return _write(() async {
      final day = _day(dayId);
      final ids = [for (final x in day?.exercises ?? <PlanExercise>[]) x.id]
        ..removeWhere((id) => id == e.id);
      final at = index.clamp(0, ids.length);
      await _repository.insertExercise(
        dayId: dayId,
        position: at,
        draft: ExerciseDraft.fromExercise(e),
        id: e.id,
        note: e.note,
      );
      ids.insert(at, e.id);
      await _repository.reorderExercises(ids);
    });
  }

  /// Deletes the active plan. The hub then shows the no-plan state.
  Future<void> deletePlan() async {
    final plan = state.plan;
    if (plan == null) return;
    try {
      await _repository.deletePlan(plan);
    } catch (e) {
      debugPrint('Workout plan delete failed: $e');
      await load();
      rethrow;
    }
    state = const WorkoutPlanState(loaded: true);
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
