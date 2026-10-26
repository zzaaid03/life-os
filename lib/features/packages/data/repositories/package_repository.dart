/// Repository interface for packages.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/repositories/supabase_package_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for packages.
abstract class PackageRepository {
  /// Matches scan-derived [updates] against the user's packages and writes
  /// the result: new packages are inserted, known ones updated. Throws when
  /// any write does not land.
  Future<void> applyScanUpdates(List<PackageUpdate> updates, String userId);
}

/// Provides the [PackageRepository].
final packageRepositoryProvider = Provider<PackageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabasePackageRepository(client);
});
