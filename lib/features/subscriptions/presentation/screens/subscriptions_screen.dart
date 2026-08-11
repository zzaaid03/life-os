/// Subscriptions screen.
///
/// Lists the user's recurring charges (subscriptions, memberships, regular
/// bills), grouped active-first then cancelled, with a monthly-spend total
/// per currency at the top. Supports create (+), tap-to-edit, cancel and
/// delete (both offered from the editor), and pull-to-refresh.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';
import 'package:life_os/features/subscriptions/domain/providers/subscription_provider.dart';
import 'package:life_os/features/subscriptions/presentation/widgets/subscription_editor_dialog.dart';

/// Screen listing the user's subscriptions.
class SubscriptionsScreen extends ConsumerWidget {
  /// Creates a [SubscriptionsScreen].
  const SubscriptionsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    final result = await SubscriptionEditorDialog.show(context);
    if (result == null || result.action != SubscriptionEditorAction.save) {
      return;
    }

    try {
      await ref
          .read(subscriptionListProvider.notifier)
          .create(
            name: result.name,
            amountCents: result.amountCents,
            currency: result.currency,
            cycle: result.cycle,
            nextChargeDate: result.nextChargeDate,
            notes: result.notes,
          );
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not create the subscription.');
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final result = await SubscriptionEditorDialog.show(
      context,
      existing: subscription,
    );
    if (result == null) return;

    if (result.action == SubscriptionEditorAction.save) {
      try {
        await ref
            .read(subscriptionListProvider.notifier)
            .update(
              subscription.copyWith(
                name: result.name,
                amountCents: result.amountCents,
                currency: result.currency,
                cycle: result.cycle,
                nextChargeDate: result.nextChargeDate,
                clearNextChargeDate: result.nextChargeDate == null,
                notes: result.notes,
              ),
            );
      } catch (_) {
        if (context.mounted) {
          _showError(context, 'Could not save the changes.');
        }
      }
      return;
    }

    if (result.action == SubscriptionEditorAction.cancelSubscription) {
      if (!context.mounted) return;
      await _cancelWithConfirm(context, ref, subscription);
      return;
    }

    if (!context.mounted) return;
    await _deleteWithConfirm(context, ref, subscription);
  }

  Future<void> _cancelWithConfirm(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: Text(
          '"${subscription.name}" will be kept for history but excluded '
          'from totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(subscriptionListProvider.notifier)
          .update(subscription.copyWith(status: SubscriptionStatus.cancelled));
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not cancel the subscription.');
      }
    }
  }

  Future<void> _deleteWithConfirm(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subscription?'),
        content: Text(
          '"${subscription.name}" will be deleted. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(subscriptionListProvider.notifier)
          .softDelete(subscription.id);
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not delete the subscription.');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add subscription',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(subscriptionListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    SubscriptionListState state,
  ) {
    if (state.status == SubscriptionListStatus.loading &&
        state.subscriptions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == SubscriptionListStatus.error &&
        state.subscriptions.isEmpty) {
      return _MessageList(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load subscriptions",
        subtitle: state.error ?? 'Please pull to refresh and try again.',
      );
    }

    if (state.subscriptions.isEmpty) {
      return const _MessageList(
        icon: Icons.repeat_rounded,
        title: 'No subscriptions yet',
        subtitle: 'Add one with + to start tracking what you pay for.',
      );
    }

    final active = state.subscriptions
        .where((s) => s.status == SubscriptionStatus.active)
        .toList();
    final cancelled = state.subscriptions
        .where((s) => s.status == SubscriptionStatus.cancelled)
        .toList();
    final monthlySpend = ref.watch(monthlySpendProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      children: [
        if (monthlySpend.isNotEmpty) ...[
          _MonthlySpendSummary(totalsByCurrency: monthlySpend),
          const SizedBox(height: AppSpacing.xl),
        ],
        for (final subscription in active) ...[
          _SubscriptionCard(
            subscription: subscription,
            onTap: () => _edit(context, ref, subscription),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (cancelled.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel(label: 'Cancelled'),
          const SizedBox(height: AppSpacing.sm),
          for (final subscription in cancelled) ...[
            _SubscriptionCard(
              subscription: subscription,
              onTap: () => _edit(context, ref, subscription),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

/// The monthly-spend total, one line per currency. Never summed across
/// currencies: this app has no exchange-rate source.
class _MonthlySpendSummary extends StatelessWidget {
  const _MonthlySpendSummary({required this.totalsByCurrency});

  final Map<String, int> totalsByCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencies = totalsByCurrency.keys.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly spend',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final currency in currencies)
            Text(
              '$currency ${formatAmount(totalsByCurrency[currency]!)} / month',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription, this.onTap});

  final Subscription subscription;
  final VoidCallback? onTap;

  String get _cycleLabel {
    final name = subscription.cycle.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCancelled = subscription.status == SubscriptionStatus.cancelled;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Opacity(
            opacity: isCancelled ? 0.55 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_cycleLabel'
                        '${subscription.nextChargeDate != null ? ' · next ${_formatDate(subscription.nextChargeDate!)}' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${subscription.currency} '
                  '${formatAmount(subscription.amountCents)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

/// A centered message rendered inside a scrollable so pull-to-refresh works
/// even when the list is empty or errored.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        const SizedBox(height: AppSpacing.xxxl * 2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                ),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
