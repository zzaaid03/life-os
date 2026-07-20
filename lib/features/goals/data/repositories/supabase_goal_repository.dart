/// Supabase implementation of [GoalRepository].
///
/// Remote-only CRUD against the `goals` table (RLS-scoped per user).
/// Deletes are soft (set `deleted_at`) to match the entity model.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed [GoalRepository].
class SupabaseGoalRepository implements GoalRepository {
  /// Creates a [SupabaseGoalRepository].
  const SupabaseGoalRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'goals';

  @override
  Future<Goal?> getById(String id) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return Goal.fromJson(response);
  }

  @override
  Future<List<Goal>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('created_at');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Goal.fromJson)
        .toList();
  }

  @override
  Future<Goal> create(Goal goal) async {
    final response = await _client
        .from(_table)
        .insert(goal.toJson())
        .select()
        .single();
    return Goal.fromJson(response);
  }

  @override
  Future<Goal> update(Goal goal) async {
    final response = await _client
        .from(_table)
        .update(goal.toJson())
        .eq('id', goal.id)
        .select()
        .single();
    return Goal.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _client
        .from(_table)
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  @override
  Future<void> purge(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

/// Provides the [GoalRepository].
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseGoalRepository(client);
});
