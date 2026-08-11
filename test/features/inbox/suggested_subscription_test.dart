import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';

void main() {
  group('SuggestedSubscription.fromJson', () {
    test('maps every field from a full valid payload', () {
      final s = SuggestedSubscription.fromJson({
        'name': 'Netflix',
        'amount': '15.49',
        'currency': 'usd',
        'cycle': 'monthly',
        'nextChargeDate': '2026-09-01',
        'sourceEmailId': 'msg-1',
      });

      expect(s.name, equals('Netflix'));
      expect(s.amountCents, equals(1549));
      expect(s.currency, equals('USD'));
      expect(s.cycle, equals(BillingCycle.monthly));
      expect(s.nextChargeDate, equals(DateTime(2026, 9, 1)));
      expect(s.sourceEmailId, equals('msg-1'));
    });

    test('parses a JSON number amount, not just a string', () {
      final s = SuggestedSubscription.fromJson({'name': 'Spotify', 'amount': 9.99});
      expect(s.amountCents, equals(999));
    });

    group('currency', () {
      test('lowercase eur normalises to EUR', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': 'eur'});
        expect(s.currency, equals('EUR'));
      });

      test('uppercase EUR stays EUR', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': 'EUR'});
        expect(s.currency, equals('EUR'));
      });

      test('a dollar sign is null, not resolved to USD', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': r'$'});
        expect(s.currency, isNull);
      });

      test('a euro sign is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': '€'});
        expect(s.currency, isNull);
      });

      test('a word is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': 'dollars'});
        expect(s.currency, isNull);
      });

      test('a two-letter code is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': 'US'});
        expect(s.currency, isNull);
      });

      test('a non-string value is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'currency': 42});
        expect(s.currency, isNull);
      });

      test('a missing key is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X'});
        expect(s.currency, isNull);
      });
    });

    group('cycle', () {
      test('weekly parses', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': 'weekly'});
        expect(s.cycle, equals(BillingCycle.weekly));
      });

      test('monthly parses', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': 'monthly'});
        expect(s.cycle, equals(BillingCycle.monthly));
      });

      test('quarterly parses', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': 'quarterly'});
        expect(s.cycle, equals(BillingCycle.quarterly));
      });

      test('yearly parses', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': 'yearly'});
        expect(s.cycle, equals(BillingCycle.yearly));
      });

      test('annually is null, it does not fall back to monthly', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': 'annually'});
        expect(s.cycle, isNull);
      });

      test('a phrase is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': 'every month'});
        expect(s.cycle, isNull);
      });

      test('an empty string is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X', 'cycle': ''});
        expect(s.cycle, isNull);
      });

      test('a missing key is null, it does not fall back to monthly', () {
        final s = SuggestedSubscription.fromJson({'name': 'X'});
        expect(s.cycle, isNull);
      });
    });

    group('nextChargeDate', () {
      test('parses a plain ISO date to local midnight', () {
        final s = SuggestedSubscription.fromJson({
          'name': 'X',
          'nextChargeDate': '2026-09-01',
        });
        expect(s.nextChargeDate, equals(DateTime(2026, 9, 1)));
      });

      test('a rolled-over date is null', () {
        final s = SuggestedSubscription.fromJson({
          'name': 'X',
          'nextChargeDate': '2026-02-31',
        });
        expect(s.nextChargeDate, isNull);
      });

      test('day-month-year order is null', () {
        final s = SuggestedSubscription.fromJson({
          'name': 'X',
          'nextChargeDate': '01-09-2026',
        });
        expect(s.nextChargeDate, isNull);
      });

      test('unpadded month and day is null', () {
        final s = SuggestedSubscription.fromJson({
          'name': 'X',
          'nextChargeDate': '2026-9-1',
        });
        expect(s.nextChargeDate, isNull);
      });

      test('a missing key is null', () {
        final s = SuggestedSubscription.fromJson({'name': 'X'});
        expect(s.nextChargeDate, isNull);
      });
    });

    test('a missing name yields an empty string, not a throw', () {
      final s = SuggestedSubscription.fromJson({});
      expect(s.name, equals(''));
    });
  });

  group('ScanResult.fromJson subscriptions', () {
    test('a missing subscriptions key gives an empty list and does not throw', () {
      final result = ScanResult.fromJson({
        'tasks': <dynamic>[],
        'jobUpdates': <dynamic>[],
      });
      expect(result.subscriptions, isEmpty);
    });

    test('a suggestion with a blank name is filtered out', () {
      final result = ScanResult.fromJson({
        'tasks': <dynamic>[],
        'jobUpdates': <dynamic>[],
        'subscriptions': <dynamic>[
          {'name': '', 'amount': '9.99'},
          {'name': 'Netflix', 'amount': '15.49'},
        ],
      });

      expect(result.subscriptions, hasLength(1));
      expect(result.subscriptions.single.name, equals('Netflix'));
    });
  });
}
