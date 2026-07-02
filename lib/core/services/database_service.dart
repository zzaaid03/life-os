/// Local database service using Drift (SQLite).
///
/// Provides offline-first data persistence on native platforms.
/// On web, Supabase is used directly — Drift is not supported.
///
/// Uses conditional exports to prevent sqlite3 native plugin
/// from crashing on web startup.
library;

export 'database_service_native.dart'
    if (dart.library.html) 'database_service_web.dart';
