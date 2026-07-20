/// Inbox scan screen.
///
/// Lets the user scan their recent Gmail with AI to surface suggested
/// tasks and job-application updates. Scan results live in
/// [inboxScanProvider] (not screen-local state) so navigating away and
/// back keeps them. Once a scan has run, the primary button becomes
/// "Update" and re-scans.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/domain/inbox_consent_provider.dart';
import 'package:life_os/features/inbox/domain/inbox_scan_provider.dart';
import 'package:life_os/features/inbox/presentation/widgets/inbox_consent_dialog.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';
import 'package:life_os/features/jobs/presentation/widgets/job_status_chip.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';

/// Screen driving the AI inbox scan flow.
class InboxScanScreen extends ConsumerWidget {
  /// Creates an [InboxScanScreen].
  const InboxScanScreen({super.key});

  /// Handles the scan button, showing the consent gate before the first
  /// scan ever and the connect-Gmail flow when no refresh token is stored.
  Future<void> _onScanPressed(BuildContext context, WidgetRef ref) async {
    final hasConsented = ref.read(inboxConsentProvider);
    if (!hasConsented) {
      final accepted = await InboxConsentDialog.show(context);
      if (!accepted) return;
      await ref.read(inboxConsentProvider.notifier).grantConsent();
    }

    try {
      await ref.read(inboxScanProvider.notifier).scan();
    } on GmailNotConnectedException {
      if (context.mounted) await _promptConnectGmail(context, ref);
    }
  }

  /// Prompts the user to connect Gmail when no refresh token is stored yet.
  Future<void> _promptConnectGmail(BuildContext context, WidgetRef ref) async {
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gmail connected. Tap "Scan my inbox" to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect Gmail. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Adds a suggested task to the real task system and removes its card.
  Future<void> _addTask(
    BuildContext context,
    WidgetRef ref,
    SuggestedTask suggestion,
  ) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    // Per product decision: don't parse the natural-language hint into a
    // real date. Create with no due date and fold the hint into the
    // description.
    final hint = suggestion.dueDateHint?.trim() ?? '';
    final description = hint.isEmpty ? null : 'Suggested due: $hint';
    final now = DateTime.now();

    final task = Task(
      id: '',
      userId: userId,
      title: suggestion.title,
      description: description,
      priority: mapSuggestedPriority(suggestion.priority),
      status: TaskStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(taskListProvider.notifier).createTask(task);
    ref.read(inboxScanProvider.notifier).removeTask(suggestion);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${suggestion.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scanState = ref.watch(inboxScanProvider);
    final isScanning = scanState.phase == InboxScanPhase.scanning;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Inbox')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          children: [
            Text(
              'Let AI read your recent emails and turn them into tasks and '
              'job updates.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isScanning
                    ? null
                    : () => _onScanPressed(context, ref),
                icon: isScanning
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        scanState.hasScannedOnce
                            ? Icons.refresh_rounded
                            : Icons.auto_awesome_rounded,
                      ),
                label: Text(
                  isScanning
                      ? 'Scanning…'
                      : scanState.hasScannedOnce
                      ? 'Update'
                      : 'Scan my inbox',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (scanState.phase == InboxScanPhase.done &&
                scanState.scannedAccount != null) ...[
              _ScannedAccountLine(account: scanState.scannedAccount!),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (scanState.phase == InboxScanPhase.error)
              _ErrorMessage(message: scanState.errorMessage),
            if (scanState.phase == InboxScanPhase.done)
              ..._buildResults(context, ref, scanState),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults(
    BuildContext context,
    WidgetRef ref,
    InboxScanState scanState,
  ) {
    final theme = Theme.of(context);
    final hasTasks = scanState.tasks.isNotEmpty;
    final hasJobs = scanState.jobUpdates.isNotEmpty;

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
                'Nothing new found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No new tasks or job updates in your recent emails.',
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
        _SectionTitle(
          title: 'Suggested Tasks',
          count: scanState.tasks.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...scanState.tasks.map(
          (t) => _SuggestedTaskCard(
            suggestion: t,
            onAdd: () => _addTask(context, ref, t),
            onDismiss: () =>
                ref.read(inboxScanProvider.notifier).dismissTask(t),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      if (hasJobs) ...[
        _SectionTitle(title: 'Job Updates', count: scanState.jobUpdates.length),
        const SizedBox(height: AppSpacing.sm),
        ...scanState.jobUpdates.map((j) => _JobUpdateCard(update: j)),
      ],
      const SizedBox(height: AppSpacing.massive),
    ];
  }
}

/// Maps a suggestion's priority string to the app's [TaskPriority].
TaskPriority mapSuggestedPriority(String priority) {
  return switch (priority.toLowerCase()) {
    'high' => TaskPriority.high,
    'medium' => TaskPriority.medium,
    'low' => TaskPriority.low,
    _ => TaskPriority.none,
  };
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
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
          message ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
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
            color: theme.colorScheme.primary,
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
    final priority = mapSuggestedPriority(suggestion.priority);

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
