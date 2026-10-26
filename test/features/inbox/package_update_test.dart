import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/models/package.dart';

Map<String, dynamic> _json([Map<String, dynamic> overrides = const {}]) {
  return {
    'merchant': 'Shop',
    'item': 'Shoes',
    'carrier': 'DHL',
    'trackingNumber': 'T1',
    'orderNumber': 'O1',
    'status': 'shipped',
    'expectedDate': '2026-10-30',
    'summary': 'Shipped.',
    'sourceEmailId': 'msg-1',
    ...overrides,
  };
}

void main() {
  group('PackageUpdate.tryParse', () {
    test('maps a full valid payload', () {
      final u = PackageUpdate.tryParse(_json())!;
      expect(u.status, PackageStatus.shipped);
      expect(u.expectedDate, DateTime(2026, 10, 30));
      expect(u.sourceEmailId, 'msg-1');
    });

    test('drops an unknown status', () {
      expect(PackageUpdate.tryParse(_json({'status': 'lost'})), isNull);
      expect(PackageUpdate.tryParse(_json({'status': null})), isNull);
    });

    test('drops an update with neither tracking nor order number', () {
      expect(
        PackageUpdate.tryParse(
          _json({'trackingNumber': '  ', 'orderNumber': null}),
        ),
        isNull,
      );
    });

    test('drops an update without a source email id', () {
      expect(PackageUpdate.tryParse(_json({'sourceEmailId': null})), isNull);
    });

    test('normalizes numbers: trim, no spaces, uppercase', () {
      final u = PackageUpdate.tryParse(
        _json({'trackingNumber': ' 1z 999 aa1 ', 'orderNumber': '  '}),
      )!;
      expect(u.trackingNumber, '1Z999AA1');
      expect(u.orderNumber, isNull);
    });

    test('caps strings to the column limits', () {
      final u = PackageUpdate.tryParse(
        _json({
          'merchant': 'm' * 300,
          'item': 'i' * 300,
          'carrier': 'c' * 300,
          'trackingNumber': 't' * 300,
          'summary': 's' * 500,
        }),
      )!;
      expect(u.merchant, hasLength(120));
      expect(u.item, hasLength(200));
      expect(u.carrier, hasLength(60));
      expect(u.trackingNumber, hasLength(60));
      expect(u.summary, hasLength(300));
    });

    test('an impossible date becomes null', () {
      final u = PackageUpdate.tryParse(_json({'expectedDate': '2026-02-31'}))!;
      expect(u.expectedDate, isNull);
    });
  });

  group('ScanResult.fromJson packages', () {
    test('missing or non-list key is empty', () {
      expect(ScanResult.fromJson({}).packages, isEmpty);
      expect(ScanResult.fromJson({'packages': 'x'}).packages, isEmpty);
    });

    test('keeps valid entries and drops bad ones', () {
      final r = ScanResult.fromJson({
        'packages': [_json(), _json({'status': 'nope'})],
      });
      expect(r.packages, hasLength(1));
    });
  });
}
