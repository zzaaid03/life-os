/// Workout session and logged set models.
library;

/// One run of a plan day. [endedAt] null means it is still open.
class WorkoutSession {
  /// Creates a [WorkoutSession].
  const WorkoutSession({
    required this.id,
    required this.dayTitle,
    required this.dayPosition,
    required this.startedAt,
    this.planId,
    this.endedAt,
  });

  /// Reads a row, tolerating missing or null fields.
  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String? ?? '',
      planId: json['plan_id'] as String?,
      dayTitle: json['day_title'] as String? ?? '',
      dayPosition: (json['day_position'] as num?)?.toInt() ?? 0,
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['ended_at'] as String? ?? '')?.toLocal(),
    );
  }

  final String id;
  final String? planId;
  final String dayTitle;
  final int dayPosition;
  final DateTime startedAt;
  final DateTime? endedAt;
}

/// One logged set. Weight is always kilograms.
class LoggedSet {
  /// Creates a [LoggedSet].
  const LoggedSet({
    required this.id,
    required this.sessionId,
    required this.exerciseName,
    required this.kind,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.holdSeconds,
  });

  /// Reads a row, tolerating missing or null fields.
  factory LoggedSet.fromJson(Map<String, dynamic> json) {
    return LoggedSet(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      exerciseName: json['exercise_name'] as String? ?? '',
      kind: json['kind'] as String? ?? 'reps',
      setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      holdSeconds: (json['hold_seconds'] as num?)?.toInt(),
    );
  }

  final String id;
  final String sessionId;
  final String exerciseName;

  /// `reps` or `time`.
  final String kind;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? holdSeconds;
}
