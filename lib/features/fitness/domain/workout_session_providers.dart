/// State for the hub: the last trained day and any workout left open today.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/fitness/data/workout_session_repository.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:riverpod/riverpod.dart';

/// Sessions of the active plan. A failed load is [loadFailed], never an empty
/// answer, so the rotation cannot fall back to Day A by accident.
class WorkoutSessionsState {
  /// Creates a [WorkoutSessionsState].
  const WorkoutSessionsState({
    this.loaded = false,
    this.loadFailed = false,
    this.lastSession,
    this.openToday,
  });

  /// Whether the first load finished (successfully or not).
  final bool loaded;

  /// True when the load failed, so the other fields are unknown.
  final bool loadFailed;

  /// The newest session with at least one logged set, driving "next up".
  final WorkoutSession? lastSession;

  /// An unfinished session started today, offered as "Resume workout".
  final WorkoutSession? openToday;
}

/// Loads session state for one plan and starts new sessions.
class WorkoutSessionsNotifier extends StateNotifier<WorkoutSessionsState> {
  /// Creates a [WorkoutSessionsNotifier] for [planId] (null: no plan yet).
  /// [now] is for tests.
  WorkoutSessionsNotifier(
    this._repository,
    this._planId, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const WorkoutSessionsState());

  final WorkoutSessionRepository _repository;
  final String? _planId;
  final DateTime Function() _now;

  /// Loads the last trained session and today's open one. A failure keeps
  /// what was shown and flags [WorkoutSessionsState.loadFailed].
  Future<void> load([String? userId]) async {
    final planId = _planId;
    if (planId == null) {
      state = const WorkoutSessionsState(loaded: true);
      return;
    }
    final n = _now();
    final startOfToday = DateTime(n.year, n.month, n.day);
    try {
      final last = await _repository.fetchLastSessionWithSets(planId);
      final open = await _repository.fetchOpenSession(planId, startOfToday);
      if (!mounted) return;
      state = WorkoutSessionsState(
        loaded: true,
        lastSession: last,
        openToday: open,
      );
    } catch (e) {
      debugPrint('Workout sessions load failed: $e');
      if (!mounted) return;
      state = WorkoutSessionsState(
        loaded: true,
        loadFailed: true,
        lastSession: state.lastSession,
        openToday: state.openToday,
      );
    }
  }

  /// Opens a session for [day] and returns its id. Throws on failure.
  Future<String> startWorkout(WorkoutPlan plan, PlanDay day) async {
    final session = await _repository.startSession(
      planId: plan.id,
      dayTitle: day.title,
      dayPosition: day.position,
    );
    if (mounted) {
      state = WorkoutSessionsState(
        loaded: true,
        lastSession: state.lastSession,
        openToday: session,
      );
    }
    return session.id;
  }
}

/// Provides the [WorkoutSessionsNotifier]. It is rebuilt (and reloads) when
/// the active plan changes.
final workoutSessionsProvider =
    StateNotifierProvider<WorkoutSessionsNotifier, WorkoutSessionsState>((ref) {
      final planId = ref.watch(workoutPlanProvider.select((s) => s.plan?.id));
      final notifier = WorkoutSessionsNotifier(
        ref.watch(workoutSessionRepositoryProvider),
        planId,
      );
      Future.microtask(notifier.load);
      return notifier;
    });
