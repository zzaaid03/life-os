import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/data/entity.dart';

void main() {
  group('SyncStatus enum', () {
    test('has all expected values', () {
      expect(SyncStatus.values, hasLength(6));
      expect(SyncStatus.synced.name, equals('synced'));
      expect(SyncStatus.pendingPush.name, equals('pendingPush'));
      expect(SyncStatus.pendingCreate.name, equals('pendingCreate'));
      expect(SyncStatus.pendingPull.name, equals('pendingPull'));
      expect(SyncStatus.conflict.name, equals('conflict'));
      expect(SyncStatus.failed.name, equals('failed'));
    });

    test('can be parsed from name', () {
      expect(
        SyncStatus.values.firstWhere((s) => s.name == 'synced'),
        equals(SyncStatus.synced),
      );
      expect(
        SyncStatus.values.firstWhere((s) => s.name == 'failed'),
        equals(SyncStatus.failed),
      );
    });
  });
}
