/// Repeating tasks.
///
/// A recurring task is NOT a series stored somewhere. There is only ever one
/// live instance of it. Completing that instance spawns the next one, and the
/// completed row keeps its history while giving up its recurrence rule. That
/// is what makes the whole thing idempotent: un-completing and re-completing a
/// task cannot spawn a second copy, because after the first completion the
/// finished row is no longer recurring.
library;

import 'package:life_os/features/tasks/data/models/task.dart';

/// The due date of the occurrence that follows [dueDate].
///
/// Advances one period from the PREVIOUS DUE DATE, not from [now], so a weekly
/// task stays anchored to its day of the week even when it gets completed
/// late. It then keeps advancing until it lands past today, so completing a
/// daily task four days late gives you tomorrow rather than four reminders for
/// dates that have already gone.
///
/// Monthly clamps to the end of a short month (31 Jan → 28 Feb) and does NOT
/// restore afterwards (→ 28 Mar). Restoring would need the series' original
/// anchor day, which does not survive the completed row giving up its rule.
DateTime nextRecurrenceDueDate(
  DateTime dueDate,
  Recurrence recurrence,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  var next = _advance(dueDate, recurrence);
  // Bounded to keep a nonsense stored date (a due date decades in the past)
  // from spinning here forever. 600 monthly steps is 50 years.
  var guard = 0;
  while (!next.isAfter(today) && guard < 600) {
    next = _advance(next, recurrence);
    guard++;
  }
  return next;
}

/// Builds the next occurrence of a task that has just been completed.
///
/// Returns null when there is nothing to spawn: the task does not repeat, or
/// it has no due date to advance from.
///
/// The returned task is a fresh pending row carrying the rule forward. It is
/// deliberately NOT linked to the completed one (no `parentTaskId`): that
/// field means subtask, and a repeat is a sibling, not a child.
Task? nextRecurringTask({
  required Task completed,
  required String newId,
  required DateTime now,
}) {
  final recurrence = completed.recurrence;
  final dueDate = completed.dueDate;
  if (recurrence == null || dueDate == null) return null;

  return Task(
    id: newId,
    userId: completed.userId,
    title: completed.title,
    description: completed.description,
    dueDate: nextRecurrenceDueDate(dueDate, recurrence, now),
    priority: completed.priority,
    goalId: completed.goalId,
    sortOrder: completed.sortOrder,
    recurrence: recurrence,
    createdAt: now,
    updatedAt: now,
  );
}

DateTime _advance(DateTime from, Recurrence recurrence) {
  return switch (recurrence) {
    // Rebuilt through DateTime's own constructor rather than by adding a
    // Duration, so a day that gains or loses an hour to DST does not drag the
    // whole series an hour off its slot.
    Recurrence.daily => DateTime(
      from.year,
      from.month,
      from.day + 1,
      from.hour,
      from.minute,
    ),
    Recurrence.weekly => DateTime(
      from.year,
      from.month,
      from.day + 7,
      from.hour,
      from.minute,
    ),
    Recurrence.monthly => _addOneMonth(from),
  };
}

DateTime _addOneMonth(DateTime from) {
  final year = from.month == 12 ? from.year + 1 : from.year;
  final month = from.month == 12 ? 1 : from.month + 1;
  // Day 0 of the following month is the last day of this one.
  final lastDayOfTarget = DateTime(year, month + 1, 0).day;
  final day = from.day < lastDayOfTarget ? from.day : lastDayOfTarget;
  return DateTime(year, month, day, from.hour, from.minute);
}
