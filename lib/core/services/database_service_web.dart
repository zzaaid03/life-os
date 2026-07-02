/// Database connection — web stub.
///
/// Drift does not support web. This stub prevents the
/// platform plugin from crashing on web startup.
///
/// Web users rely on Supabase directly for data persistence.
library;

import 'package:drift/drift.dart';
import 'package:riverpod/riverpod.dart';

/// Provides a no-op QueryExecutor for web.
///
/// Throws [UnsupportedError] if actually used for queries.
/// This prevents the sqlite3 native plugin from loading on web.
QueryExecutor openDatabaseConnection() {
  return DatabaseConnection.delayed(
    Future.error(
      UnsupportedError(
        'Drift is not supported on web. '
        'Use Supabase for data persistence on web.',
      ),
    ),
  );
}

/// Provider that returns null on web — Supabase is the data source.
final databaseConnectionProvider = Provider<QueryExecutor>((ref) {
  return openDatabaseConnection();
});
