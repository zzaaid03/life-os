import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/utils/date_format.dart';

void main() {
  group('formatDay', () {
    test('renders a single-digit day with no leading zero', () {
      expect(formatDay(DateTime(2026, 1, 9)), '9 Jan');
    });

    test('renders a double-digit day', () {
      expect(formatDay(DateTime(2026, 8, 18)), '18 Aug');
    });

    test('renders January correctly', () {
      expect(formatDay(DateTime(2026, 1, 1)), '1 Jan');
    });

    test('renders December correctly', () {
      expect(formatDay(DateTime(2026, 12, 31)), '31 Dec');
    });
  });

  group('localDateString', () {
    test('zero-pads month and day', () {
      expect(localDateString(DateTime(2026, 1, 9, 14)), '2026-01-09');
    });

    test('a time just after local midnight stays on the new day', () {
      expect(localDateString(DateTime(2026, 10, 23, 0, 1)), '2026-10-23');
    });

    test('a time just before local midnight stays on the old day', () {
      expect(localDateString(DateTime(2026, 10, 22, 23, 59)), '2026-10-22');
    });
  });

  group('formatDayTime', () {
    test('zero-pads a minute below 10', () {
      expect(formatDayTime(DateTime(2026, 8, 18, 14, 5)), '18 Aug at 14:05');
    });

    test('does not pad a minute at or above 10', () {
      expect(formatDayTime(DateTime(2026, 8, 18, 9, 30)), '18 Aug at 9:30');
    });
  });
}
