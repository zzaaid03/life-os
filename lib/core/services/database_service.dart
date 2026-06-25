/// Local database service using Drift (SQLite).
///
/// Provides offline-first data persistence.
/// Tables will be defined in feature-specific DAOs
/// when data models are implemented in Milestone 3.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart';

/// Opens a database connection with platform-appropriate settings.
///
/// Returns a [QueryExecutor] that connects to a local SQLite database.
/// On web, Drift is not supported — Supabase is used directly.
QueryExecutor openDatabaseConnection() {
  if (kIsWeb) {
    return DatabaseConnection.delayed(
      Future(() async {
        throw UnsupportedError(
          'Drift is not supported on web. '
          'Use Supabase for data persistence on web.',
        );
      }),
    );
  }

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'life_os.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Riverpod provider for the database [QueryExecutor].
///
/// This provides the raw database connection.
/// Feature-specific database classes will wrap this
/// when tables are defined in future milestones.
final databaseConnectionProvider = Provider<QueryExecutor>((ref) {
  return openDatabaseConnection();
});
