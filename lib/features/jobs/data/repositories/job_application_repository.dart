/// Repository interface for job applications.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/data/repositories/supabase_job_application_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for [JobApplication] records.
abstract class JobApplicationRepository {
  /// Upserts a batch of scan-derived [JobUpdate]s for [userId] without ever
  /// creating duplicates.
  Future<void> upsertFromScan(List<JobUpdate> updates, String userId);

  /// Option B: auto-applies status/summary to job updates that match an
  /// EXISTING application, and returns the updates that refer to a brand-new
  /// application (no matching row) so the UI can confirm before adding them.
  Future<List<JobUpdate>> applyKnownAndCollectNew(
    List<JobUpdate> updates,
    String userId,
  );

  /// Creates a job application manually. Returns the inserted row.
  Future<JobApplication> create({
    required String userId,
    required String company,
    required String role,
    required String status,
    String? summary,
    String? location,
  });

  /// Updates an existing job application's editable fields.
  Future<void> update(
    String id, {
    required String company,
    required String role,
    required String status,
    String? summary,
    String? location,
  });

  /// Permanently deletes a job application.
  Future<void> delete(String id);

  /// Fetches all job applications for [userId], most recently updated first.
  Future<List<JobApplication>> getAll(String userId);
}

/// Provides the [JobApplicationRepository].
final jobApplicationRepositoryProvider = Provider<JobApplicationRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseJobApplicationRepository(client);
});
