/// The editable form of one plan exercise, plus the pure rules it enforces.
library;

import 'package:life_os/features/fitness/domain/workout_plan.dart';

/// The most exercises one day can hold (the table allows positions 0-19).
const int kMaxExercisesPerDay = 20;

const int _minSets = 1;
const int _maxSets = 10;
const int _minReps = 1;
const int _maxReps = 50;
const int _minHold = 5;
const int _maxHold = 300;
const int _minRest = 0;
const int _maxRest = 600;

/// Longest allowed exercise name.
const int kMaxExerciseName = 60;

/// An exercise being added or edited. Every `with*` method clamps to the
/// column limits, so a draft built through them stays inside the table checks.
class ExerciseDraft {
  /// Creates a draft. Defaults are a 3 x 8-12 reps exercise with 60s rest.
  const ExerciseDraft({
    this.name = '',
    this.kind = 'reps',
    this.sets = 3,
    this.repsMin = 8,
    this.repsMax = 12,
    this.holdSeconds,
    this.restSeconds = 60,
  });

  /// Starts a draft from a saved exercise.
  factory ExerciseDraft.fromExercise(PlanExercise e) {
    final isTime = e.kind == 'time';
    return ExerciseDraft(
      name: e.name,
      kind: isTime ? 'time' : 'reps',
      sets: e.sets.clamp(_minSets, _maxSets),
      repsMin: isTime ? null : (e.repsMin ?? 8).clamp(_minReps, _maxReps),
      repsMax: isTime ? null : (e.repsMax ?? 12).clamp(_minReps, _maxReps),
      holdSeconds: isTime
          ? (e.holdSeconds ?? 30).clamp(_minHold, _maxHold)
          : null,
      restSeconds: e.restSeconds.clamp(_minRest, _maxRest),
    );
  }

  final String name;

  /// `reps` or `time`.
  final String kind;
  final int sets;
  final int? repsMin;
  final int? repsMax;
  final int? holdSeconds;
  final int restSeconds;

  bool get isTime => kind == 'time';

  /// Same name, other fields as given.
  ExerciseDraft withName(String value) => ExerciseDraft(
    name: value,
    kind: kind,
    sets: sets,
    repsMin: repsMin,
    repsMax: repsMax,
    holdSeconds: holdSeconds,
    restSeconds: restSeconds,
  );

  /// Switches kind. The other kind's fields are cleared (the table requires
  /// a reps row to have no hold and a time row to have no reps).
  ExerciseDraft withKind(String value) {
    if (value == kind) return this;
    if (value == 'time') {
      return ExerciseDraft(
        name: name,
        kind: 'time',
        sets: sets,
        repsMin: null,
        repsMax: null,
        holdSeconds: 30,
        restSeconds: restSeconds,
      );
    }
    return ExerciseDraft(
      name: name,
      sets: sets,
      repsMin: 8,
      repsMax: 12,
      restSeconds: restSeconds,
    );
  }

  ExerciseDraft withSets(int value) =>
      _copy(sets: value.clamp(_minSets, _maxSets));

  /// Changing the low end pushes the high end up when it would cross it.
  ExerciseDraft withRepsMin(int value) {
    final lo = value.clamp(_minReps, _maxReps);
    final hi = repsMax ?? lo;
    return _copy(repsMin: lo, repsMax: hi < lo ? lo : hi);
  }

  /// Changing the high end pulls the low end down when it would cross it.
  ExerciseDraft withRepsMax(int value) {
    final hi = value.clamp(_minReps, _maxReps);
    final lo = repsMin ?? hi;
    return _copy(repsMin: lo > hi ? hi : lo, repsMax: hi);
  }

  ExerciseDraft withHold(int value) =>
      _copy(holdSeconds: value.clamp(_minHold, _maxHold));

  ExerciseDraft withRest(int value) =>
      _copy(restSeconds: value.clamp(_minRest, _maxRest));

  // Keeps the other kind's fields as they are; only used for in-kind edits.
  ExerciseDraft _copy({
    int? sets,
    int? repsMin,
    int? repsMax,
    int? holdSeconds,
    int? restSeconds,
  }) {
    return ExerciseDraft(
      name: name,
      kind: kind,
      sets: sets ?? this.sets,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax ?? this.repsMax,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  /// Whether the draft can be saved.
  bool get isValid {
    final n = name.trim();
    if (n.isEmpty || n.length > kMaxExerciseName) return false;
    if (sets < _minSets || sets > _maxSets) return false;
    if (restSeconds < _minRest || restSeconds > _maxRest) return false;
    if (isTime) {
      final h = holdSeconds;
      return h != null &&
          h >= _minHold &&
          h <= _maxHold &&
          repsMin == null &&
          repsMax == null;
    }
    final lo = repsMin;
    final hi = repsMax;
    return lo != null &&
        hi != null &&
        holdSeconds == null &&
        lo >= _minReps &&
        hi <= _maxReps &&
        lo <= hi;
  }

  /// Column values for insert and update. The unused kind's columns are sent
  /// as null so an update clears them.
  Map<String, dynamic> toRow() => {
    'name': name.trim(),
    'kind': kind,
    'sets': sets,
    'reps_min': isTime ? null : repsMin,
    'reps_max': isTime ? null : repsMax,
    'hold_seconds': isTime ? holdSeconds : null,
    'rest_seconds': restSeconds,
  };
}

/// Moves one item to its final index, as [ReorderableListView.onReorderItem]
/// reports it.
List<T> reorderItems<T>(List<T> items, int oldIndex, int newIndex) {
  final result = [...items];
  final moved = result.removeAt(oldIndex);
  result.insert(newIndex.clamp(0, result.length), moved);
  return result;
}

/// The id to position pairs for a day in its new order: 0..n-1.
Map<String, int> positionsFor(List<String> orderedIds) => {
  for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
};
