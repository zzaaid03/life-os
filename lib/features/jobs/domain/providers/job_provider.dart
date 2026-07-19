/// Riverpod providers for the job applications feature.
///
/// Exposes a [JobListNotifier] that loads the user's tracked job
/// applications and can be refreshed (e.g. after an inbox scan upserts
/// new updates). Mirrors the load/auto-load pattern used by the tasks
/// feature so cold-start behaves consistently.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the job applications list.
enum JobListStatus { loading, loaded, error }

/// State managed by [JobListNotifier].
class JobListState {
  /// Creates a [JobListState].
  const JobListState({
    this.status = JobListStatus.loading,
    this.jobs = const <JobApplication>[],
    this.error,
  });

  /// The current loading status.
  final JobListStatus status;

  /// The loaded job applications.
  final List<JobApplication> jobs;

  /// An error message, if loading failed.
  final String? error;

  /// Returns a copy with the given overrides.
  JobListState copyWith({
    JobListStatus? status,
    List<JobApplication>? jobs,
    String? error,
  }) {
    return JobListState(
      status: status ?? this.status,
      jobs: jobs ?? this.jobs,
      error: error,
    );
  }
}

/// Loads and refreshes the user's job applications.
class JobListNotifier extends StateNotifier<JobListState> {
  /// Creates a [JobListNotifier].
  JobListNotifier(this._repository) : super(const JobListState());

  final JobApplicationRepository _repository;

  String? _userId;

  /// Loads job applications for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.jobs.isEmpty) {
      state = const JobListState(status: JobListStatus.loading);
    }
    try {
      final jobs = await _repository.getAll(userId);
      state = JobListState(status: JobListStatus.loaded, jobs: jobs);
    } catch (e) {
      if (state.jobs.isNotEmpty) {
        state = state.copyWith(status: JobListStatus.loaded);
      } else {
        state = const JobListState(
          status: JobListStatus.error,
          error: 'Failed to load job applications.',
        );
      }
    }
  }

  /// Reloads job applications for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }
}

/// Provides the [JobListNotifier] and its [JobListState].
final jobListProvider =
    StateNotifierProvider<JobListNotifier, JobListState>((ref) {
      final repository = ref.watch(jobApplicationRepositoryProvider);
      final notifier = JobListNotifier(repository);

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold-start: if the session was already restored before this
      // provider was created, `ref.listen` won't fire, so load eagerly.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });

/// The number of tracked job applications (for dashboard badges).
final jobApplicationCountProvider = Provider<int>((ref) {
  return ref.watch(jobListProvider).jobs.length;
});
