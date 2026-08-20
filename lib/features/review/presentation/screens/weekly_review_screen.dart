/// The weekly review screen.
///
/// Shows the most recently ended week's activity across tasks, job hunt,
/// subscriptions and goals. Visual idiom matches
/// `subscriptions_screen.dart`: same spacing/radius tokens, plain
/// `Container`-based cards and section labels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/review/domain/providers/weekly_review_provider.dart';
import 'package:life_os/features/review/domain/weekly_review.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';

/// Shows the most recently ended week's review.
class WeeklyReviewScreen extends ConsumerWidget {
  /// Creates a [WeeklyReviewScreen].
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(weeklyReviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your week')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        children: [
          _WeekRangeLabel(review: review),
          const SizedBox(height: AppSpacing.xl),
          if (review.isEmpty)
            const _EmptyState()
          else ...[
            if (!review.tasks.isEmpty) ...[
              const _SectionHeader(label: 'Tasks'),
              const SizedBox(height: AppSpacing.sm),
              _TasksSection(tasks: review.tasks),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (!review.jobs.isEmpty) ...[
              const _SectionHeader(label: 'Job hunt'),
              const SizedBox(height: AppSpacing.sm),
              _JobsSection(jobs: review.jobs),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (!review.subscriptions.isEmpty) ...[
              const _SectionHeader(label: 'Subscriptions'),
              const SizedBox(height: AppSpacing.sm),
              _SubscriptionsSection(subscriptions: review.subscriptions),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (!review.goals.isEmpty) ...[
              const _SectionHeader(label: 'Goals'),
              const SizedBox(height: AppSpacing.sm),
              _GoalsSection(goals: review.goals),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeekRangeLabel extends StatelessWidget {
  const _WeekRangeLabel({required this.review});

  final WeeklyReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastDay = review.weekEnd.subtract(const Duration(days: 1));

    return Text(
      '${formatDay(review.weekStart)} to ${formatDay(lastDay)}',
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl * 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_cafe_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'A quiet week',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              'Nothing happened in the reviewed week.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _TasksSection extends StatelessWidget {
  const _TasksSection({required this.tasks});

  final ReviewTasks tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tasks.completed.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tasks.completed.length} completed',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final task in tasks.completed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(task.title, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        if (tasks.completed.isNotEmpty && tasks.slipped.isNotEmpty)
          const SizedBox(height: AppSpacing.sm),
        if (tasks.slipped.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tasks.slipped.length} slipped',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final task in tasks.slipped) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(task.title, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _JobsSection extends StatelessWidget {
  const _JobsSection({required this.jobs});

  final ReviewJobs jobs;

  String _label(String status) =>
      status.isEmpty ? status : status[0].toUpperCase() + status.substring(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = jobs.pipeline.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (jobs.added.isNotEmpty) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${jobs.added.length} added',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final job in jobs.added) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${job.company} · ${job.role}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (jobs.quiet.isNotEmpty) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${jobs.quiet.length} gone quiet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final job in jobs.quiet) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${job.company} · ${job.role}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (statuses.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pipeline',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final status in statuses) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_label(status)}: ${jobs.pipeline[status]}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SubscriptionsSection extends StatelessWidget {
  const _SubscriptionsSection({required this.subscriptions});

  final ReviewSubscriptions subscriptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subscriptions.renewingSoon.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${subscriptions.renewingSoon.length} renewing soon',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final subscription in subscriptions.renewingSoon) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${subscription.name}'
                    '${subscription.nextChargeDate != null ? ' · ${formatDay(subscription.nextChargeDate!)}' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        if (subscriptions.monthlyTotals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly spend',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final total in subscriptions.monthlyTotals) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${total.currency} ${formatAmount(total.totalCents)} / month',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.goals});

  final ReviewGoals goals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (goals.moved.isNotEmpty)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final movement in goals.moved) ...[
                  if (movement != goals.moved.first)
                    const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${movement.goal.title}: ${movement.completedCount} '
                    '${movement.completedCount == 1 ? 'task' : 'tasks'} completed',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        if (goals.untouched.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No movement',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final goal in goals.untouched) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(goal.title, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
