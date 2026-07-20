/// Inbox scan screen.
///
/// Lets the user scan their recent Gmail with AI to surface suggested
/// tasks and job-application updates. Suggested tasks can be added to the
/// real task system or dismissed; job updates are persisted automatically
/// and shown for reference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/domain/inbox_consent_provider.dart';
import 'package:life_os/features/inbox/presentation/widgets/inbox_consent_dialog.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';
import 'package:life_os/features/jobs/presentation/widgets/job_status_chip.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';

/// The phase of the scan flow.
enum _ScanPhase { idle, scanning, done, error }

/// Screen driving the AI inbox scan flow.
class InboxScanScreen extends ConsumerStatefulWidget {
  /// Creates an [InboxScanScreen].
  const InboxScanScreen({super.key});

  @override
  ConsumerState<InboxScanScreen> createState() => _InboxScanScreenState();
}

class _InboxScanScreenState extends ConsumerState<InboxScanScreen> {
  _ScanPhase _phase = _ScanPhase.idle;
  String? _errorMessage;

  /// The Gmail address the last scan read, as reported by the function.
  String? _scannedAccount;

  // Suggested tasks are local + mutable so Add/Dismiss can remove cards.
  final List<SuggestedTask> _suggestedTasks = [];
  List<JobUpdate> _jobUpdates = const [];

  /// Handles the "Scan my inbox" tap, showing the consent gate first if the
  /// user has not yet agreed.
  Future<void> _onScanPressed() async {
    final hasConsented = ref.read(inboxConsentProvider);
    if (!hasConsented) {
      final accepted = await InboxConsentDialog.show(context);
      if (!accepted) return;
      await ref.read(inboxConsentProvider.notifier).grantConsent();
    }
    await _performScan();
  }

  Future<void> _performScan() async {
    setState(() {
      _phase = _ScanPhase.scanning;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(inboxScanServiceProvider)
          .scanInbox(maxResults: 10);

      // Persist job updates and refresh the jobs list so the Job
      // Applications screen reflects this scan immediately.
      final userId = ref.read(authProvider).userId;
      if (userId != null && result.jobUpdates.isNotEmpty) {
        await ref
            .read(jobApplicationRepositoryProvider)
            .upsertFromScan(result.jobUpdates, userId);
        await ref.read(jobListProvider.notifier).refresh();
      }

      if (!mounted) return;
      setState(() {
        _suggestedTasks
          ..clear()
          ..addAll(result.tasks);
        _jobUpdates = result.jobUpdates;
        _scannedAccount = result.scannedAccount;
        _phase = _ScanPhase.done;
      });
    } on GmailNotConnectedException {
      if (!mounted) return;
      setState(() => _phase = _ScanPhase.idle);
      await _promptConnectGmail();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScanPhase.error;
        _errorMessage =
            'We couldn\'t scan your inbox right now. Please try again.';
      });
    }
  }

  /// Prompts the user to connect Gmail when no refresh token is stored yet.
  ///
  /// Running the Google sign-in flow persists a fresh refresh token (see
  /// [googleCredentialsCaptureProvider]) that the Edge Function then uses to
  /// read the inbox on subsequent scans.
  Future<void> _promptConnectGmail() async {
    final connect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Gmail'),
        content: const Text(
          'Connect your Google account so Life OS can scan your inbox. '
          'You\'ll choose an account and grant read-only Gmail access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Connect Gmail'),
          ),
        ],
      ),
    );

    if (connect != true) return;

    try {
      // On web this redirects out to Google and back (the page reloads, so
      // the user returns and taps Scan again); on native the OAuth flow
      // completes in-place and the refresh token is stored automatically.
      await ref.read(authProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gmail connected. Tap "Scan my inbox" to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect Gmail. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Adds a suggested task to the real task system and removes its card.
  Future<void> _addTask(SuggestedTask suggestion) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    // Per spec: do not parse the natural-language hint into a real date.
    // Create with no due date and fold the hint into the description.
    final hint = suggestion.dueDateHint?.trim() ?? '';
    final description = hint.isEmpty ? null : 'Suggested due: $hint';
    final now = DateTime.now();

    final task = Task(
      id: '',
      userId: userId,
      title: suggestion.title,
      description: description,
      priority: _mapPriority(suggestion.priority),
      status: TaskStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(taskListProvider.notifier).createTask(task);

    if (!mounted) return;
    setState(() => _suggestedTasks.remove(suggestion));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${suggestion.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _dismissTask(SuggestedTask suggestion) {
    setState(() => _suggestedTasks.remove(suggestion));
  }

  static TaskPriority _mapPriority(String priority) {
    return switch (priority.toLowerCase()) {
      'high' => TaskPriority.high,
      'medium' => TaskPriority.medium,
      'low' => TaskPriority.low,
      _ => TaskPriority.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Inbox')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      children: [
        Text(
          'Let AI read your recent emails and turn them into tasks and job '
          'updates.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _phase == _ScanPhase.scanning ? null : _onScanPressed,
            icon: _phase == _ScanPhase.scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _phase == _ScanPhase.scanning ? 'Scanning…' : 'Scan my inbox',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_phase == _ScanPhase.done && _scannedAccount != null) ...[
          _ScannedAccountLine(account: _scannedAccount!),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_phase == _ScanPhase.error) _buildError(context),
        if (_phase == _ScanPhase.done) ..._buildResults(context),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _errorMessage ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResults(BuildContext context) {
    final theme = Theme.of(context);
    final hasTasks = _suggestedTasks.isNotEmpty;
    final hasJobs = _jobUpdates.isNotEmpty;

    if (!hasTasks && !hasJobs) {
      return [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nothing actionable found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your recent emails didn\'t contain any tasks or job updates.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      if (hasTasks) ...[
        _SectionTitle(title: 'Suggested Tasks', count: _suggestedTasks.length),
        const SizedBox(height: AppSpacing.sm),
        ..._suggestedTasks.map(
          (t) => _SuggestedTaskCard(
            suggestion: t,
            onAdd: () => _addTask(t),
            onDismiss: () => _dismissTask(t),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      if (hasJobs) ...[
        _SectionTitle(title: 'Job Updates', count: _jobUpdates.length),
        const SizedBox(height: AppSpacing.sm),
        ..._jobUpdates.map((j) => _JobUpdateCard(update: j)),
      ],
      const SizedBox(height: AppSpacing.massive),
    ];
  }
}

/// A small line showing which Gmail account was scanned.
class _ScannedAccountLine extends StatelessWidget {
  const _ScannedAccountLine({required this.account});

  final String account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Row(
      children: [
        Icon(Icons.mark_email_read_outlined, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Scanned: $account',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$count',
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SuggestedTaskCard extends StatelessWidget {
  const _SuggestedTaskCard({
    required this.suggestion,
    required this.onAdd,
    required this.onDismiss,
  });

  final SuggestedTask suggestion;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = suggestion.dueDateHint?.trim() ?? '';
    final priority = _InboxScanScreenState._mapPriority(suggestion.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (priority != TaskPriority.none || hint.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (priority != TaskPriority.none) ...[
                        TaskPriorityChip(priority: priority),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (hint.isNotEmpty)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Flexible(
                                child: Text(
                                  hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            color: AppColors.success,
            tooltip: 'Add task',
            onPressed: onAdd,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _JobUpdateCard extends StatelessWidget {
  const _JobUpdateCard({required this.update});

  final JobUpdate update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  jobDisplayTitle(
                    company: update.company,
                    role: update.role,
                    status: update.status,
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              JobStatusChip(status: update.status),
            ],
          ),
          if (update.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              update.summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
