import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/data/repositories/package_repository.dart';
import 'package:life_os/features/packages/domain/providers/package_provider.dart';
import 'package:life_os/features/packages/presentation/screens/packages_screen.dart';

class _FakePackageRepository extends Fake implements PackageRepository {
  _FakePackageRepository(this.rows, {this.fail = false});

  List<Package> rows;
  bool fail;

  @override
  Future<List<Package>> fetchPackages(String userId) async {
    if (fail) throw StateError('offline');
    return rows;
  }
}

Widget _app(_FakePackageRepository repo) {
  return ProviderScope(
    overrides: [
      packageListProvider.overrideWith((ref) {
        final notifier = PackageListNotifier(repo);
        Future.microtask(() => notifier.load('user-1'));
        return notifier;
      }),
    ],
    child: const MaterialApp(home: PackagesScreen()),
  );
}

void main() {
  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_app(_FakePackageRepository([])));
    await tester.pumpAndSettle();
    expect(
      find.text('No packages yet. Run an inbox scan to find your orders.'),
      findsOneWidget,
    );
  });

  testWidgets('error state shows Retry and recovers', (tester) async {
    final repo = _FakePackageRepository([], fail: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Failed to load packages.'), findsOneWidget);
    expect(
      find.text('No packages yet. Run an inbox scan to find your orders.'),
      findsNothing,
    );

    repo
      ..fail = false
      ..rows = [
        const Package(
          id: '1',
          merchant: 'Amazon',
          status: PackageStatus.shipped,
        ),
      ];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Amazon'), findsOneWidget);
  });

  testWidgets('populated state shows sections, status and fallbacks', (
    tester,
  ) async {
    final repo = _FakePackageRepository([
      Package(
        id: '1',
        merchant: 'Amazon',
        item: 'Shoes',
        carrier: 'DHL',
        trackingNumber: 'JD0146',
        status: PackageStatus.outForDelivery,
        expectedDate: DateTime(2026, 10, 27),
        lastUpdate: 'Out for delivery today.',
      ),
      const Package(id: '2', status: PackageStatus.ordered),
      Package(
        id: '3',
        merchant: 'IKEA',
        status: PackageStatus.delivered,
        deliveredAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      ),
      Package(
        id: '4',
        merchant: 'Zalando',
        status: PackageStatus.delivered,
        deliveredAt: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Delivered'), findsNWidgets(2)); // header + IKEA label
    expect(find.text('Older (1)'), findsOneWidget);
    expect(find.text('Amazon'), findsOneWidget);
    expect(find.text('Package'), findsOneWidget); // no merchant fallback
    expect(find.text('Out for delivery'), findsOneWidget);
    expect(find.text('Expected 27 Oct'), findsOneWidget);
    expect(find.text('DHL · JD0146'), findsOneWidget);
    expect(find.text('Zalando'), findsNothing); // collapsed
  });
}
