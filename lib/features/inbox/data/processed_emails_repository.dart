/// Processed-emails repository.
///
/// Tracks which Gmail message ids have already been surfaced as task
/// suggestions so a re-scan never re-suggests something the user has
/// already added or dismissed. Only opaque Gmail ids are stored.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for the `processed_emails` table.
class ProcessedEmailsRepository {
  /// Creates a [ProcessedEmailsRepository].
  const ProcessedEmailsRepository(this._client);

  final SupabaseClient _client;

  /// The Supabase table name.
  static const String _table = 'processed_emails';

  /// Returns the subset of [emailIds] already processed for [userId].
  Future<Set<String>> getProcessedIds(
    String userId,
    List<String> emailIds,
  ) async {
    if (emailIds.isEmpty) return const {};
    final response = await _client
        .from(_table)
        .select('email_id')
        .eq('user_id', userId)
        .inFilter('email_id', emailIds);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => row['email_id'] as String)
        .toSet();
  }

  /// Records [emailIds] as processed for [userId] (idempotent).
  Future<void> markProcessed(String userId, List<String> emailIds) async {
    if (emailIds.isEmpty) return;
    final rows = emailIds
        .toSet()
        .map((id) => {'user_id': userId, 'email_id': id})
        .toList();
    await _client.from(_table).upsert(rows, onConflict: 'user_id,email_id');
  }
}

/// Provides the [ProcessedEmailsRepository].
final processedEmailsRepositoryProvider = Provider<ProcessedEmailsRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return ProcessedEmailsRepository(client);
});
