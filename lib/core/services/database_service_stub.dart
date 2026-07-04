/// Database connection stub for web.
///
/// Drift does not support web via FFI. This stub provides
/// a function signature matching [openDatabaseConnection] from
/// the native implementation, but returns a no-op executor.
///
/// On web, Supabase is used directly for all data persistence.
library;

import 'package:drift/drift.dart';

/// Returns a no-op [QueryExecutor] for web.
///
/// Throws [UnsupportedError] if actually used for queries.
QueryExecutor openDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future.error(
      UnsupportedError('Drift is not supported on web. Use Supabase directly.'),
    ),
  );
}
