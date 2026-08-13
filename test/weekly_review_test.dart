import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/review/domain/weekly_review.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

Task _task({
  required String id,
  TaskStatus status = TaskStatus.pending,
  DateTime? dueDate,
  DateTime? completedAt,
  DateTime? updatedAt,
  String? goalId,
  DateTime? deletedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return Task(
    id: id,
    userId: 'user-1',
    title: 'Task $id',
    status: status,
    dueDate: dueDate,
    completedAt: completedAt,
    goalId: goalId,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    deletedAt: deletedAt,
  );
}

JobApplication _job({
  required String id,
  required String status,
  DateTime? appliedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final fallback = DateTime(2026, 1, 1);
  return JobApplication(
    id: id,
    company: 'Company $id',
    role: 'Role $id',
    status: status,
    appliedAt: appliedAt,
    createdAt: createdAt ?? fallback,
    updatedAt: updatedAt ?? fallback,
  );
}

Subscription _subscription({
  required String id,
  required String currency,
  int amountCents = 999,
  BillingCycle cycle = BillingCycle.monthly,
  SubscriptionStatus status = SubscriptionStatus.active,
  DateTime? nextChargeDate,
}) {
  final now = DateTime(2026, 1, 1);
  return Subscription(
    id: id,
    userId: 'user-1',
    name: 'Sub $id',
    amountCents: amountCents,
    currency: currency,
    cycle: cycle,
    status: status,
    nextChargeDate: nextChargeDate,
    createdAt: now,
    updatedAt: now,
  );
}

Goal _goal({
  required String id,
  GoalStatus status = GoalStatus.active,
}) {
  final now = DateTime(2026, 1, 1);
  return Goal(
    id: id,
    userId: 'user-1',
    title: 'Goal $id',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // Monday 2026-01-05 00:00 local through Monday 2026-01-12 00:00 local,
  // exclusive.
  final weekStart = DateTime(2026, 1, 5);
  final weekEnd = DateTime(2026, 1, 12);

  group('buildWeeklyReview — tasks', () {
    test('a task completed on the window\'s last day is included', () {
      final lastMoment = weekEnd.subtract(const Duration(seconds: 1));
      final review = buildWeeklyReview(
        weekStart: weekStart,
        tasks: [
          _task(
            id: 'a',
            status: TaskStatus.completed,
            completedAt: lastMoment,
          ),
        ],
        jobs: const [],
        subscriptions: const [],
        goals: const [],
      );

      expect(review.tasks.completed.map((t) => t.id), ['a']);
    });

    test('a task completed exactly at weekEnd is excluded', () {
      final review = buildWeeklyReview(
        weekStart: weekStart,
        tasks: [
          _task(id: 'a', status: TaskStatus.completed, completedAt: weekEnd),
        ],
        jobs: const [],
        subscriptions: const [],
        goals: const [],
      );

      expect(review.tasks.completed, isEmpty);
    });

    test(
      'a task completed in-window but edited later stays in the week it '
      'was completed (proves completedAt, not updatedAt)',
      () {
        final review = buildWeeklyReview(
          weekStart: weekStart,
          tasks: [
            _task(
              id: 'a',
              status: TaskStatus.completed,
              completedAt: weekStart.add(const Duration(days: 1)),
              updatedAt: weekEnd.add(const Duration(days: 30)),
            ),
          ],
          jobs: const [],
          subscriptions: const [],
          goals: const [],
        );

        expect(review.tasks.completed.map((t) => t.id), ['a']);
      },
    );

    test(
      'a task due in the window and still open appears in slipped; a '
      'completed one does not',
      () {
        final review = buildWeeklyReview(
          weekStart: weekStart,
          tasks: [
            _task(
              id: 'open',
              status: TaskStatus.pending,
              dueDate: weekStart.add(const Duration(days: 2)),
            ),
            _task(
              id: 'done',
              status: TaskStatus.completed,
              dueDate: weekStart.add(const Duration(days: 2)),
              completedAt: weekStart.add(const Duration(days: 1)),
            ),
          ],
          jobs: const [],
          subscriptions: const [],
          goals: const [],
        );

        expect(review.tasks.slipped.map((t) => t.id), ['open']);
      },
    );

    test('archived and soft-deleted tasks appear in neither list', () {
      final review = buildWeeklyReview(
        weekStart: weekStart,
        tasks: [
          _task(
            id: 'archived',
            status: TaskStatus.archived,
            dueDate: weekStart.add(const Duration(days: 1)),
          ),
          _task(
            id: 'deleted',
            status: TaskStatus.completed,
            completedAt: weekStart.add(const Duration(days: 1)),
            deletedAt: weekStart,
          ),
        ],
        jobs: const [],
        subscriptions: const [],
        goals: const [],
      );

      expect(review.tasks.completed, isEmpty);
      expect(review.tasks.slipped, isEmpty);
    });
  });

  group('buildWeeklyReview — subscriptions', () {
    test(
      'two subscriptions in different currencies produce two CurrencyTotal '
      'entries and no combined figure',
      () {
        final review = buildWeeklyReview(
          weekStart: weekStart,
          tasks: const [],
          jobs: const [],
          subscriptions: [
            _subscription(id: 'a', currency: 'USD', amountCents: 999),
            _subscription(id: 'b', currency: 'EUR', amountCents: 500),
          ],
          goals: const [],
        );

        expect(review.subscriptions.monthlyTotals, hasLength(2));
        final currencies = review.subscriptions.monthlyTotals
            .map((t) => t.currency)
            .toList();
        expect(currencies, ['EUR', 'USD']);
      },
    );

    test('a cancelled subscription is excluded from the totals', () {
      final review = buildWeeklyReview(
        weekStart: weekStart,
        tasks: const [],
        jobs: const [],
        subscriptions: [
          _subscription(id: 'a', currency: 'USD', amountCents: 999),
          _subscription(
            id: 'b',
            currency: 'USD',
            amountCents: 500,
            status: SubscriptionStatus.cancelled,
          ),
        ],
        goals: const [],
      );

      expect(review.subscriptions.monthlyTotals, hasLength(1));
      expect(review.subscriptions.monthlyTotals.single.totalCents, 999);
    });
  });

  group('buildWeeklyReview — goals', () {
    test(
      'a goal with two completed linked tasks reports a count of 2; a goal '
      'with none is in untouched',
      () {
        final review = buildWeeklyReview(
          weekStart: weekStart,
          tasks: [
            _task(
              id: 't1',
              status: TaskStatus.completed,
              completedAt: weekStart.add(const Duration(days: 1)),
              goalId: 'g1',
            ),
            _task(
              id: 't2',
              status: TaskStatus.completed,
              completedAt: weekStart.add(const Duration(days: 2)),
              goalId: 'g1',
            ),
          ],
          jobs: const [],
          subscriptions: const [],
          goals: [_goal(id: 'g1'), _goal(id: 'g2')],
        );

        expect(review.goals.moved, hasLength(1));
        expect(review.goals.moved.single.goal.id, 'g1');
        expect(review.goals.moved.single.completedCount, 2);
        expect(review.goals.untouched.map((g) => g.id), ['g2']);
      },
    );
  });

  group('buildWeeklyReview — jobs', () {
    test('an application added in the window appears in added', () {
      final review = buildWeeklyReview(
        weekStart: weekStart,
        tasks: const [],
        jobs: [
          _job(
            id: 'a',
            status: 'applied',
            appliedAt: weekStart.add(const Duration(days: 1)),
          ),
        ],
        subscriptions: const [],
        goals: const [],
      );

      expect(review.jobs.added.map((j) => j.id), ['a']);
    });
  });

  group('mostRecentEndedWeekStart', () {
    test('on a Wednesday returns the Monday 9 days earlier', () {
      // 2026-01-14 is a Wednesday.
      final wednesday = DateTime(2026, 1, 14);
      final result = mostRecentEndedWeekStart(wednesday);

      expect(result, wednesday.subtract(const Duration(days: 9)));
      expect(result, DateTime(2026, 1, 5));
    });

    test('returns real local midnight across a daylight-saving change', () {
      // Europe/Berlin springs forward on the last Sunday of March (2026-03-29),
      // so the week before it is 167 hours long, not 168. Duration arithmetic
      // would land on 23:00 of the previous day; the constructor must not.
      for (final now in [
        DateTime(2026, 3, 31), // Tuesday after the spring-forward
        DateTime(2026, 4, 1), // Wednesday after
        DateTime(2026, 11, 3), // Tuesday after the autumn fall-back
      ]) {
        final result = mostRecentEndedWeekStart(now);
        expect(result.hour, 0, reason: 'not local midnight for $now');
        expect(result.minute, 0, reason: 'not local midnight for $now');
        expect(result.weekday, DateTime.monday, reason: 'not a Monday for $now');
      }
    });
  });

  group('buildWeeklyReview — empty input', () {
    test('all-empty input produces isEmpty == true and does not throw', () {
      final review = buildWeeklyReview(
        weekStart: weekStart,
        tasks: const [],
        jobs: const [],
        subscriptions: const [],
        goals: const [],
      );

      expect(review.isEmpty, isTrue);
    });

    test(
      'standing snapshots alone do not make the week look eventful',
      () {
        // A real user always has a job pipeline and a monthly total. If those
        // counted as activity, isEmpty would be permanently false and the
        // screen's empty state would be unreachable.
        final review = buildWeeklyReview(
          weekStart: weekStart,
          tasks: const [],
          jobs: [
            _job(
              id: 'old',
              status: 'interview',
              appliedAt: weekStart.subtract(const Duration(days: 90)),
            ),
          ],
          subscriptions: [_subscription(id: 's', currency: 'EUR')],
          goals: [_goal(id: 'g')],
        );

        expect(review.jobs.pipeline, isNotEmpty);
        expect(review.subscriptions.monthlyTotals, isNotEmpty);
        expect(review.goals.untouched, isNotEmpty);
        expect(review.isEmpty, isTrue);
      },
    );
  });
}
