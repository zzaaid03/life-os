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
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/domain/inbox_consent_provider.dart';
import 'package:life_os/features/inbox/domain/inbox_scan_pending.dart';
import 'package:life_os/features/inbox/domain/inbox_scan_provider.dart';
import 'package:life_os/features/inbox/presentation/widgets/inbox_consent_dialog.dart';
import 'package:life_os/features/inbox/presentation/widgets/scan_backlog_sheet.dart';
import 'package:life_os/features/inbox/presentation/widgets/scan_result_cards.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/providers/subscription_provider.dart';
import 'package:life_os/features/subscriptions/presentation/widgets/subscription_editor_dialog.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';

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

    final notifier = ref.read(inboxScanProvider.notifier);
    var order = ScanOrder.newest;

    // A cheap count, never a body fetch or a model call, decides whether to
    // ask which end of a backlog to start from. A failed count reads as
    // zero pending, so this just falls through to a normal scan.
    final pending = await notifier.checkPending();
    if (pending.needsChoice) {
      if (!context.mounted) return;
      final chosen = await showScanBacklogSheet(context, pending);
      if (chosen == null) return;
      order = chosen;
    }

    try {
      await notifier.scan(order: order);
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

  /// Opens the task editor prefilled from a suggestion, requiring the user
  /// to set a due date, then adds the confirmed task and removes its card.
  Future<void> _addTask(
    BuildContext context,
    WidgetRef ref,
    SuggestedTask suggestion,
  ) async {
    // A parsed dueDate is pre-filled directly on the editor, so the
    // "Suggested due:" description is only needed when we don't have one.
    final hint = suggestion.dueDateHint?.trim() ?? '';
    final description = (suggestion.dueDate == null && hint.isNotEmpty)
        ? 'Suggested due: $hint'
        : null;

    final result = await TaskEditorSheet.show(
      context,
      initialTitle: suggestion.title,
      initialDescription: description,
      initialDueDate: suggestion.dueDate,
      defaultPriority: mapSuggestedPriority(suggestion.priority),
    );
    if (result == null) return;

    await ref.read(taskListProvider.notifier).createTask(result);
    ref.read(inboxScanProvider.notifier).removeTask(suggestion);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${suggestion.title}"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Persists a brand-new job update to the tracker and removes its card.
  Future<void> _addJobApplication(
    BuildContext context,
    WidgetRef ref,
    JobUpdate update,
  ) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    try {
      await ref
          .read(jobApplicationRepositoryProvider)
          .upsertFromScan([update], userId);
    } catch (e) {
      debugPrint('Add job from scan failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't add this job. Try again."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref.read(jobListProvider.notifier).refresh();
    ref.read(inboxScanProvider.notifier).removeJobUpdate(update);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to your job tracker'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens the subscription editor prefilled from a suggestion. Only writes
  /// on an explicit save; backing out leaves the card in place so the user
  /// keeps the chance to add it later.
  Future<void> _addSubscription(
    BuildContext context,
    WidgetRef ref,
    SuggestedSubscription suggestion,
  ) async {
    final result = await SubscriptionEditorDialog.show(
      context,
      draft: SubscriptionDraft(
        name: suggestion.name,
        amountCents: suggestion.amountCents,
        currency: suggestion.currency,
        cycle: suggestion.cycle,
        nextChargeDate: suggestion.nextChargeDate,
      ),
    );
    if (!context.mounted) return;
    if (result == null || result.action != SubscriptionEditorAction.save) {
      return;
    }

    try {
      await ref.read(subscriptionListProvider.notifier).create(
        name: result.name,
        amountCents: result.amountCents,
        currency: result.currency,
        cycle: result.cycle,
        nextChargeDate: result.nextChargeDate,
        notes: result.notes,
        sourceEmailId: suggestion.sourceEmailId,
      );
      ref.read(inboxScanProvider.notifier).removeSubscription(suggestion);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to subscriptions'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add that subscription. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Each scan sends a batch of your inbox emails to an AI '
              'service, whatever they are about. Only what it extracts is '
              'saved, never the emails themselves.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                height: 1.4,
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
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.packages),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Packages'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (scanState.phase == InboxScanPhase.done &&
                scanState.scannedAccount != null) ...[
              ScannedAccountLine(account: scanState.scannedAccount!),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (scanState.phase == InboxScanPhase.done &&
                scanState.remaining > 0) ...[
              Text(
                '${scanState.remaining} more waiting. Tap Update to keep going.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else if (scanState.phase == InboxScanPhase.done)
              const SizedBox(height: AppSpacing.md),
            if (scanState.phase == InboxScanPhase.error)
              ScanErrorMessage(message: scanState.errorMessage),
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

    final subscriptionListState = ref.watch(subscriptionListProvider);
    final visibleSubscriptions = subscriptionListState.status ==
            SubscriptionListStatus.loaded
        ? scanState.subscriptions.where((s) {
            final name = s.name.trim().toLowerCase();
            return !subscriptionListState.subscriptions.any(
              (existing) =>
                  existing.status != SubscriptionStatus.cancelled &&
                  existing.name.trim().toLowerCase() == name,
            );
          }).toList()
        : scanState.subscriptions;
    final hasSubs = visibleSubscriptions.isNotEmpty;

    if (!hasTasks && !hasJobs && !hasSubs) {
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
                'No new tasks, job updates or subscriptions in your recent '
                'emails.',
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
        ScanSectionTitle(
          title: 'Suggested Tasks',
          count: scanState.tasks.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...scanState.tasks.map(
          (t) => SuggestedTaskCard(
            suggestion: t,
            onAdd: () => _addTask(context, ref, t),
            onDismiss: () =>
                ref.read(inboxScanProvider.notifier).dismissTask(t),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      if (hasJobs) ...[
        ScanSectionTitle(
          title: 'New Job Applications',
          count: scanState.jobUpdates.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...scanState.jobUpdates.map(
          (j) => JobUpdateCard(
            update: j,
            onAdd: () => _addJobApplication(context, ref, j),
            onDismiss: () =>
                ref.read(inboxScanProvider.notifier).dismissJobUpdate(j),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      if (hasSubs) ...[
        ScanSectionTitle(
          title: 'Subscriptions',
          count: visibleSubscriptions.length,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...visibleSubscriptions.map(
          (s) => ScanSubscriptionCard(
            suggestion: s,
            onAdd: () => _addSubscription(context, ref, s),
            onDismiss: () =>
                ref.read(inboxScanProvider.notifier).dismissSubscription(s),
          ),
        ),
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
