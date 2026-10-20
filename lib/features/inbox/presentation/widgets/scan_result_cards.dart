import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/presentation/screens/inbox_scan_screen.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';
import 'package:life_os/features/jobs/presentation/widgets/job_status_chip.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_due_date_badge.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';

class ScanErrorMessage extends StatelessWidget {
  const ScanErrorMessage({super.key, required this.message});

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
class ScannedAccountLine extends StatelessWidget {
  const ScannedAccountLine({super.key, required this.account});

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

class ScanSectionTitle extends StatelessWidget {
  const ScanSectionTitle({super.key, required this.title, required this.count});

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

class SuggestedTaskCard extends StatelessWidget {
  const SuggestedTaskCard({
    super.key,
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
                if (priority != TaskPriority.none ||
                    suggestion.dueDate != null ||
                    hint.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (priority != TaskPriority.none) ...[
                        TaskPriorityChip(priority: priority),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if (suggestion.dueDate != null)
                        TaskDueDateBadge(dueDate: suggestion.dueDate)
                      else if (hint.isNotEmpty)
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

class JobUpdateCard extends StatelessWidget {
  const JobUpdateCard({
    super.key,
    required this.update,
    required this.onAdd,
    required this.onDismiss,
  });

  final JobUpdate update;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check_rounded),
                color: AppColors.success,
                tooltip: 'Add to tracker',
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
        ],
      ),
    );
  }
}

class ScanSubscriptionCard extends StatelessWidget {
  const ScanSubscriptionCard({
    super.key,
    required this.suggestion,
    required this.onAdd,
    required this.onDismiss,
  });

  final SuggestedSubscription suggestion;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountCents = suggestion.amountCents;
    final currency = suggestion.currency;
    final cycle = suggestion.cycle;
    final nextChargeDate = suggestion.nextChargeDate;

    final String detail;
    if (amountCents != null) {
      final amount = '${formatAmount(amountCents)}${currency != null ? ' $currency' : ''}';
      final cyclePart = cycle != null ? ' / ${cycle.name}' : '';
      final datePart = nextChargeDate != null
          ? ' · next ${formatDay(nextChargeDate)}'
          : '';
      detail = '$amount$cyclePart$datePart';
    } else {
      detail = 'Amount not stated';
    }

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
                  suggestion.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.check_rounded),
            color: AppColors.success,
            tooltip: 'Add subscription',
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
