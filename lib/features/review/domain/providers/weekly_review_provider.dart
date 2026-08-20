/// Provider for the weekly review.
///
/// Reads the four list providers that are already loaded in memory and
/// builds the review with the pure [buildWeeklyReview]. No repository call,
/// no network: every source list is already fetched by its own feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/review/domain/weekly_review.dart';
import 'package:life_os/features/subscriptions/domain/providers/subscription_provider.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';

/// The most recently ended week's review, rebuilt whenever any source list
/// changes.
final weeklyReviewProvider = Provider<WeeklyReview>((ref) {
  final tasks = ref.watch(taskListProvider).tasks;
  final jobs = ref.watch(jobListProvider).jobs;
  final subscriptions = ref.watch(subscriptionListProvider).subscriptions;
  final goals = ref.watch(goalListProvider).goals;

  return buildWeeklyReview(
    weekStart: mostRecentEndedWeekStart(DateTime.now()),
    tasks: tasks,
    jobs: jobs,
    subscriptions: subscriptions,
    goals: goals,
  );
});
