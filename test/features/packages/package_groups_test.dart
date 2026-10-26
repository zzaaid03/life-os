import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/domain/package_groups.dart';

Package _p(
  String id, {
  PackageStatus status = PackageStatus.shipped,
  DateTime? expected,
  DateTime? deliveredAt,
  DateTime? deletedAt,
}) {
  return Package(
    id: id,
    status: status,
    expectedDate: expected,
    deliveredAt: deliveredAt,
    deletedAt: deletedAt,
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 26, 12);

  test('on the way sorts by expected date, no date last', () {
    final groups = groupPackages([
      _p('none'),
      _p('late', expected: DateTime(2026, 11, 5)),
      _p('soon', expected: DateTime(2026, 10, 27)),
    ], now);
    expect(groups.onTheWay.map((p) => p.id), ['soon', 'late', 'none']);
  });

  test('delivered splits at 7 days, newest first', () {
    final groups = groupPackages([
      _p(
        'old',
        status: PackageStatus.delivered,
        deliveredAt: now.subtract(const Duration(days: 8)),
      ),
      _p(
        'a',
        status: PackageStatus.delivered,
        deliveredAt: now.subtract(const Duration(days: 3)),
      ),
      _p(
        'b',
        status: PackageStatus.delivered,
        deliveredAt: now.subtract(const Duration(days: 1)),
      ),
      _p('edge', status: PackageStatus.delivered, deliveredAt: now),
    ], now);
    expect(groups.delivered.map((p) => p.id), ['edge', 'b', 'a']);
    expect(groups.older.map((p) => p.id), ['old']);
    expect(groups.onTheWay, isEmpty);
  });

  test('delivered without a date stays recent, deleted ones are dropped', () {
    final groups = groupPackages([
      _p('nodate', status: PackageStatus.delivered),
      _p('gone', deletedAt: now),
    ], now);
    expect(groups.delivered.map((p) => p.id), ['nodate']);
    expect(groups.onTheWay, isEmpty);
    expect(groupPackages([], now).isEmpty, isTrue);
  });
}
