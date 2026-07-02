/// Database connection — native (Android, iOS, desktop).
///
/// Provides a real SQLite database via Drift for
/// offline-first data persistence.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart';

/// Opens a native SQLite database connection.
QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'life_os.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Riverpod provider for the database [QueryExecutor].
final databaseConnectionProvider = Provider<QueryExecutor>((ref) {
  return openDatabaseConnection();
});
