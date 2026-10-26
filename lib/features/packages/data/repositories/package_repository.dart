/// Repository interface for packages.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/data/repositories/supabase_package_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for packages.
abstract class PackageRepository {
  /// The user's live (not deleted) packages, newest update first.
  Future<List<Package>> fetchPackages(String userId);

  /// Marks the package delivered, stamping `delivered_at` now. Throws when no
  /// row was changed.
  Future<void> markDelivered(String id);

  /// Soft-deletes the package. Throws when no row was changed.
  Future<void> softDelete(String id);

  /// Undoes [softDelete]. Throws when no row was changed.
  Future<void> restore(String id);

  /// Matches scan-derived [updates] against the user's packages and writes
  /// the result: new packages are inserted, known ones updated. Returns how
  /// many packages were inserted or visibly changed. Throws when any write
  /// does not land.
  Future<int> applyScanUpdates(List<PackageUpdate> updates, String userId);
}

/// Provides the [PackageRepository].
final packageRepositoryProvider = Provider<PackageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabasePackageRepository(client);
});
