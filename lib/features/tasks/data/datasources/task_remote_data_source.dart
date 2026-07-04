/// Supabase-backed remote data source for tasks.
///
/// Provides online CRUD operations against the `tasks` table in
/// Supabase. Conversion between Supabase JSON responses and the
/// [Task] domain model is handled by [Task.fromJson] / [Task.toJson].
library;

import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote data source for [Task] records backed by Supabase.
class TaskRemoteDataSource {
  /// Creates a [TaskRemoteDataSource] with the given [SupabaseClient].
  const TaskRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// The Supabase table name for tasks.
  static const String _table = 'tasks';

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
  Future<List<Task>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  /// Fetches tasks for [userId] updated after [lastSync].
  Future<List<Task>> getSince(String userId, DateTime lastSync) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSync.toIso8601String());
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Task.fromJson)
        .toList();
  }

  /// Upserts a task to the `tasks` table.
  ///
  /// Returns the task as returned by the server, or the original
  /// [task] if no row is returned.
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
