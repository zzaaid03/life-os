/// Job applications screen.
///
/// Lists the user's tracked job applications (populated by inbox scans),
/// each with a colored status chip and summary. Supports pull-to-refresh
/// and shows a friendly empty state when nothing is tracked yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/jobs/presentation/widgets/job_status_chip.dart';

/// Screen listing the user's tracked job applications.
class JobApplicationsScreen extends ConsumerWidget {
  /// Creates a [JobApplicationsScreen].
  const JobApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Applications')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(jobListProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, JobListState state) {
    if (state.status == JobListStatus.loading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == JobListStatus.error && state.jobs.isEmpty) {
      return _MessageList(
        icon: Icons.error_outline_rounded,
        title: 'Couldn\'t load applications',
        subtitle: state.error ?? 'Please pull to refresh and try again.',
      );
    }

    if (state.jobs.isEmpty) {
      return const _MessageList(
        icon: Icons.work_outline_rounded,
        title: 'No applications tracked yet',
        subtitle: 'Scan your inbox to start.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      itemCount: state.jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _JobCard(job: state.jobs[index]),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobApplication job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
                    Text(
                      job.company,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (job.role.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        job.role,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              JobStatusChip(status: job.status),
            ],
          ),
          if (job.summary != null && job.summary!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              job.summary!,
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
