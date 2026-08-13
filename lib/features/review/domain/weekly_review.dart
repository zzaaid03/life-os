/// Pure builder for the weekly review.
///
/// No Riverpod, no I/O, no clock inside [buildWeeklyReview] itself: every
/// date used is passed in, so this can be unit tested directly and reused
/// unchanged if the trigger (a button, a Sunday digest) ever changes.
library;

import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/domain/follow_up.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// Returns local Monday 00:00 of the most recently ENDED week relative to
/// [now].
///
/// "Ended" excludes the week [now] is currently inside: on a Wednesday, that
/// is the Monday 9 days earlier, not the Monday 2 days earlier, since the
/// current week has not finished yet.
/// Built with DateTime's own constructor rather than `Duration` arithmetic.
/// Subtracting 7 * 24h across a daylight-saving transition lands on 23:00 or
/// 01:00 of the wrong day instead of local midnight; the constructor
/// normalises an out-of-range day and always yields real local midnight.
DateTime mostRecentEndedWeekStart(DateTime now) {
  // DateTime.weekday is 1 (Monday) .. 7 (Sunday).
  return DateTime(now.year, now.month, now.day - (now.weekday - 1) - 7);
}

/// One currency's monthly subscription total, in cents.
class CurrencyTotal {
  /// Creates a [CurrencyTotal].
  const CurrencyTotal({required this.currency, required this.totalCents});

  /// Three-letter uppercase ISO code.
  final String currency;

  /// Sum of monthly-equivalent charges in this currency, in cents.
  final int totalCents;
}

/// How much progress one goal made this week.
class GoalMovement {
  /// Creates a [GoalMovement].
  const GoalMovement({required this.goal, required this.completedCount});

  /// The goal that moved.
  final Goal goal;

  /// Number of linked tasks completed inside the window.
  final int completedCount;
}

/// Task activity for the review window.
class ReviewTasks {
  /// Creates a [ReviewTasks].
  const ReviewTasks({required this.completed, required this.slipped});

  /// Tasks completed inside the window, sorted by `completedAt` ascending.
  final List<Task> completed;

  /// Tasks due inside the window that are still open, sorted by `dueDate`
  /// ascending.
  final List<Task> slipped;

  /// Whether both lists are empty.
  bool get isEmpty => completed.isEmpty && slipped.isEmpty;
}

/// Job-hunt activity for the review window.
class ReviewJobs {
  /// Creates a [ReviewJobs].
  const ReviewJobs({
    required this.added,
    required this.pipeline,
    required this.quiet,
  });

  /// Applications added inside the window.
  final List<JobApplication> added;

  /// A snapshot of how many applications are at each current status, as of
  /// now. This is NOT a claim that a transition happened during the window:
  /// there is no status-history table in this schema.
  final Map<String, int> pipeline;

  /// Applications that have gone quiet, from [staleApplications].
  final List<JobApplication> quiet;

  /// Whether nothing job-related is worth reporting for this window.
  ///
  /// [pipeline] is deliberately excluded: it is a standing snapshot of every
  /// application ever, so counting it would make this permanently false for
  /// anyone with a single application and the empty state unreachable.
  bool get isEmpty => added.isEmpty && quiet.isEmpty;
}

/// Subscription activity for the review window.
class ReviewSubscriptions {
  /// Creates a [ReviewSubscriptions].
  const ReviewSubscriptions({
    required this.renewingSoon,
    required this.monthlyTotals,
  });

  /// Subscriptions charging within 7 days after the window ends.
  final List<Subscription> renewingSoon;

  /// Monthly totals, one entry per currency, never combined or converted.
  final List<CurrencyTotal> monthlyTotals;

  /// Whether nothing subscription-related is worth reporting for this window.
  ///
  /// [monthlyTotals] is deliberately excluded for the same reason as
  /// [ReviewJobs.pipeline]: a standing total is not weekly activity.
  bool get isEmpty => renewingSoon.isEmpty;
}

/// Goal activity for the review window.
class ReviewGoals {
  /// Creates a [ReviewGoals].
  const ReviewGoals({required this.moved, required this.untouched});

  /// Goals with at least one linked task completed inside the window,
  /// sorted by completed count descending.
  final List<GoalMovement> moved;

  /// Active goals with no linked task completed inside the window.
  final List<Goal> untouched;

  /// Whether no goal moved during this window.
  ///
  /// [untouched] is deliberately excluded: an active goal that saw no work is
  /// standing context, not something that happened this week.
  bool get isEmpty => moved.isEmpty;
}

