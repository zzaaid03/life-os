import 'package:life_os/features/tasks/data/models/task.dart';

/// Which of the two daily reminder slots a [PendingReminder] occupies.
enum ReminderSlot {
  /// 20:00 local, the day before the task is due.
  eveningBefore,

  /// 09:00 local, on the day the task is due.
  morningOf,
}

/// Local hour at which the evening-before reminder fires.
const int kEveningBeforeHour = 20;

/// Local hour at which the morning-of reminder fires.
const int kMorningOfHour = 9;

/// iOS allows at most 64 PENDING scheduled local notifications per app. Past
/// that the OS silently drops whichever it likes, so we do the truncating
/// ourselves, soonest-first, and the result is deterministic instead of
/// whatever iOS felt like keeping. Two slots per task means this covers the
/// nearest ~32 tasks. Android has no comparable limit, but scheduling the
/// same window on both keeps behaviour identical across platforms.
const int kMaxPendingReminders = 64;

/// One notification the platform should be holding, fully resolved.
///
/// [id] is the notification id handed to the OS. It is the item's index in
/// the freshly built schedule, NOT a hash of the task: the scheduler always
/// cancels everything and re-schedules the whole window, so sequential ids
/// are collision-free by construction and no task id needs to survive a
/// round trip through an int.
class PendingReminder {
  /// Creates a [PendingReminder].
  const PendingReminder({
    required this.id,
    required this.taskId,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.slot,
  });

  /// Notification id passed to the OS (the index in the built schedule).
  final int id;

  /// The task this reminder is about, carried as the notification payload so
  /// a tap can deep-link to it.
  final String taskId;

  /// Notification title shown on the lock screen.
  final String title;

  /// Notification body shown under the title.
  final String body;

  /// Local wall-clock time at which this should fire.
  final DateTime fireAt;

  /// Which slot this reminder occupies.
  final ReminderSlot slot;
}

/// Builds the full set of reminders that should currently be scheduled.
///
/// Pure and deterministic: same [tasks] and [now] always give the same list,
/// which is what makes this testable without a device or the plugin.
///
/// [tasks] are expected to carry LOCAL `dueDate` values. That is already the
/// case everywhere in the app: `Task.fromJson` calls `.toLocal()` on read and
/// `.toUtc()` on write, so an in-memory Task is always local. Do not "fix"
/// this by converting again.
///
/// Skipped, deliberately:
/// - tasks with no due date (the model allows null even though the editor
///   requires one, so old or imported rows can still be null),
/// - completed and archived tasks (nobody wants a reminder for something they
///   already did),
/// - soft-deleted tasks,
/// - any slot whose fire time is already in the past relative to [now]. A task
///   due today has already missed its evening-before slot; that is correct,
///   not a bug. It still gets its morning-of reminder if 09:00 has not passed.
List<PendingReminder> buildReminderSchedule(
  List<Task> tasks,
  DateTime now, {
  int maxPending = kMaxPendingReminders,
}) {
  final candidates = <PendingReminder>[];

  for (final task in tasks) {
    final dueDate = task.dueDate;
    if (dueDate == null) continue;
    if (task.deletedAt != null) continue;
    if (task.status == TaskStatus.completed ||
        task.status == TaskStatus.archived) {
      continue;
    }

    // Collapse to the calendar day, then rebuild at the slot hour. Going
    // through DateTime's own constructor keeps DST correct: on a day that
    // gains or loses an hour, 09:00 local is still 09:00 local.
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final slots = <ReminderSlot, DateTime>{
      ReminderSlot.eveningBefore: DateTime(
        dueDay.year,
        dueDay.month,
        dueDay.day - 1,
        kEveningBeforeHour,
      ),
      ReminderSlot.morningOf: DateTime(
        dueDay.year,
        dueDay.month,
        dueDay.day,
        kMorningOfHour,
      ),
    };

    for (final entry in slots.entries) {
      if (!entry.value.isAfter(now)) continue;
      candidates.add(
        PendingReminder(
          // Rewritten to the real index below, once the list is ordered.
          id: 0,
          taskId: task.id,
          title: entry.key == ReminderSlot.eveningBefore
              ? 'Due tomorrow'
              : 'Due today',
          body: task.title,
          fireAt: entry.value,
          slot: entry.key,
        ),
      );
    }
  }

  // Soonest first, so truncation drops the furthest-out reminders rather than
  // an arbitrary set. Ties broken by task id to keep the order stable across
  // rebuilds (two tasks due the same day would otherwise swap places and
  // churn the scheduled set for no reason).
  candidates.sort((a, b) {
    final byTime = a.fireAt.compareTo(b.fireAt);
    if (byTime != 0) return byTime;
    return a.taskId.compareTo(b.taskId);
  });

  final kept = candidates.length > maxPending
      ? candidates.sublist(0, maxPending)
      : candidates;

  return <PendingReminder>[
    for (var i = 0; i < kept.length; i++)
      PendingReminder(
        id: i,
        taskId: kept[i].taskId,
        title: kept[i].title,
        body: kept[i].body,
        fireAt: kept[i].fireAt,
        slot: kept[i].slot,
      ),
  ];
}
