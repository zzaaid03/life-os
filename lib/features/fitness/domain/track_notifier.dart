/// Drives the track-mode screen: loading a session, logging sets, leaving.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/fitness/data/workout_session_repository.dart';
import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/track_state.dart';
import 'package:life_os/features/fitness/domain/workout_checkin_providers.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:life_os/features/fitness/domain/workout_session_providers.dart';
import 'package:riverpod/riverpod.dart';

/// How a workout ended.
enum WorkoutExit {
  /// No set was logged, so the empty session was deleted.
  discarded,

  /// The session was closed and today was marked as trained.
  saved,

  /// The session was closed but the daily check-in could not be saved.
  savedCheckinFailed,
}

/// Loads one session and writes its sets.
class TrackNotifier extends StateNotifier<TrackState> {
  /// Creates a [TrackNotifier]. [readPlan] gives the active plan,
  /// [markTrained] saves today's check-in and [onChanged] refreshes the hub.
  TrackNotifier({
    required this.repository,
    required this.sessionId,
    required this.readPlan,
    required this.markTrained,
    required this.onChanged,
  }) : super(const TrackState());

  final String sessionId;
  final WorkoutSessionRepository repository;
  final WorkoutPlan? Function() readPlan;
  final Future<void> Function() markTrained;
  final Future<void> Function() onChanged;
  int _keys = 0;

  String _key(String prefix) => '$prefix-${_keys++}';

  /// Loads the session, its logged sets and last time's numbers.
  Future<void> load() async {
    try {
      final session = await repository.fetchSession(sessionId);
      if (session == null) {
        state = const TrackState(
          loading: false,
          error: 'This workout was not found.',
        );
        return;
      }
      final logged = await repository.fetchSets(sessionId);
      final day = _dayFor(session);
      final planned = day?.exercises ?? const <PlanExercise>[];
      final names = <String>{
        for (final e in planned) e.name,
        for (final s in logged) s.exerciseName,
      }.toList();
      var historyFailed = false;
      var history = <String, List<LoggedSet>>{};
      try {
        history = await repository.fetchLastValues(
          names,
          excludeSessionId: sessionId,
        );
      } catch (e) {
        debugPrint('Workout history load failed: $e');
        historyFailed = true;
      }
      if (!mounted) return;
      state = TrackState(
        loading: false,
        session: session,
        exercises: _build(planned, logged, history),
        historyFailed: historyFailed,
      );
    } catch (e) {
      debugPrint('Workout load failed: $e');
      if (!mounted) return;
      state = const TrackState(
        loading: false,
        error: "Couldn't load this workout.",
      );
    }
  }

  PlanDay? _dayFor(WorkoutSession session) {
    for (final d in readPlan()?.days ?? const <PlanDay>[]) {
      if (d.position == session.dayPosition) return d;
    }
    return null;
  }

  List<TrackExercise> _build(
    List<PlanExercise> planned,
    List<LoggedSet> logged,
    Map<String, List<LoggedSet>> history,
  ) {
    final out = <TrackExercise>[];
    final planNames = {for (final e in planned) e.name};
    for (final e in planned) {
      out.add(
        _exercise(
          name: e.name,
          kind: e.kind == 'time' ? 'time' : 'reps',
          count: e.sets,
          logged: [
            for (final s in logged)
              if (s.exerciseName == e.name) s,
          ],
          history: history[e.name] ?? const [],
          planReps: e.repsMin,
          planHold: e.holdSeconds,
          extra: false,
        ),
      );
    }
    // Exercises added during an earlier visit to this session.
    final extraNames = <String>[];
    for (final s in logged) {
      if (!planNames.contains(s.exerciseName) &&
          !extraNames.contains(s.exerciseName)) {
        extraNames.add(s.exerciseName);
      }
    }
    for (final name in extraNames) {
      final mine = [
        for (final s in logged)
          if (s.exerciseName == name) s,
      ];
      out.add(
        _exercise(
          name: name,
          kind: mine.first.kind,
          count: 0,
          logged: mine,
          history: history[name] ?? const [],
          extra: true,
        ),
      );
    }
    return out;
  }

  TrackExercise _exercise({
    required String name,
    required String kind,
    required int count,
    required List<LoggedSet> logged,
    required List<LoggedSet> history,
    required bool extra,
    int? planReps,
    int? planHold,
  }) {
    var rowCount = count;
    for (final s in logged) {
      if (s.setNumber > rowCount) rowCount = s.setNumber;
    }
    rowCount = rowCount.clamp(1, kMaxSetsPerExercise);
    final rows = <TrackRow>[];
    for (var i = 0; i < rowCount; i++) {
      LoggedSet? mine;
      for (final s in logged) {
        if (s.setNumber == i + 1) mine = s;
      }
      final values = mine != null
          ? SetValues(
              reps: mine.reps,
              weightKg: mine.weightKg,
              holdSeconds: mine.holdSeconds,
            )
          : prefillSet(
              kind: kind,
              index: i,
              history: history,
              planReps: planReps,
              planHold: planHold,
            );
      rows.add(
        TrackRow(
          key: _key('row'),
          setNumber: i + 1,
          initial: values,
          logged: mine,
        ),
      );
    }
    return TrackExercise(
      key: _key('ex'),
      name: name,
      kind: kind,
      rows: rows,
      extra: extra,
    );
  }

  // Replaces one row of one exercise.
  void _putRow(int exercise, int row, TrackRow next) {
    final list = [...state.exercises];
    final rows = [...list[exercise].rows];
    rows[row] = next;
    list[exercise] = list[exercise].copyWith(rows: rows);
    state = state.copyWith(exercises: list);
  }

