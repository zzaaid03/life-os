/// Timeline event model + aggregator.
///
/// Builds a unified chronological feed from the existing feature
/// providers — created/completed tasks, goal updates, and job-application
/// status changes. Because it `watch`es each underlying provider, the feed
/// recomputes automatically whenever any source data changes.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:riverpod/riverpod.dart';

/// The kind of event on the timeline, driving its icon and label.
enum TimelineEventType {
  taskCreated,
  taskCompleted,
  goalUpdated,
  jobStatusChanged,
}

/// A single event on the unified timeline.
class TimelineEvent {
  /// Creates a [TimelineEvent].
  const TimelineEvent({
    required this.type,
    required this.title,
    this.subtitle,
    required this.timestamp,
  });

  /// What happened.
  final TimelineEventType type;

  /// The primary line (e.g. the task title).
  final String title;

  /// An optional secondary line.
  final String? subtitle;

  /// When it happened.
  final DateTime timestamp;

  /// The icon for this event type.
  IconData get icon => switch (type) {
    TimelineEventType.taskCreated => Icons.add_task_rounded,
    TimelineEventType.taskCompleted => Icons.check_circle_rounded,
    TimelineEventType.goalUpdated => Icons.flag_rounded,
    TimelineEventType.jobStatusChanged => Icons.work_outline_rounded,
  };

  /// A short label for this event type (e.g. "Task completed").
  String get label => switch (type) {
    TimelineEventType.taskCreated => 'Task created',
    TimelineEventType.taskCompleted => 'Task completed',
    TimelineEventType.goalUpdated => 'Goal update',
    TimelineEventType.jobStatusChanged => 'Job application',
  };
}

/// The unified timeline: all events, newest first.
final timelineEventsProvider = Provider<List<TimelineEvent>>((ref) {
  final events = <TimelineEvent>[];

  // Tasks — creation and completion are separate events.
  final tasks = ref.watch(taskListProvider).tasks;
  for (final task in tasks) {
    events.add(
      TimelineEvent(
        type: TimelineEventType.taskCreated,
        title: task.title,
        timestamp: task.createdAt,
      ),
    );
    if (task.status == TaskStatus.completed && task.completedAt != null) {
      events.add(
        TimelineEvent(
          type: TimelineEventType.taskCompleted,
          title: task.title,
          timestamp: task.completedAt!,
        ),
      );
    }
  }

  // Goals — one event per goal reflecting its latest update.
  final goals = ref.watch(goalListProvider).goals;
  for (final goal in goals) {
    final linkedCount = ref.watch(goalTaskCountProvider(goal.id));
    final progress = linkedCount > 0
        ? ref.watch(goalProgressProvider(goal.id))
        : goal.progress;
    final pct = (progress * 100).round();
    final isCompleted = linkedCount > 0
        ? progress >= 1.0
        : goal.status == GoalStatus.completed;
    events.add(
      TimelineEvent(
        type: TimelineEventType.goalUpdated,
        title: goal.title,
        subtitle: isCompleted ? 'Completed \u{1F389}' : '$pct% there',
        timestamp: goal.updatedAt,
      ),
    );
  }

  // Job applications — one event per application's latest status.
  final jobs = ref.watch(jobListProvider).jobs;
  for (final job in jobs) {
    events.add(
      TimelineEvent(
        type: TimelineEventType.jobStatusChanged,
        title: jobDisplayTitle(
          company: job.company,
          role: job.role,
          status: job.status,
        ),
        subtitle: jobStatusHeadline(job.status),
        timestamp: job.updatedAt,
      ),
    );
  }

  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return events;
});
