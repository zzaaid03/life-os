/// Provider for the workout part of the weekly review.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/features/fitness/data/workout_history_repository.dart';
import 'package:life_os/features/review/domain/weekly_review.dart';
import 'package:life_os/features/review/domain/weekly_workouts.dart';

/// Workouts of the same week [weeklyReviewProvider] covers (local Monday to
/// Monday, queried in UTC). A failed query stays an error, never an empty week.
final weeklyWorkoutsProvider = FutureProvider.autoDispose<WeeklyWorkouts>((
  ref,
) async {
  final start = mostRecentEndedWeekStart(DateTime.now());
  // Constructor, not Duration math: see mostRecentEndedWeekStart.
  final end = DateTime(start.year, start.month, start.day + 7);
  final window = await ref
      .watch(workoutHistoryRepositoryProvider)
      .fetchWindow(start.toUtc(), end.toUtc());
  return buildWeeklyWorkouts(
    windowSets: window.sets,
    priorBests: window.priorBests,
  );
});
