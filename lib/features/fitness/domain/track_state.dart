/// State of the track-mode screen: exercises, their set rows, and what is logged.
library;

import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';

/// One set row. [logged] is set only after the insert succeeded.
class TrackRow {
  /// Creates a [TrackRow].
  const TrackRow({
    required this.key,
    required this.setNumber,
    required this.initial,
    this.logged,
    this.saving = false,
  });

  /// Stable id for widget state.
  final String key;

  /// 1-based number stored with the set.
  final int setNumber;

  /// The prefilled (or last edited) numbers for the fields.
  final SetValues initial;
  final LoggedSet? logged;

  /// True while a write for this row is in flight.
  final bool saving;

  TrackRow copyWith({
    SetValues? initial,
    LoggedSet? logged,
    bool? saving,
    bool clearLogged = false,
  }) {
    return TrackRow(
      key: key,
      setNumber: setNumber,
      initial: initial ?? this.initial,
      logged: clearLogged ? null : (logged ?? this.logged),
      saving: saving ?? this.saving,
    );
  }
}

/// One exercise of the session. [extra] ones were added today and are not in
/// the plan.
class TrackExercise {
  /// Creates a [TrackExercise].
  const TrackExercise({
    required this.key,
    required this.name,
    required this.kind,
    required this.rows,
    this.extra = false,
    this.skipped = false,
  });

  final String key;
  final String name;

  /// `reps` or `time`.
  final String kind;
  final List<TrackRow> rows;
  final bool extra;
  final bool skipped;

  int get loggedCount => rows.where((r) => r.logged != null).length;

  TrackExercise copyWith({List<TrackRow>? rows, bool? skipped}) {
    return TrackExercise(
      key: key,
      name: name,
      kind: kind,
      rows: rows ?? this.rows,
      extra: extra,
      skipped: skipped ?? this.skipped,
    );
  }
}

/// The whole screen state. [error] set means the load failed.
class TrackState {
  /// Creates a [TrackState].
  const TrackState({
    this.loading = true,
    this.error,
    this.session,
    this.exercises = const [],
    this.index = 0,
    this.historyFailed = false,
  });

  final bool loading;
  final String? error;
  final WorkoutSession? session;
  final List<TrackExercise> exercises;

  /// The exercise on screen.
  final int index;

  /// True when last time's numbers could not be loaded, so the rows hold the
  /// plan's numbers instead.
  final bool historyFailed;

  int get loggedCount => exercises.fold(0, (sum, e) => sum + e.loggedCount);

  TrackState copyWith({
    List<TrackExercise>? exercises,
    int? index,
    bool? historyFailed,
  }) {
    return TrackState(
      loading: loading,
      error: error,
      session: session,
      exercises: exercises ?? this.exercises,
      index: index ?? this.index,
      historyFailed: historyFailed ?? this.historyFailed,
    );
  }
}