  /// Logs the set in a row. The row shows as logged only after the insert
  /// worked. Throws on failure, leaving the row unlogged.
  Future<void> logRow(int exercise, int row, SetValues values) async {
    final ex = state.exercises[exercise];
    final current = ex.rows[row];
    if (current.saving) return;
    _putRow(exercise, row, current.copyWith(saving: true));
    try {
      final saved = await repository.logSet(
        sessionId: sessionId,
        exerciseName: ex.name,
        kind: ex.kind,
        setNumber: current.setNumber,
        values: values,
      );
      if (!mounted) return;
      _putRow(
        exercise,
        row,
        current.copyWith(initial: values, logged: saved, saving: false),
      );
    } catch (e) {
      debugPrint('Workout set log failed: $e');
      if (mounted) _putRow(exercise, row, current.copyWith(saving: false));
      rethrow;
    }
  }

  /// Changes the numbers of an already logged set. Throws on failure.
  Future<void> updateRow(int exercise, int row, SetValues values) async {
    final current = state.exercises[exercise].rows[row];
    final logged = current.logged;
    if (logged == null || current.saving) return;
    _putRow(exercise, row, current.copyWith(saving: true));
    try {
      final saved = await repository.updateSet(logged.id, values);
      if (!mounted) return;
      _putRow(
        exercise,
        row,
        current.copyWith(initial: values, logged: saved, saving: false),
      );
    } catch (e) {
      debugPrint('Workout set update failed: $e');
      if (mounted) _putRow(exercise, row, current.copyWith(saving: false));
      rethrow;
    }
  }

  /// Deletes the logged set; the row stays so set numbers keep their place.
  /// Throws on failure.
  Future<void> removeLog(int exercise, int row) async {
    final current = state.exercises[exercise].rows[row];
    final logged = current.logged;
    if (logged == null || current.saving) return;
    _putRow(exercise, row, current.copyWith(saving: true));
    try {
      await repository.deleteSet(logged.id);
      if (!mounted) return;
      _putRow(
        exercise,
        row,
        current.copyWith(clearLogged: true, saving: false),
      );
    } catch (e) {
      debugPrint('Workout set delete failed: $e');
      if (mounted) _putRow(exercise, row, current.copyWith(saving: false));
      rethrow;
    }
  }

  /// Adds an empty row to an exercise, up to [kMaxSetsPerExercise].
  void addRow(int exercise) {
    final ex = state.exercises[exercise];
    if (ex.rows.length >= kMaxSetsPerExercise) return;
    final last = ex.rows.last.initial;
    final list = [...state.exercises];
    list[exercise] = ex.copyWith(
      rows: [
        ...ex.rows,
        TrackRow(
          key: _key('row'),
          setNumber: ex.rows.length + 1,
          initial: SetValues(
            reps: last.reps,
            weightKg: last.weightKg,
            holdSeconds: last.holdSeconds,
          ),
        ),
      ],
    );
    state = state.copyWith(exercises: list);
  }

  /// Adds an exercise for today only; it never touches the plan.
  Future<void> addExercise(String name, String kind) async {
    var history = const <LoggedSet>[];
    var failed = state.historyFailed;
    try {
      final found = await repository.fetchLastValues([
        name,
      ], excludeSessionId: sessionId);
      history = found[name] ?? const [];
    } catch (e) {
      debugPrint('Workout history load failed: $e');
      failed = true;
    }
    if (!mounted) return;
    final ex = _exercise(
      name: name,
      kind: kind,
      count: history.isEmpty ? 3 : history.length,
      logged: const [],
      history: history,
      extra: true,
    );
    state = state.copyWith(
      exercises: [...state.exercises, ex],
      index: state.exercises.length,
      historyFailed: failed,
    );
  }

  /// Shows the exercise at [index].
  void goTo(int index) {
    if (index < 0 || index >= state.exercises.length) return;
    state = state.copyWith(index: index);
  }

  /// Marks the current exercise as skipped and moves on.
  void skipCurrent() {
    final i = state.index;
    if (i >= state.exercises.length - 1) return;
    final list = [...state.exercises];
    list[i] = list[i].copyWith(skipped: true);
    state = state.copyWith(exercises: list, index: i + 1);
  }

  /// Ends the workout (finish button or X). With no logged set the empty
  /// session is deleted; with one or more it is closed and today counts as
  /// trained. Throws when the session itself could not be written, so the
  /// screen stays open.
  Future<WorkoutExit> leave() async {
    if (state.loggedCount == 0) {
      await repository.deleteSession(sessionId);
      await _refreshHub();
      return WorkoutExit.discarded;
    }
    await repository.finishSession(sessionId);
    var exit = WorkoutExit.saved;
    try {
      await markTrained();
    } catch (e) {
      debugPrint('Workout check-in save failed: $e');
      exit = WorkoutExit.savedCheckinFailed;
    }
    await _refreshHub();
    return exit;
  }

  Future<void> _refreshHub() async {
    try {
      await onChanged();
    } catch (e) {
      debugPrint('Workout hub refresh failed: $e');
    }
  }
}

/// Provides a [TrackNotifier] per session id.
final trackProvider = StateNotifierProvider.autoDispose
    .family<TrackNotifier, TrackState, String>((ref, sessionId) {
      final notifier = TrackNotifier(
        repository: ref.watch(workoutSessionRepositoryProvider),
        sessionId: sessionId,
        readPlan: () => ref.read(workoutPlanProvider).plan,
        markTrained: () =>
            ref.read(workoutCheckinProvider.notifier).markTrainedToday(),
        onChanged: () => ref.read(workoutSessionsProvider.notifier).load(),
      );
      Future.microtask(notifier.load);
      return notifier;
    });
