/// Supabase-backed repository for job applications.
///
/// Reads and upserts rows in the `public.job_applications` table. RLS
/// ensures each user only ever sees and writes their own rows, but every
/// query is still scoped by `user_id` explicitly for clarity.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for [JobApplication] records backed by Supabase.
class SupabaseJobApplicationRepository implements JobApplicationRepository {
  /// Creates a [SupabaseJobApplicationRepository].
  const SupabaseJobApplicationRepository(this._client);

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
  @override
  Future<void> upsertFromScan(List<JobUpdate> updates, String userId) async {
    for (final update in updates) {
      final values = {
        'status': update.status,
        'summary': update.summary,
        'source_email_id': update.sourceEmailId,
      };
      final existingId = await _findExistingId(update, userId);
      if (existingId != null) {
        await _client.from(_table).update(values).eq('id', existingId);
      } else {
        await _client.from(_table).insert({
          'user_id': userId,
          'company': update.company.trim(),
          'role': update.role,
          ...values,
        });
      }
    }
  }

  /// Returns the id of the existing row [update] refers to, using the same
  /// identity rules as [upsertFromScan], or `null` if there is no match.
  Future<String?> _findExistingId(JobUpdate update, String userId) async {
    final company = update.company.trim();
    if (company.isNotEmpty) {
      // Match on company (case-insensitive), NOT role: the AI extracts
      // inconsistent role strings across emails for the same application,
      // which caused a duplicate instead of a status update.
      final rows = await _client
          .from(_table)
          .select('id, role')
          .eq('user_id', userId)
          .ilike('company', company);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      if (list.length == 1) return list.first['id'] as String?;
      // Multiple applications at the same company: disambiguate by role.
      // If none matches, don't guess: return null so it's surfaced as a
      // new card for the user to confirm, never merged into the wrong row.
      final role = update.role.trim().toLowerCase();
      for (final row in list) {
        if ((row['role'] as String? ?? '').trim().toLowerCase() == role) {
          return row['id'] as String?;
        }
      }
      return null;
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
  @override
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
  @override
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
  @override
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
  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// Fetches all job applications for [userId], most recently updated first.
  @override
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
