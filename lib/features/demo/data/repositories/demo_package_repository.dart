/// In-memory demo override of [PackageRepository]: never touches Supabase.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/data/repositories/package_repository.dart';

/// A [PackageRepository] that keeps a few sample packages in memory. Scan
/// updates are accepted and stored nowhere.
class DemoPackageRepository implements PackageRepository {
  /// Creates a [DemoPackageRepository].
  DemoPackageRepository() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _rows = [
      Package(
        id: 'demo-pkg-1',
        merchant: 'Amazon',
        item: 'Running shoes',
        carrier: 'DHL',
        trackingNumber: 'JD014600003SE',
        status: PackageStatus.outForDelivery,
        expectedDate: today,
        lastUpdate: 'Your parcel is out for delivery today.',
      ),
      Package(
        id: 'demo-pkg-2',
        merchant: 'Zalando',
        item: 'Winter jacket',
        carrier: 'Hermes',
        orderNumber: 'ZL4417820',
        status: PackageStatus.shipped,
        expectedDate: today.add(const Duration(days: 3)),
        lastUpdate: 'Your order has been handed to the carrier.',
      ),
      Package(
        id: 'demo-pkg-3',
        merchant: 'IKEA',
        item: 'Desk lamp',
        status: PackageStatus.delivered,
        deliveredAt: now.toUtc().subtract(const Duration(days: 2)),
        lastUpdate: 'Delivered to your door.',
      ),
    ];
  }

  late List<Package> _rows;
  final Set<String> _deleted = {};

  @override
  Future<int> applyScanUpdates(
    List<PackageUpdate> updates,
    String userId,
  ) async => 0;

  @override
  Future<List<Package>> fetchPackages(String userId) async => [
    for (final p in _rows)
      if (!_deleted.contains(p.id)) p,
  ];

  @override
  Future<void> markDelivered(String id) async {
    _rows = [
      for (final p in _rows)
        if (p.id == id)
          p.copyWith(
            status: PackageStatus.delivered,
            deliveredAt: DateTime.now().toUtc(),
          )
        else
          p,
    ];
  }

  @override
  Future<void> softDelete(String id) async => _deleted.add(id);

  @override
  Future<void> restore(String id) async => _deleted.remove(id);
}
