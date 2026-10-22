/// Pure builder for the workout part of the weekly review.
library;

import 'package:life_os/features/fitness/domain/personal_best.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

/// A set that beat the best earlier one for its exercise.
class NewPersonalBest {
  /// Creates a [NewPersonalBest].
  const NewPersonalBest({required this.set, required this.previous});

  /// The new best.
  final LoggedSet set;

  /// The best before the week.
  final LoggedSet previous;
}

/// Workouts done in the reviewed week.
class WeeklyWorkouts {
  /// Creates a [WeeklyWorkouts].
  const WeeklyWorkouts({
    required this.sessionCount,
    required this.setCount,
    required this.personalBests,
  });

  /// Distinct sessions with at least one set in the window.
  final int sessionCount;

  /// Sets logged in the window.
  final int setCount;

  /// One entry per exercise that beat its earlier best.
  final List<NewPersonalBest> personalBests;
}

/// Counts sessions and sets in [windowSets] and finds the personal bests.
/// [priorBests] holds the best earlier set per [setGroupKey]. With no earlier
/// set there is nothing to beat, so the first log of an exercise is not a PB.
WeeklyWorkouts buildWeeklyWorkouts({
  required List<LoggedSet> windowSets,
  required Map<String, LoggedSet> priorBests,
}) {
  final groups = <String, List<LoggedSet>>{};
  for (final s in windowSets) {
    groups.putIfAbsent(setGroupKey(s.exerciseName, s.kind), () => []).add(s);
  }
  final bests = <NewPersonalBest>[];
  for (final entry in groups.entries) {
    final prior = priorBests[entry.key];
    final best = bestSet(entry.value);
    if (prior != null && best != null && isBetterSet(best, prior)) {
      bests.add(NewPersonalBest(set: best, previous: prior));
    }
  }
  return WeeklyWorkouts(
    sessionCount: {for (final s in windowSets) s.sessionId}.length,
    setCount: windowSets.length,
    personalBests: bests,
  );
}

/// The review line for a personal best.
String describePersonalBest(NewPersonalBest pb, UnitSystem units) {
  final name = pb.set.exerciseName;
  final now = describeSet(pb.set, units);
  if (pb.set.kind == 'time') return '$name: $now';
  return '$name: $now (best was ${describeSet(pb.previous, units)})';
}