/// The full weekly review for one window.
class WeeklyReview {
  /// Creates a [WeeklyReview].
  const WeeklyReview({
    required this.weekStart,
    required this.weekEnd,
    required this.tasks,
    required this.jobs,
    required this.subscriptions,
    required this.goals,
  });

  /// Local Monday 00:00 of the reviewed week.
  final DateTime weekStart;

  /// [weekStart] plus 7 days. The window is half-open: `[weekStart, weekEnd)`.
  final DateTime weekEnd;

  /// Task activity.
  final ReviewTasks tasks;

  /// Job-hunt activity.
  final ReviewJobs jobs;

  /// Subscription activity.
  final ReviewSubscriptions subscriptions;

  /// Goal activity.
  final ReviewGoals goals;

  /// True only when nothing HAPPENED in this window.
  ///
  /// Each section excludes its standing snapshots (the job pipeline, monthly
  /// subscription totals, goals that sat still), so this is a real signal
  /// rather than something permanently false for any user with data.
  bool get isEmpty =>
      tasks.isEmpty && jobs.isEmpty && subscriptions.isEmpty && goals.isEmpty;
}

bool _inWindow(DateTime value, DateTime start, DateTime end) {
  return !value.isBefore(start) && value.isBefore(end);
}

/// Assembles a [WeeklyReview] for `[weekStart, weekStart + 7 days)` from
/// already-loaded rows. Pure: no clock, no provider, no network.
WeeklyReview buildWeeklyReview({
  required DateTime weekStart,
  required List<Task> tasks,
  required List<JobApplication> jobs,
  required List<Subscription> subscriptions,
  required List<Goal> goals,
}) {
  // Constructor, not `add(Duration(days: 7))`: see mostRecentEndedWeekStart.
  final weekEnd = DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day + 7,
    weekStart.hour,
    weekStart.minute,
  );

  final activeTasks = tasks.where(
    (t) => t.deletedAt == null && t.status != TaskStatus.archived,
  );

  final completed =
      activeTasks
          .where(
            (t) =>
                t.status == TaskStatus.completed &&
                t.completedAt != null &&
                _inWindow(t.completedAt!, weekStart, weekEnd),
          )
          .toList()
        ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));

  final slipped =
      activeTasks
          .where(
            (t) =>
                t.status != TaskStatus.completed &&
                t.dueDate != null &&
                _inWindow(t.dueDate!, weekStart, weekEnd),
          )
          .toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  final reviewTasks = ReviewTasks(completed: completed, slipped: slipped);

  final added = jobs
      .where(
        (j) => _inWindow(j.appliedAt ?? j.createdAt, weekStart, weekEnd),
      )
      .toList();

  final pipeline = <String, int>{};
  for (final job in jobs) {
    pipeline[job.status] = (pipeline[job.status] ?? 0) + 1;
  }

  final quiet = staleApplications(jobs, weekEnd);

  final reviewJobs = ReviewJobs(added: added, pipeline: pipeline, quiet: quiet);

  final renewingSoon = chargingSoon(subscriptions, weekEnd);

  final monthlyTotals = monthlyTotalsByCurrency(subscriptions).entries
      .map((e) => CurrencyTotal(currency: e.key, totalCents: e.value))
      .toList()
    ..sort((a, b) => a.currency.compareTo(b.currency));

  final reviewSubscriptions = ReviewSubscriptions(
    renewingSoon: renewingSoon,
    monthlyTotals: monthlyTotals,
  );

  final completedByGoalId = <String, int>{};
  for (final task in completed) {
    final goalId = task.goalId;
    if (goalId == null) continue;
    completedByGoalId[goalId] = (completedByGoalId[goalId] ?? 0) + 1;
  }

  final moved = <GoalMovement>[];
  final untouched = <Goal>[];
  for (final goal in goals) {
    final count = completedByGoalId[goal.id] ?? 0;
    if (count > 0) {
      moved.add(GoalMovement(goal: goal, completedCount: count));
    } else if (goal.status == GoalStatus.active) {
      untouched.add(goal);
    }
  }
  moved.sort((a, b) => b.completedCount.compareTo(a.completedCount));

  final reviewGoals = ReviewGoals(moved: moved, untouched: untouched);

  return WeeklyReview(
    weekStart: weekStart,
    weekEnd: weekEnd,
    tasks: reviewTasks,
    jobs: reviewJobs,
    subscriptions: reviewSubscriptions,
    goals: reviewGoals,
  );
}
