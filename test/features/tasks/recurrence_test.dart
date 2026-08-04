import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/recurrence.dart';

Task _task({
  required String id,
  DateTime? dueDate,
  Recurrence? recurrence,
  TaskStatus status = TaskStatus.pending,
  TaskPriority priority = TaskPriority.none,
  String? goalId,
}) {
  final stamp = DateTime(2026, 1, 1);
  return Task(
    id: id,
    userId: 'u1',
    title: 'Task $id',
    dueDate: dueDate,
    recurrence: recurrence,
    status: status,
    priority: priority,
    goalId: goalId,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

void main() {
  group('nextRecurrenceDueDate', () {
    test('daily advances by one day from the due date', () {
      final dueDate = DateTime(2026, 1, 10);
      final now = DateTime(2026, 1, 10, 9);

      final next = nextRecurrenceDueDate(dueDate, Recurrence.daily, now);

      expect(next, equals(DateTime(2026, 1, 11)));
    });

    test('weekly advances by seven days from the due date', () {
      final dueDate = DateTime(2026, 1, 10);
      final now = DateTime(2026, 1, 10, 9);

      final next = nextRecurrenceDueDate(dueDate, Recurrence.weekly, now);

      expect(next, equals(DateTime(2026, 1, 17)));
    });

    test('monthly advances by one calendar month from the due date', () {
      final dueDate = DateTime(2026, 1, 10);
      final now = DateTime(2026, 1, 10, 9);

      final next = nextRecurrenceDueDate(dueDate, Recurrence.monthly, now);

      expect(next, equals(DateTime(2026, 2, 10)));
    });

    test('monthly clamps 31 Jan to 28 Feb (2026 is not a leap year)', () {
      final dueDate = DateTime(2026, 1, 31);
      final now = DateTime(2026, 1, 31, 9);

      final next = nextRecurrenceDueDate(dueDate, Recurrence.monthly, now);

      expect(next, equals(DateTime(2026, 2, 28)));
    });

    test('completing a daily task several periods late rolls forward to '
        'a date after today, not into the past', () {
      final dueDate = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 5, 12);

      final next = nextRecurrenceDueDate(dueDate, Recurrence.daily, now);

      expect(next.isAfter(DateTime(2026, 1, 5)), isTrue);
      expect(next, equals(DateTime(2026, 1, 6)));
    });

    test('completing a weekly task several periods late rolls forward to '
        'a date after today, not into the past', () {
      final dueDate = DateTime(2026, 1, 1);
      final now = DateTime(2026, 1, 20, 12);

      final next = nextRecurrenceDueDate(dueDate, Recurrence.weekly, now);

      expect(next.isAfter(DateTime(2026, 1, 20)), isTrue);
      expect(next, equals(DateTime(2026, 1, 22)));
    });
  });

  group('nextRecurringTask', () {
    test('returns null for a non-repeating task', () {
      final completed = _task(
        id: 't1',
        dueDate: DateTime(2026, 1, 10),
        status: TaskStatus.completed,
      );

      final next = nextRecurringTask(
        completed: completed,
        newId: 't2',
        now: DateTime(2026, 1, 10, 9),
      );

      expect(next, isNull);
    });

    test('returns null for a repeating task with a null due date', () {
      final completed = _task(
        id: 't1',
        dueDate: null,
        recurrence: Recurrence.daily,
        status: TaskStatus.completed,
      );

      final next = nextRecurringTask(
        completed: completed,
        newId: 't2',
        now: DateTime(2026, 1, 10, 9),
      );

      expect(next, isNull);
    });

    test('spawned task carries title, priority, goalId and the rule '
        'forward, is pending, and has a null completedAt', () {
      final now = DateTime(2026, 1, 10, 9);
      final completed = _task(
        id: 't1',
        dueDate: DateTime(2026, 1, 10),
        recurrence: Recurrence.weekly,
        status: TaskStatus.completed,
        priority: TaskPriority.high,
        goalId: 'g1',
      );

      final next = nextRecurringTask(
        completed: completed,
        newId: 't2',
        now: now,
      );

      expect(next, isNotNull);
      expect(next!.id, equals('t2'));
      expect(next.title, equals(completed.title));
      expect(next.priority, equals(TaskPriority.high));
      expect(next.goalId, equals('g1'));
      expect(next.recurrence, equals(Recurrence.weekly));
      expect(next.status, equals(TaskStatus.pending));
      expect(next.completedAt, isNull);
      expect(next.dueDate, equals(DateTime(2026, 1, 17)));
    });
  });
}
