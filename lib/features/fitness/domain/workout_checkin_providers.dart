/// State for today's "did you train today?" check-in.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/fitness/data/workout_checkin_repository.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:riverpod/riverpod.dart';

/// Today's check-in. [trained] null with no error means "not answered yet".
class WorkoutCheckinState {
  /// Creates a [WorkoutCheckinState].
  const WorkoutCheckinState({
    this.loaded = false,
    this.loadFailed = false,
    this.localDate,
    this.trained,
  });

  /// Whether the first load finished (successfully or not).
  final bool loaded;

  /// True when the load failed, so a null [trained] means "unknown".
  final bool loadFailed;

  /// The local date [trained] belongs to, "YYYY-MM-DD".
  final String? localDate;

  /// The answer for [localDate], or null when not answered.
  final bool? trained;
}

/// Loads and saves today's check-in.
class WorkoutCheckinNotifier extends StateNotifier<WorkoutCheckinState> {
  /// Creates a [WorkoutCheckinNotifier]. [now] is for tests.
  WorkoutCheckinNotifier(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const WorkoutCheckinState());

  final WorkoutCheckinRepository _repository;
  final DateTime Function() _now;

  String _today() => localDateString(_now());

  /// Loads the check-in for today's local date, recomputed on every call so
  /// it rolls over at midnight. A failure keeps any answer already shown.
  Future<void> load([String? userId]) async {
    final today = _today();
    try {
      final trained = await _repository.fetch(today);
      state = WorkoutCheckinState(
        loaded: true,
        localDate: today,
        trained: trained,
      );
    } catch (e) {
      debugPrint('Workout check-in load failed: $e');
      state = WorkoutCheckinState(
        loaded: true,
        loadFailed: true,
        localDate: state.localDate,
        trained: state.trained,
      );
    }
  }

  /// Saves today's answer. On failure the state is reloaded so the screen
  /// matches the database, and the error is rethrown for the screen to report.
  Future<void> setTrained({required bool trained}) async {
    final today = _today();
    try {
      await _repository.save(today, trained: trained);
    } catch (e) {
      debugPrint('Workout check-in save failed: $e');
      await load();
      rethrow;
    }
    state = WorkoutCheckinState(
      loaded: true,
      localDate: today,
      trained: trained,
    );
  }

  /// Marks today as trained. Slice C2 calls this when a workout finishes.
  Future<void> markTrainedToday() => setTrained(trained: true);
}

/// True when the loaded answer is for today and says the user trained.
bool trainedToday(WorkoutCheckinState s, [DateTime? now]) {
  return s.trained == true &&
      s.localDate == localDateString(now ?? DateTime.now());
}

/// Provides the [WorkoutCheckinNotifier].
final workoutCheckinProvider =
    StateNotifierProvider<WorkoutCheckinNotifier, WorkoutCheckinState>((ref) {
      final notifier = WorkoutCheckinNotifier(
        ref.watch(workoutCheckinRepositoryProvider),
      );
      autoLoadOnSignIn(ref, notifier.load);
      return notifier;
    });
