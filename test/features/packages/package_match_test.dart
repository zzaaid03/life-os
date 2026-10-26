import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/domain/package_match.dart';

final _now = DateTime.utc(2026, 10, 26, 12);

PackageUpdate _update({
  String? tracking,
  String? order,
  PackageStatus status = PackageStatus.ordered,
  String? merchant,
  DateTime? expected,
  String email = 'e1',
}) {
  return PackageUpdate(
    merchant: merchant,
    trackingNumber: tracking,
    orderNumber: order,
    status: status,
    expectedDate: expected,
    summary: 'update $email',
    sourceEmailId: email,
  );
}

void main() {
  group('matchPackageUpdates', () {
    test('ordered then shipped on the same order is one package with tracking',
        () {
      final first = matchPackageUpdates(
        const [],
        [_update(order: 'A1', merchant: 'Shop')],
        now: _now,
      );
      expect(first.inserts, hasLength(1));
      final stored = first.inserts.single.copyWith();
      final existing = Package(
        id: 'p1',
        merchant: stored.merchant,
        orderNumber: stored.orderNumber,
        status: stored.status,
      );

      final second = matchPackageUpdates(
        [existing],
        [_update(order: 'A1', tracking: 'T1', status: PackageStatus.shipped)],
        now: _now,
      );
      expect(second.inserts, isEmpty);
      expect(second.updates, hasLength(1));
      expect(second.updates.single.id, 'p1');
      expect(second.updates.single.trackingNumber, 'T1');
      expect(second.updates.single.status, PackageStatus.shipped);
      expect(second.updates.single.merchant, 'Shop');
    });

    test('a second tracking number on the same order is a new package', () {
      const existing = Package(
        id: 'p1',
        orderNumber: 'A1',
        trackingNumber: 'T1',
        status: PackageStatus.shipped,
      );
      final changes = matchPackageUpdates(
        [existing],
        [_update(order: 'A1', tracking: 'T2', status: PackageStatus.shipped)],
        now: _now,
      );
      expect(changes.updates, isEmpty);
      expect(changes.inserts, hasLength(1));
      expect(changes.inserts.single.trackingNumber, 'T2');
    });

    test('status never goes backwards', () {
      const existing = Package(
        id: 'p1',
        trackingNumber: 'T1',
        status: PackageStatus.outForDelivery,
      );
      final changes = matchPackageUpdates(
        [existing],
        [_update(tracking: 'T1', status: PackageStatus.shipped)],
        now: _now,
      );
      expect(changes.updates.single.status, PackageStatus.outForDelivery);
    });

    test('delivered stamps delivered_at once', () {
      const existing = Package(
        id: 'p1',
        trackingNumber: 'T1',
        status: PackageStatus.shipped,
      );
      final changes = matchPackageUpdates(
        [existing],
        [_update(tracking: 'T1', status: PackageStatus.delivered)],
        now: _now,
      );
      expect(changes.updates.single.deliveredAt, _now);
    });

    test('a deleted match is skipped, not revived or duplicated', () {
      final existing = Package(
        id: 'p1',
        trackingNumber: 'T1',
        status: PackageStatus.shipped,
        deletedAt: DateTime.utc(2026, 10, 1),
      );
      final changes = matchPackageUpdates(
        [existing],
        [_update(tracking: 'T1', status: PackageStatus.delivered)],
        now: _now,
      );
      expect(changes.inserts, isEmpty);
      expect(changes.updates, isEmpty);
    });

    test('two updates in one batch for the same new package insert once', () {
      final changes = matchPackageUpdates(
        const [],
        [
          _update(order: 'A1', email: 'e1'),
          _update(
            order: 'A1',
            tracking: 'T1',
            status: PackageStatus.shipped,
            email: 'e2',
          ),
        ],
        now: _now,
      );
      expect(changes.updates, isEmpty);
      expect(changes.inserts, hasLength(1));
      expect(changes.inserts.single.trackingNumber, 'T1');
      expect(changes.inserts.single.status, PackageStatus.shipped);
      expect(changes.inserts.single.sourceEmailId, 'e2');
    });

    test('expected date is replaced while undelivered', () {
      final existing = Package(
        id: 'p1',
        trackingNumber: 'T1',
        status: PackageStatus.shipped,
        expectedDate: DateTime(2026, 10, 28),
      );
      final changes = matchPackageUpdates(
        [existing],
        [
          _update(
            tracking: 'T1',
            status: PackageStatus.shipped,
            expected: DateTime(2026, 10, 30),
          ),
        ],
        now: _now,
      );
      expect(changes.updates.single.expectedDate, DateTime(2026, 10, 30));
    });

    test('a stored #305-... order matches an update with 305-...', () {
      const existing = Package(
        id: 'p1',
        orderNumber: '#305-7712094-8830215',
        status: PackageStatus.ordered,
      );
      final changes = matchPackageUpdates(
        [existing],
        [
          _update(
            order: '305-7712094-8830215',
            status: PackageStatus.shipped,
          ),
        ],
        now: _now,
      );
      expect(changes.inserts, isEmpty);
      expect(changes.updates.single.id, 'p1');
      expect(changes.changedCount, 1);
    });

    test('changedCount counts inserts and real changes, not repeats', () {
      const existing = Package(
        id: 'p1',
        trackingNumber: 'T1',
        status: PackageStatus.shipped,
        lastUpdate: 'update e1',
      );
      final changes = matchPackageUpdates(
        [existing],
        [
          _update(tracking: 'T1', status: PackageStatus.shipped, email: 'e1'),
          _update(order: 'NEW1', email: 'e2'),
        ],
        now: _now,
      );
      expect(changes.inserts, hasLength(1));
      expect(changes.changedCount, 1);
    });

    test('an older ordered email after a shipped one keeps the shipped details',
        () {
      final changes = matchPackageUpdates(
        const [],
        [
          _update(
            order: 'A1',
            status: PackageStatus.shipped,
            email: 'shipped',
          ),
          _update(order: 'A1', email: 'ordered'),
        ],
        now: _now,
      );
      expect(changes.inserts, hasLength(1));
      final pkg = changes.inserts.single;
      expect(pkg.status, PackageStatus.shipped);
      expect(pkg.lastUpdate, 'update shipped');
      expect(pkg.sourceEmailId, 'shipped');
    });

    test('same status twice: the second summary wins', () {
      final changes = matchPackageUpdates(
        const [],
        [
          _update(order: 'A1', email: 'first'),
          _update(order: 'A1', email: 'second'),
        ],
        now: _now,
      );
      final pkg = changes.inserts.single;
      expect(pkg.lastUpdate, 'update second');
      expect(pkg.sourceEmailId, 'second');
    });

    test('an ordered email does not touch a shipped row', () {
      final existing = Package(
        id: 'p1',
        orderNumber: 'A1',
        status: PackageStatus.shipped,
        expectedDate: DateTime(2026, 10, 28),
        lastUpdate: 'Shipped by DHL',
        sourceEmailId: 'shipped',
      );
      final changes = matchPackageUpdates(
        [existing],
        [_update(order: 'A1', expected: DateTime(2026, 11, 2))],
        now: _now,
      );
      final pkg = changes.updates.single;
      expect(pkg.status, PackageStatus.shipped);
      expect(pkg.lastUpdate, 'Shipped by DHL');
      expect(pkg.expectedDate, DateTime(2026, 10, 28));
      expect(pkg.sourceEmailId, 'shipped');
    });
  });
}
