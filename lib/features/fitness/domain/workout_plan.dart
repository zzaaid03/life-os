/// Saved workout plan models and the pure helpers that format them.
library;

/// One exercise in a plan day.
class PlanExercise {
  /// Creates a [PlanExercise].
  const PlanExercise({
    required this.id,
    required this.position,
    required this.name,
    required this.kind,
    required this.sets,
    required this.restSeconds,
    this.repsMin,
    this.repsMax,
    this.holdSeconds,
    this.note,
  });

  /// Reads a row, tolerating missing or null fields.
  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    return PlanExercise(
      id: json['id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'reps',
      sets: (json['sets'] as num?)?.toInt() ?? 0,
      repsMin: (json['reps_min'] as num?)?.toInt(),
      repsMax: (json['reps_max'] as num?)?.toInt(),
      holdSeconds: (json['hold_seconds'] as num?)?.toInt(),
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
    );
  }

  final String id;
  final int position;
  final String name;

  /// `reps` or `time`.
  final String kind;
  final int sets;
  final int? repsMin;
  final int? repsMax;
  final int? holdSeconds;
  final int restSeconds;
  final String? note;
}

/// One training day of a plan.
class PlanDay {
  /// Creates a [PlanDay].
  const PlanDay({
    required this.id,
    required this.position,
    required this.title,
    required this.exercises,
  });

  /// Reads a row with its nested exercises, sorted by position.
  factory PlanDay.fromJson(Map<String, dynamic> json) {
    final raw = json['workout_plan_exercises'];
    final exercises = <PlanExercise>[
      if (raw is List)
        for (final e in raw)
          if (e is Map<String, dynamic>) PlanExercise.fromJson(e),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return PlanDay(
      id: json['id'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      exercises: exercises,
    );
  }

  final String id;
  final int position;
  final String title;
  final List<PlanExercise> exercises;
}

/// A saved plan with its days.
class WorkoutPlan {
  /// Creates a [WorkoutPlan].
  const WorkoutPlan({required this.id, required this.name, required this.days});

  /// Reads a row with nested days, sorted by position.
  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final raw = json['workout_plan_days'];
    final days = <PlanDay>[
      if (raw is List)
        for (final d in raw)
          if (d is Map<String, dynamic>) PlanDay.fromJson(d),
    ]..sort((a, b) => a.position.compareTo(b.position));
    return WorkoutPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      days: days,
    );
  }

  final String id;
  final String name;
  final List<PlanDay> days;
}

/// The day to show as "next up": always the first day for now. Workout
/// sessions will drive this later.
int nextUpDay(WorkoutPlan plan) => 0;

/// "A", "B", ... for a day position.
String dayLetter(int position) =>
    String.fromCharCode(0x41 + position.clamp(0, 25));

// 60s stays "60s" (the spec's example); 120s and up in whole minutes read as "2m".
String _rest(int seconds) {
  if (seconds >= 120 && seconds % 60 == 0) return '${seconds ~/ 60}m';
  return '${seconds}s';
}

/// The prescription line, e.g. `4 × 8-10 · 90s` or `3 × 30s hold · 60s`.
/// The rep range uses a plain hyphen.
String formatPrescription(PlanExercise e) {
  final String work;
  if (e.kind == 'time') {
    work = '${e.holdSeconds ?? 0}s hold';
  } else {
    final lo = e.repsMin;
    final hi = e.repsMax;
    if (lo == null && hi == null) {
      work = '?';
    } else if (lo == null || hi == null || lo == hi) {
      work = '${lo ?? hi}';
    } else {
      work = '$lo-$hi';
    }
  }
  return '${e.sets} × $work · ${_rest(e.restSeconds)}';
}
