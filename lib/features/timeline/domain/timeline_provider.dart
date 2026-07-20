/// Timeline event model + aggregator.
///
/// Builds a unified chronological feed from the existing feature
/// providers — created/completed tasks, notes, habit check-offs, goal
/// updates, and job-application status changes. Because it `watch`es each
/// underlying provider, the feed recomputes automatically whenever any
/// source data changes.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/habits/domain/providers/habit_provider.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';
import 'package:life_os/features/notes/domain/providers/note_provider.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:riverpod/riverpod.dart';

/// The kind of event on the timeline, driving its icon and label.
enum TimelineEventType {
  taskCreated,
  taskCompleted,
  noteCreated,
  habitCheckedOff,
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
    TimelineEventType.noteCreated => Icons.sticky_note_2_outlined,
    TimelineEventType.habitCheckedOff => Icons.local_fire_department_rounded,
    TimelineEventType.goalUpdated => Icons.flag_rounded,
    TimelineEventType.jobStatusChanged => Icons.work_outline_rounded,
  };

  /// A short label for this event type (e.g. "Task completed").
  String get label => switch (type) {
    TimelineEventType.taskCreated => 'Task created',
    TimelineEventType.taskCompleted => 'Task completed',
    TimelineEventType.noteCreated => 'Note',
    TimelineEventType.habitCheckedOff => 'Habit checked off',
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

  // Notes.
  final notes = ref.watch(noteListProvider).notes;
  for (final note in notes) {
    events.add(
      TimelineEvent(
        type: TimelineEventType.noteCreated,
        title: note.title,
        timestamp: note.createdAt,
      ),
    );
  }

  // Habit check-offs — resolve the habit name for each entry.
  final habitState = ref.watch(habitListProvider);
  final habitNames = {
    for (final view in habitState.habits) view.habit.id: view.habit.name,
  };
  for (final entry in habitState.recentEntries) {
    final name = habitNames[entry.habitId];
    if (name == null) continue; // Entry of a deleted/archived habit.
    events.add(
      TimelineEvent(
        type: TimelineEventType.habitCheckedOff,
        title: name,
        // Entries store a date (not a time); use the creation instant when
        // the check-off happened on the same day for a natural ordering.
        timestamp: _sameDay(entry.createdAt, entry.completedDate)
            ? entry.createdAt
            : entry.completedDate,
      ),
    );
  }

  // Goals — one event per goal reflecting its latest update.
  final goals = ref.watch(goalListProvider).goals;
  for (final goal in goals) {
    final pct = (goal.progress * 100).round();
    events.add(
      TimelineEvent(
        type: TimelineEventType.goalUpdated,
        title: goal.title,
        subtitle: goal.status == GoalStatus.completed
            ? 'Completed \u{1F389}'
            : '$pct% there',
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

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
