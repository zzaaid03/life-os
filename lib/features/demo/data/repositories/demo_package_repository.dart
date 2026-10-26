/// In-memory demo override of [PackageRepository]: never touches Supabase.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/repositories/package_repository.dart';

/// A [PackageRepository] that accepts scan updates and stores nothing, since
/// demo mode has no Packages screen to show them on yet.
class DemoPackageRepository implements PackageRepository {
  /// Creates a [DemoPackageRepository].
  const DemoPackageRepository();

  @override
  Future<void> applyScanUpdates(
    List<PackageUpdate> updates,
    String userId,
  ) async {}
}
