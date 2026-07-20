/// Supabase-backed repository for job applications.
///
/// Reads and upserts rows in the `public.job_applications` table. RLS
/// ensures each user only ever sees and writes their own rows, but every
/// query is still scoped by `user_id` explicitly for clarity.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for [JobApplication] records backed by Supabase.
class JobApplicationRepository {
  /// Creates a [JobApplicationRepository].
  const JobApplicationRepository(this._client);

  final SupabaseClient _client;

  /// The Supabase table name.
  static const String _table = 'job_applications';

  /// Upserts a batch of scan-derived [JobUpdate]s for [userId] without ever
  /// creating duplicates.
  ///
  /// Identity rules (mirroring migration 010's partial unique indexes):
  /// - update WITH a company → identified by `(user_id, company, role)`;
  ///   a later email about the same application updates status/summary.
  /// - update WITHOUT a company → identified by `(user_id, source_email_id)`
  ///   so re-scanning the same email updates the same row.
  /// - no company AND no email id → inserted as-is (nothing to key on).
  ///
  /// Writes are explicit select-then-insert/update because PostgREST's
  /// upsert cannot target partial unique indexes.
  Future<void> upsertFromScan(List<JobUpdate> updates, String userId) async {
    for (final update in updates) {
      final values = {
        'status': update.status,
        'summary': update.summary,
        'source_email_id': update.sourceEmailId,
      };

      if (update.company.isNotEmpty) {
        final existing = await _client
            .from(_table)
            .select('id')
            .eq('user_id', userId)
            .eq('company', update.company)
            .eq('role', update.role)
            .maybeSingle();

        if (existing != null) {
          await _client
              .from(_table)
              .update(values)
              .eq('id', existing['id'] as String);
        } else {
          await _client.from(_table).insert({
            'user_id': userId,
            'company': update.company,
            'role': update.role,
            ...values,
          });
        }
        continue;
      }

      final emailId = update.sourceEmailId;
      if (emailId != null && emailId.isNotEmpty) {
        final existing = await _client
            .from(_table)
            .select('id')
            .eq('user_id', userId)
            .eq('company', '')
            .eq('source_email_id', emailId)
            .maybeSingle();

        if (existing != null) {
          await _client
              .from(_table)
              .update(values)
              .eq('id', existing['id'] as String);
        } else {
          await _client.from(_table).insert({
            'user_id': userId,
            'company': '',
            'role': update.role,
            ...values,
          });
        }
        continue;
      }

      // No identity available — persist it anyway so the update isn't lost.
      await _client.from(_table).insert({
        'user_id': userId,
        'company': '',
        'role': update.role,
        ...values,
      });
    }
  }

  /// Fetches all job applications for [userId], most recently updated first.
  Future<List<JobApplication>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(JobApplication.fromJson)
        .toList();
  }
}

/// Provides the [JobApplicationRepository].
final jobApplicationRepositoryProvider = Provider<JobApplicationRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return JobApplicationRepository(client);
});
