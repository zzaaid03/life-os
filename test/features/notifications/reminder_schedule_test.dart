import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/notifications/domain/reminder_schedule.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

Task _task({
  required String id,
  DateTime? dueDate,
  TaskStatus status = TaskStatus.pending,
  DateTime? deletedAt,
}) {
  final stamp = DateTime(2026, 1, 1);
  return Task(
    id: id,
    userId: 'u1',
    title: 'Task $id',
    dueDate: dueDate,
    status: status,
    deletedAt: deletedAt,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

void main() {
  group('buildReminderSchedule', () {
    test('due in 3 days produces evening-before and morning-of reminders',
        () {
      final now = DateTime(2026, 1, 10, 8);
      final dueDate = DateTime(2026, 1, 13);
      final task = _task(id: 't1', dueDate: dueDate);

      final result = buildReminderSchedule([task], now);

      expect(result, hasLength(2));
      expect(
        result.map((r) => r.slot),
        containsAll(<ReminderSlot>[
          ReminderSlot.eveningBefore,
          ReminderSlot.morningOf,
        ]),
      );

      final evening = result.firstWhere(
        (r) => r.slot == ReminderSlot.eveningBefore,
      );
      final morning = result.firstWhere(
        (r) => r.slot == ReminderSlot.morningOf,
      );

      expect(evening.fireAt, equals(DateTime(2026, 1, 12, kEveningBeforeHour)));
      expect(morning.fireAt, equals(DateTime(2026, 1, 13, kMorningOfHour)));
    });

    test('task with null dueDate produces nothing', () {
      final now = DateTime(2026, 1, 10, 8);
      final task = _task(id: 't1', dueDate: null);

      final result = buildReminderSchedule([task], now);

      expect(result, isEmpty);
    });

    test('completed, archived, and soft-deleted tasks produce nothing', () {
      final now = DateTime(2026, 1, 10, 8);
      final dueDate = DateTime(2026, 1, 13);

      final completed = _task(
        id: 't1',
        dueDate: dueDate,
        status: TaskStatus.completed,
      );
      final archived = _task(
        id: 't2',
        dueDate: dueDate,
        status: TaskStatus.archived,
      );
      final softDeleted = _task(
        id: 't3',
        dueDate: dueDate,
        deletedAt: DateTime(2026, 1, 5),
      );

      final result = buildReminderSchedule(
        [completed, archived, softDeleted],
        now,
      );

      expect(result, isEmpty);
    });

    test('a slot already past relative to now is skipped, the other slot '
        'for the same task still appears', () {
      final now = DateTime(2026, 1, 10, 7);
      final dueDate = DateTime(2026, 1, 10);
      final task = _task(id: 't1', dueDate: dueDate);

      final result = buildReminderSchedule([task], now);

      expect(result, hasLength(1));
      expect(result.single.slot, equals(ReminderSlot.morningOf));
      expect(result.single.fireAt, equals(DateTime(2026, 1, 10, kMorningOfHour)));
    });

    test('caps at maxPending, keeping the soonest reminders and dropping '
        'the furthest-out ones', () {
      final now = DateTime(2026, 1, 1);
      final tasks = [
        for (var i = 1; i <= 10; i++)
          _task(id: 't$i', dueDate: now.add(Duration(days: i))),
      ];

      final result = buildReminderSchedule(tasks, now, maxPending: 5);

      expect(result, hasLength(5));

      // Furthest-out task's reminders must not survive the cap.
      expect(result.any((r) => r.taskId == 't10'), isFalse);
      expect(result.any((r) => r.taskId == 't9'), isFalse);

      // Nearest task's both slots must survive.
      expect(result.where((r) => r.taskId == 't1'), hasLength(2));

      // Every kept fireAt must be <= the cutoff (task 3's evening-before slot).
      final cutoff = DateTime(2026, 1, 3, kEveningBeforeHour);
      for (final reminder in result) {
        expect(
          reminder.fireAt.isAfter(cutoff),
          isFalse,
          reason: '${reminder.taskId} ${reminder.slot} fired after cutoff',
        );
      }
    });

    test('ids are the list index, sequential from 0 with no gaps or '
        'duplicates', () {
      final now = DateTime(2026, 1, 1);
      final tasks = [
        for (var i = 1; i <= 5; i++)
          _task(id: 't$i', dueDate: now.add(Duration(days: i))),
      ];

      final result = buildReminderSchedule(tasks, now);

      for (var i = 0; i < result.length; i++) {
        expect(result[i].id, equals(i));
      }
      expect(result.map((r) => r.id).toSet(), hasLength(result.length));
    });

    test('ordering is stable across repeated calls for same-day tasks', () {
      final now = DateTime(2026, 1, 1);
      final dueDate = DateTime(2026, 1, 5);
      final taskB = _task(id: 'tB', dueDate: dueDate);
      final taskA = _task(id: 'tA', dueDate: dueDate);

      final first = buildReminderSchedule([taskB, taskA], now);
      final second = buildReminderSchedule([taskB, taskA], now);

      final firstOrder = first.map((r) => '${r.taskId}:${r.slot}').toList();
      final secondOrder = second.map((r) => '${r.taskId}:${r.slot}').toList();

      expect(firstOrder, equals(secondOrder));

      // Same fireAt time -> tie broken by taskId, so 'tA' sorts before 'tB'.
      final sameSlotEntries = first
          .where((r) => r.slot == ReminderSlot.eveningBefore)
          .toList();
      expect(sameSlotEntries.first.taskId, equals('tA'));
      expect(sameSlotEntries.last.taskId, equals('tB'));
    });
  });
}
