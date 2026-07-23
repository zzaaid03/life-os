/// In-memory demo repository for [JobApplication]s.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';

/// Stateful in-memory [JobApplicationRepository] backing the sandbox demo
/// mode.
class DemoJobApplicationRepository implements JobApplicationRepository {
  /// Creates a [DemoJobApplicationRepository] seeded with demo data.
  DemoJobApplicationRepository() : _jobs = buildDemoJobs();

  final List<JobApplication> _jobs;

  /// Mirrors [SupabaseJobApplicationRepository]'s identity rules: a update
  /// WITH a company matches by `(company, role)`; a update WITHOUT a company
  /// matches by `sourceEmailId` against a row with an empty company.
  int _findExistingIndex(JobUpdate update) {
    if (update.company.isNotEmpty) {
      return _jobs.indexWhere(
        (j) => j.company == update.company && j.role == update.role,
      );
    }

    final emailId = update.sourceEmailId;
    if (emailId != null && emailId.isNotEmpty) {
      return _jobs.indexWhere(
        (j) => j.company.isEmpty && j.sourceEmailId == emailId,
      );
    }

    return -1;
  }

  @override
  Future<void> upsertFromScan(List<JobUpdate> updates, String userId) async {
    for (final update in updates) {
      final index = _findExistingIndex(update);
      final now = DateTime.now();

      if (index != -1) {
        _jobs[index] = JobApplication(
          id: _jobs[index].id,
          company: _jobs[index].company,
          role: _jobs[index].role,
          location: _jobs[index].location,
          status: update.status,
          summary: update.summary,
          sourceEmailId: update.sourceEmailId,
          appliedAt: _jobs[index].appliedAt,
          createdAt: _jobs[index].createdAt,
          updatedAt: now,
        );
      } else {
        _jobs.add(
          JobApplication(
            id: 'demo-job-${_jobs.length}-${now.microsecondsSinceEpoch}',
            company: update.company,
            role: update.role,
            status: update.status,
            summary: update.summary,
            sourceEmailId: update.sourceEmailId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  }

  @override
  Future<List<JobUpdate>> applyKnownAndCollectNew(
    List<JobUpdate> updates,
    String userId,
  ) async {
    final newOnes = <JobUpdate>[];

    for (final update in updates) {
      final index = _findExistingIndex(update);

      if (index != -1) {
        _jobs[index] = JobApplication(
          id: _jobs[index].id,
          company: _jobs[index].company,
          role: _jobs[index].role,
          location: _jobs[index].location,
          status: update.status,
          summary: update.summary,
          sourceEmailId: update.sourceEmailId,
          appliedAt: _jobs[index].appliedAt,
          createdAt: _jobs[index].createdAt,
          updatedAt: DateTime.now(),
        );
      } else {
        newOnes.add(update);
      }
    }

    return newOnes;
  }

  @override
  Future<JobApplication> create({
    required String userId,
    required String company,
    required String role,
    required String status,
    String? summary,
    String? location,
  }) async {
    final now = DateTime.now();
    final job = JobApplication(
      id: 'demo-job-${_jobs.length}-${now.microsecondsSinceEpoch}',
      company: company,
      role: role,
      location: location,
      status: status,
      summary: summary,
      createdAt: now,
      updatedAt: now,
    );
    _jobs.add(job);
    return job;
  }

  @override
  Future<void> update(
    String id, {
    required String company,
    required String role,
    required String status,
    String? summary,
    String? location,
  }) async {
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index != -1) {
      _jobs[index] = JobApplication(
        id: _jobs[index].id,
        company: company,
        role: role,
        location: location,
        status: status,
        summary: summary,
        sourceEmailId: _jobs[index].sourceEmailId,
        appliedAt: _jobs[index].appliedAt,
        createdAt: _jobs[index].createdAt,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    _jobs.removeWhere((j) => j.id == id);
  }

  @override
  Future<List<JobApplication>> getAll(String userId) async {
    return List.unmodifiable(_jobs);
  }
}
