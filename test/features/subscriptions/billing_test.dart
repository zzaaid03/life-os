import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';

Subscription _subscription({
  required String id,
  String name = 'Sub',
  required int amountCents,
  String currency = 'USD',
  required BillingCycle cycle,
  DateTime? nextChargeDate,
  SubscriptionStatus status = SubscriptionStatus.active,
  DateTime? deletedAt,
}) {
  final stamp = DateTime(2026, 1, 1);
  return Subscription(
    id: id,
    userId: 'u1',
    name: name,
    amountCents: amountCents,
    currency: currency,
    cycle: cycle,
    nextChargeDate: nextChargeDate,
    status: status,
    createdAt: stamp,
    updatedAt: stamp,
    deletedAt: deletedAt,
  );
}

void main() {
  group('monthlyEquivalentCents', () {
    test('weekly converts via 52 weeks a year', () {
      final s = _subscription(
        id: '1',
        amountCents: 1000,
        cycle: BillingCycle.weekly,
      );
      expect(monthlyEquivalentCents(s), equals((1000 * 52 / 12).round()));
    });

    test('monthly returns the amount unchanged', () {
      final s = _subscription(
        id: '1',
        amountCents: 1000,
        cycle: BillingCycle.monthly,
      );
      expect(monthlyEquivalentCents(s), equals(1000));
    });

    test('quarterly rounds 1000 cents to 333', () {
      final s = _subscription(
        id: '1',
        amountCents: 1000,
        cycle: BillingCycle.quarterly,
      );
      expect(monthlyEquivalentCents(s), equals(333));
    });

    test('yearly rounds 1000 cents to 83', () {
      final s = _subscription(
        id: '1',
        amountCents: 1000,
        cycle: BillingCycle.yearly,
      );
      expect(monthlyEquivalentCents(s), equals(83));
    });
  });

  group('yearlyEquivalentCents', () {
    test('weekly multiplies by 52', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.weekly,
      );
      expect(yearlyEquivalentCents(s), equals(100 * 52));
    });

    test('monthly multiplies by 12', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.monthly,
      );
      expect(yearlyEquivalentCents(s), equals(100 * 12));
    });

    test('quarterly multiplies by 4', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.quarterly,
      );
      expect(yearlyEquivalentCents(s), equals(100 * 4));
    });

    test('yearly returns the amount unchanged', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.yearly,
      );
      expect(yearlyEquivalentCents(s), equals(100));
    });
  });

  group('monthlyTotalsByCurrency', () {
    test('groups two currencies separately, never summed together', () {
      final subscriptions = [
        _subscription(
          id: '1',
          amountCents: 1000,
          currency: 'USD',
          cycle: BillingCycle.monthly,
        ),
        _subscription(
          id: '2',
          amountCents: 500,
          currency: 'EUR',
          cycle: BillingCycle.monthly,
        ),
        _subscription(
          id: '3',
          amountCents: 200,
          currency: 'USD',
          cycle: BillingCycle.monthly,
        ),
      ];

      final totals = monthlyTotalsByCurrency(subscriptions);

      expect(totals, equals({'USD': 1200, 'EUR': 500}));
    });

    test('excludes cancelled subscriptions', () {
      final subscriptions = [
        _subscription(
          id: '1',
          amountCents: 1000,
          cycle: BillingCycle.monthly,
          status: SubscriptionStatus.cancelled,
        ),
      ];

      expect(monthlyTotalsByCurrency(subscriptions), isEmpty);
    });

    test('excludes soft-deleted subscriptions', () {
      final subscriptions = [
        _subscription(
          id: '1',
          amountCents: 1000,
          cycle: BillingCycle.monthly,
          deletedAt: DateTime(2026, 1, 5),
        ),
      ];

      expect(monthlyTotalsByCurrency(subscriptions), isEmpty);
    });

    test('an empty list returns an empty map, not a zero entry', () {
      expect(monthlyTotalsByCurrency([]), equals(<String, int>{}));
    });
  });

  group('chargingSoon', () {
    final from = DateTime(2026, 3, 1);

    test('includes a charge due today', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.monthly,
        nextChargeDate: DateTime(2026, 3, 1),
      );
      expect(chargingSoon([s], from), equals([s]));
    });

    test('includes a charge on the boundary day', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.monthly,
        nextChargeDate: DateTime(2026, 3, 8),
      );
      expect(chargingSoon([s], from, days: 7), equals([s]));
    });

    test('excludes a past charge date', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.monthly,
        nextChargeDate: DateTime(2026, 2, 28),
      );
      expect(chargingSoon([s], from), isEmpty);
    });

    test('excludes a subscription with no next charge date', () {
      final s = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.monthly,
      );
      expect(chargingSoon([s], from), isEmpty);
    });

    test('sorts soonest first', () {
      final later = _subscription(
        id: '1',
        amountCents: 100,
        cycle: BillingCycle.monthly,
        nextChargeDate: DateTime(2026, 3, 6),
      );
      final sooner = _subscription(
        id: '2',
        amountCents: 100,
        cycle: BillingCycle.monthly,
        nextChargeDate: DateTime(2026, 3, 2),
      );

      final result = chargingSoon([later, sooner], from);

      expect(result, equals([sooner, later]));
    });
  });

  group('formatAmount', () {
    test('formats zero', () {
      expect(formatAmount(0), equals('0.00'));
    });

    test('formats 5 cents', () {
      expect(formatAmount(5), equals('0.05'));
    });

    test('formats 1000 cents', () {
      expect(formatAmount(1000), equals('10.00'));
    });

    test('formats 123456 cents', () {
      expect(formatAmount(123456), equals('1234.56'));
    });
  });
}
