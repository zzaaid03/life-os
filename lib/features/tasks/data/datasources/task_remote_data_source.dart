/// Supabase-backed remote data source for tasks.
///
/// Provides online CRUD operations against the `tasks` table in
/// Supabase. Conversion between Supabase JSON responses and the
/// [Task] domain model is handled by [Task.fromJson] / [Task.toJson].
library;

import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The remote calls the sync engine needs. Lets tests swap in a fake.
abstract interface class TaskSyncRemote {
  /// Upserts a task to the server.
  Future<Task> upsert(Task task);

  /// Fetches one page of tasks for [userId], ordered by `updated_at` then `id`.
  ///
  /// Without [cursor]: rows updated at or after [since]. With [cursor] (the
  /// last row of the previous page): rows strictly after it in that order,
  /// so a row updated mid-pull can't make a later page skip another row.
  Future<List<Task>> getSince(
    String userId,
    DateTime since, {
    ({DateTime updatedAt, String id})? cursor,
    required int limit,
  });
}

/// Remote data source for [Task] records backed by Supabase.
class TaskRemoteDataSource implements TaskSyncRemote {
  /// Creates a [TaskRemoteDataSource] with the given [SupabaseClient].
  const TaskRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// The Supabase table name for tasks.
  static const String _table = 'tasks';

  /// The PostgREST `or` filter for rows strictly after ([updatedAt], [id]).
  /// Values are double-quoted so `:` and `.` can't be read as syntax.
  static String keysetFilter(DateTime updatedAt, String id) {
    final ts = updatedAt.toUtc().toIso8601String();
    return 'updated_at.gt."$ts",and(updated_at.eq."$ts",id.gt."$id")';
  }

  /// Fetches a single task by [id], or `null` if not found.
  Future<Task?> getById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Task.fromJson(response);
  }

  /// Fetches all non-deleted tasks for the given [userId].
  ///
  /// Pages through the table 1000 rows at a time, because PostgREST silently
  /// cuts a single response off at 1000. The order is by id so pages never
  /// overlap or skip a row.
  Future<List<Task>> getAll(String userId) async {
    const pageSize = 1000;
    final tasks = <Task>[];
    var from = 0;
    while (true) {
      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('id')
          .range(from, from + pageSize - 1);
      final page = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Task.fromJson)
          .toList();
      tasks.addAll(page);
      if (page.length < pageSize) return tasks;
      from += pageSize;
    }
  }

  @override
  Future<List<Task>> getSince(
    String userId,
    DateTime since, {
    ({DateTime updatedAt, String id})? cursor,
    required int limit,
  }) async {
    var query = _client.from(_table).select().eq('user_id', userId);
    if (cursor == null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    } else {
      query = query.or(keysetFilter(cursor.updatedAt, cursor.id));
    }
    final response = await query.order('updated_at').order('id').limit(limit);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  /// Upserts a task to the `tasks` table.
  ///
  /// Returns the task as returned by the server, or the original
  /// [task] if no row is returned.
  @override
  Future<Task> upsert(Task task) async {
    final response = await _client
        .from(_table)
        .upsert(task.toJson())
        .select()
        .maybeSingle();
    if (response == null) return task;
    return Task.fromJson(response);
  }

  /// Soft-deletes a task by setting `deleted_at` to now.
  Future<void> delete(String id) async {
    await _client
        .from(_table)
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
