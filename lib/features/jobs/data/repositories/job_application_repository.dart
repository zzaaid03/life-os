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

  /// Returns the id of the existing row [update] refers to, using the same
  /// identity rules as [upsertFromScan], or `null` if there is no match.
  Future<String?> _findExistingId(JobUpdate update, String userId) async {
    if (update.company.isNotEmpty) {
      final existing = await _client
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .eq('company', update.company)
          .eq('role', update.role)
          .maybeSingle();
      return existing?['id'] as String?;
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
      return existing?['id'] as String?;
    }

    return null;
  }

  /// Option B: auto-applies status/summary to job updates that match an
  /// EXISTING application, and returns the updates that refer to a brand-new
  /// application (no matching row) so the UI can confirm before adding them.
  Future<List<JobUpdate>> applyKnownAndCollectNew(
    List<JobUpdate> updates,
    String userId,
  ) async {
    final newOnes = <JobUpdate>[];

    for (final update in updates) {
      final id = await _findExistingId(update, userId);

      if (id != null) {
        await _client
            .from(_table)
            .update({
              'status': update.status,
              'summary': update.summary,
              'source_email_id': update.sourceEmailId,
            })
            .eq('id', id);
      } else {
        newOnes.add(update);
      }
    }

    return newOnes;
  }

  /// Creates a job application manually. Returns the inserted row.
  Future<JobApplication> create({
    required String userId,
    required String company,
    required String role,
    required String status,
    String? summary,
    String? location,
  }) async {
    final response = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'company': company,
          'role': role,
          'status': status,
          'summary': summary,
          'location': location,
        })
        .select()
        .single();
    return JobApplication.fromJson(response);
  }

  /// Updates an existing job application's editable fields.
  Future<void> update(
    String id, {
    required String company,
    required String role,
    required String status,
    String? summary,
    String? location,
  }) async {
    await _client
        .from(_table)
        .update({
          'company': company,
          'role': role,
          'status': status,
          'summary': summary,
          'location': location,
        })
        .eq('id', id);
  }

  /// Permanently deletes a job application.
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
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
