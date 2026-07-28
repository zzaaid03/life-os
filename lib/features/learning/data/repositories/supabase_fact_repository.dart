/// Supabase-backed repository for the learning system's inferred facts.
///
/// Read-and-suppress only. Facts are written exclusively by the
/// `infer-facts` Edge Function; nothing in the client creates one. RLS scopes
/// every row to its owner, but each query still filters on `user_id`
/// explicitly, the same convention used by the other repositories.
library;

import 'package:life_os/features/learning/data/models/user_fact.dart';
import 'package:life_os/features/learning/data/repositories/fact_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for [UserFact] records backed by Supabase.
class SupabaseFactRepository implements FactRepository {
  /// Creates a [SupabaseFactRepository].
  SupabaseFactRepository(this._client);

  final SupabaseClient _client;

  /// The Supabase table name.
  static const String _table = 'user_facts';

  /// Fetches this user's live facts, most recently confirmed first.
  ///
  /// Rows whose category this client does not recognise are skipped rather
  /// than crashing the list, so adding a category server-side cannot break an
  /// already-installed app.
  @override
  Future<List<UserFact>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .isFilter('suppressed_at', null)
        .order('last_confirmed_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => UserFact.tryFromJson(row as Map<String, dynamic>))
        .whereType<UserFact>()
        .toList();
  }

  /// Marks [fact] as rejected by the user, permanently.
  ///
  /// Sets `suppressed_at` instead of deleting the row. The row has to survive
  /// so the unique `(user_id, fact_key)` key still matches when the inference
  /// function next derives the same fact: it upserts onto this row, leaves
  /// `suppressed_at` alone, and the fact stays hidden. Deleting the row
  /// instead would let the very next run insert it again.
  @override
  Future<void> suppress(UserFact fact) async {
    await _client
        .from(_table)
        .update({'suppressed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', fact.id)
        .eq('user_id', fact.userId);
  }
}
