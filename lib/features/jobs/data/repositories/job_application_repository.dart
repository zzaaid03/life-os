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

  /// Upserts a batch of scan-derived [JobUpdate]s for [userId].
  ///
  /// Conflicts on `(user_id, company, role)` update the existing row's
  /// status/summary/source rather than inserting a duplicate. Timestamps are
  /// left to the database defaults. Updates missing a company or role are
  /// skipped, since the unique constraint requires both.
  Future<void> upsertFromScan(List<JobUpdate> updates, String userId) async {
    final rows = updates
        .where((u) => u.company.isNotEmpty && u.role.isNotEmpty)
        .map(
          (u) => {
            'user_id': userId,
            'company': u.company,
            'role': u.role,
            'status': u.status,
            'summary': u.summary,
            'source_email_id': u.sourceEmailId,
          },
        )
        .toList();

    if (rows.isEmpty) return;

    await _client.from(_table).upsert(rows, onConflict: 'user_id,company,role');
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
