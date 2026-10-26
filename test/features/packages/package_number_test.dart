import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/packages/domain/package_number.dart';

void main() {
  group('normalizePackageNumber', () {
    test('strips a leading #', () {
      expect(normalizePackageNumber('#123'), '123');
      expect(normalizePackageNumber('# 123'), '123');
    });

    test('strips a leading No. / No / Nr. label', () {
      expect(normalizePackageNumber('No. 123'), '123');
      expect(normalizePackageNumber('nr.123'), '123');
      expect(normalizePackageNumber('No 123'), '123');
      expect(normalizePackageNumber('Nr. #123'), '123');
    });

    test('drops spaces and uppercases', () {
      expect(normalizePackageNumber('12 34'), '1234');
      expect(normalizePackageNumber('1z999aa1'), '1Z999AA1');
    });

    test('keeps letters that only look like a label', () {
      expect(normalizePackageNumber('NORD123'), 'NORD123');
    });

    test('accepts numbers, rejects other types and empties', () {
      expect(normalizePackageNumber(123), '123');
      expect(normalizePackageNumber(null), isNull);
      expect(normalizePackageNumber('  '), isNull);
      expect(normalizePackageNumber('#'), isNull);
    });

    test('caps at 60 characters', () {
      expect(normalizePackageNumber('a' * 100)!.length, 60);
    });
  });
}
