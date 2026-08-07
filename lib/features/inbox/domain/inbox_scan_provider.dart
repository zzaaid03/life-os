/// Inbox scan state provider.
///
/// Holds the latest scan result app-wide (instead of screen-local state)
/// so navigating away from and back to the Scan screen keeps the results.
/// Also orchestrates the scan pipeline: invoke the Edge Function, persist
/// job updates, and refresh the jobs list.
///
/// The server is now the sole source of dedup: `extract-tasks` only ever
/// selects emails it has not already marked processed, so an email surfaced
/// once cannot come back. A client-side filter against the same
/// `processed_emails` table used to run here too, from before the server
/// tracked anything itself; keeping it would now filter out every single
/// suggestion, since the server marks a batch processed before the response
/// ever reaches the client.
library;

import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/domain/inbox_scan_pending.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:riverpod/riverpod.dart';

/// The phase of the scan flow.
enum InboxScanPhase { idle, scanning, done, error }

/// State held by [InboxScanController].
class InboxScanState {
  /// Creates an [InboxScanState].
  const InboxScanState({
    this.phase = InboxScanPhase.idle,
    this.tasks = const <SuggestedTask>[],
    this.jobUpdates = const <JobUpdate>[],
    this.scannedAccount,
    this.errorMessage,
    this.hasScannedOnce = false,
    this.remaining = 0,
  });

  /// Current phase of the flow.
  final InboxScanPhase phase;

  /// Suggested tasks still awaiting an Add/Dismiss decision.
  final List<SuggestedTask> tasks;

  /// Job updates from the last scan (already persisted).
  final List<JobUpdate> jobUpdates;

  /// The Gmail address the last scan read.
  final String? scannedAccount;

  /// A user-facing error message when [phase] is [InboxScanPhase.error].
  final String? errorMessage;

  /// Whether at least one scan has completed this session, drives the
  /// "Scan my inbox" vs "Update" button label.
  final bool hasScannedOnce;

  /// How many pending emails the last scan did not get to.
  final int remaining;

  /// Returns a copy with the given overrides.
  InboxScanState copyWith({
    InboxScanPhase? phase,
    List<SuggestedTask>? tasks,
    List<JobUpdate>? jobUpdates,
    String? scannedAccount,
    String? errorMessage,
    bool? hasScannedOnce,
    int? remaining,
  }) {
    return InboxScanState(
      phase: phase ?? this.phase,
      tasks: tasks ?? this.tasks,
      jobUpdates: jobUpdates ?? this.jobUpdates,
      scannedAccount: scannedAccount ?? this.scannedAccount,
      errorMessage: errorMessage,
      hasScannedOnce: hasScannedOnce ?? this.hasScannedOnce,
      remaining: remaining ?? this.remaining,
    );
  }
}

/// Drives the inbox scan flow and keeps its result across navigation.
class InboxScanController extends StateNotifier<InboxScanState> {
  /// Creates an [InboxScanController].
  InboxScanController(this._ref) : super(const InboxScanState());

  final Ref _ref;

  /// Asks how much mail is waiting, without analysing any of it.
  ///
  /// Cheap enough to call before every scan; see [InboxScanService.countPending].
  Future<InboxScanPending> checkPending() {
    return _ref.read(inboxScanServiceProvider).countPending();
  }

  /// Runs a scan end-to-end.
  ///
  /// Rethrows [GmailNotConnectedException] so the UI can offer the
  /// connect-Gmail flow; all other failures land in an error state.
  Future<void> scan({
    int maxResults = kScanBatchSize,
    ScanOrder order = ScanOrder.newest,
  }) async {
    state = state.copyWith(phase: InboxScanPhase.scanning);

    try {
      final result = await _ref
          .read(inboxScanServiceProvider)
          .scanInbox(maxResults: maxResults, order: order);

      final userId = _ref.read(authProvider).userId;
      var jobUpdates = result.jobUpdates;

      if (userId != null && jobUpdates.isNotEmpty) {
        jobUpdates = await _ref
            .read(jobApplicationRepositoryProvider)
            .applyKnownAndCollectNew(jobUpdates, userId);
        await _ref.read(jobListProvider.notifier).refresh();
      }

      state = InboxScanState(
        phase: InboxScanPhase.done,
        tasks: result.tasks,
        jobUpdates: jobUpdates,
        scannedAccount: result.scannedAccount,
        hasScannedOnce: true,
        remaining: result.remaining,
      );
    } on GmailNotConnectedException {
      state = state.copyWith(phase: InboxScanPhase.idle);
      rethrow;
    } catch (_) {
      state = state.copyWith(
        phase: InboxScanPhase.error,
        errorMessage:
            'We couldn\'t scan your inbox right now. Please try again.',
      );
    }
  }

  /// Removes a suggestion after the user added it as a real task.
  void removeTask(SuggestedTask task) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => !identical(t, task)).toList(),
    );
  }

  /// Removes a suggestion the user dismissed.
  void dismissTask(SuggestedTask task) => removeTask(task);

  /// Removes a job update after the user added it to the tracker.
  void removeJobUpdate(JobUpdate update) {
    state = state.copyWith(
      jobUpdates: state.jobUpdates.where((j) => !identical(j, update)).toList(),
    );
  }

  /// Removes a job update the user dismissed.
  void dismissJobUpdate(JobUpdate update) => removeJobUpdate(update);
}

/// The app-wide inbox scan state.
final inboxScanProvider =
    StateNotifierProvider<InboxScanController, InboxScanState>((ref) {
      return InboxScanController(ref);
    });
