/// Inbox scan state provider.
///
/// Holds the latest scan result app-wide (instead of screen-local state)
/// so navigating away from and back to the Scan screen keeps the results.
/// Also orchestrates the scan pipeline: invoke the Edge Function, drop task
/// suggestions whose source email was already processed, persist job
/// updates, refresh the jobs list, and record the newly-seen email ids.
library;

import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/data/processed_emails_repository.dart';
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

  /// Whether at least one scan has completed this session — drives the
  /// "Scan my inbox" vs "Update" button label.
  final bool hasScannedOnce;

  /// Returns a copy with the given overrides.
  InboxScanState copyWith({
    InboxScanPhase? phase,
    List<SuggestedTask>? tasks,
    List<JobUpdate>? jobUpdates,
    String? scannedAccount,
    String? errorMessage,
    bool? hasScannedOnce,
  }) {
    return InboxScanState(
      phase: phase ?? this.phase,
      tasks: tasks ?? this.tasks,
      jobUpdates: jobUpdates ?? this.jobUpdates,
      scannedAccount: scannedAccount ?? this.scannedAccount,
      errorMessage: errorMessage,
      hasScannedOnce: hasScannedOnce ?? this.hasScannedOnce,
    );
  }
}

/// Drives the inbox scan flow and keeps its result across navigation.
class InboxScanController extends StateNotifier<InboxScanState> {
  /// Creates an [InboxScanController].
  InboxScanController(this._ref) : super(const InboxScanState());

  final Ref _ref;

  /// Runs a scan end-to-end.
  ///
  /// Rethrows [GmailNotConnectedException] so the UI can offer the
  /// connect-Gmail flow; all other failures land in an error state.
  Future<void> scan({int maxResults = 10}) async {
    state = state.copyWith(phase: InboxScanPhase.scanning);

    try {
      final result = await _ref
          .read(inboxScanServiceProvider)
          .scanInbox(maxResults: maxResults);

      final userId = _ref.read(authProvider).userId;
      var tasks = result.tasks;
      var jobUpdates = result.jobUpdates;

      if (userId != null) {
        final processedRepo = _ref.read(processedEmailsRepositoryProvider);

        // Drop suggestions/job updates already seen in a previous scan.
        final taskIds = result.tasks
            .map((t) => t.sourceEmailId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();
        final jobIds = result.jobUpdates
            .map((j) => j.sourceEmailId)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();
        final allIds = [...taskIds, ...jobIds];
        try {
          final seen = await processedRepo.getProcessedIds(userId, allIds);
          tasks = result.tasks
              .where(
                (t) =>
                    t.sourceEmailId == null || !seen.contains(t.sourceEmailId),
              )
              .toList();
          jobUpdates = result.jobUpdates
              .where(
                (j) =>
                    j.sourceEmailId == null || !seen.contains(j.sourceEmailId),
              )
              .toList();
          // Everything surfaced this scan counts as seen from now on.
          await processedRepo.markProcessed(userId, allIds);
        } catch (_) {
          // Dedup is best-effort; a failure just means suggestions/job
          // updates may reappear on the next scan.
        }

        if (jobUpdates.isNotEmpty) {
          await _ref
              .read(jobApplicationRepositoryProvider)
              .upsertFromScan(jobUpdates, userId);
          await _ref.read(jobListProvider.notifier).refresh();
        }
      }

      state = InboxScanState(
        phase: InboxScanPhase.done,
        tasks: tasks,
        jobUpdates: jobUpdates,
        scannedAccount: result.scannedAccount,
        hasScannedOnce: true,
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
}

/// The app-wide inbox scan state.
final inboxScanProvider =
    StateNotifierProvider<InboxScanController, InboxScanState>((ref) {
      return InboxScanController(ref);
    });
