/// Drift database for Life OS.
///
/// Provides offline-first local storage using SQLite.
/// Tables are added incrementally as features are implemented.
library;

import 'package:drift/drift.dart';
import 'package:life_os/core/services/database_service_stub.dart'
    if (dart.library.io) 'package:life_os/core/services/database_service_native.dart'
    as native;

part 'app_database.g.dart';

/// Drift table definition for tasks.
@DataClassName('TaskEntry')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();
  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get parentTaskId => text().named('parent_task_id').nullable()();
  TextColumn get goalId => text().named('goal_id').nullable()();
  RealColumn get sortOrder =>
      real().named('sort_order').withDefault(const Constant(0.0))();
  DateTimeColumn get syncedAt => dateTime().named('synced_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The Drift database instance for Life OS.
@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  /// Creates an [AppDatabase] with the default connection.
  AppDatabase() : super(native.openDatabaseConnection());

  /// Creates an [AppDatabase] with a custom [executor] (for testing).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(tasks, tasks.goalId);
        }
      },
    );
  }
}
