/// Job applications screen.
///
/// Lists the user's tracked job applications (populated by inbox scans or
/// created manually), each with a colored status chip and summary.
/// Supports create (+), tap-to-edit, swipe-to-delete, pull-to-refresh,
/// and a friendly empty state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';
import 'package:life_os/features/jobs/presentation/widgets/job_editor_dialog.dart';
import 'package:life_os/features/jobs/presentation/widgets/job_status_chip.dart';

/// Screen listing the user's tracked job applications.
class JobApplicationsScreen extends ConsumerWidget {
  /// Creates a [JobApplicationsScreen].
  const JobApplicationsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    final result = await JobEditorDialog.show(context);
    if (result == null) return;

    try {
      await ref
          .read(jobApplicationRepositoryProvider)
          .create(
            userId: userId,
            company: result.company,
            role: result.role,
            status: result.status,
            summary: result.summary,
            location: result.location,
          );
      await ref.read(jobListProvider.notifier).refresh();
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not create the entry.');
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    JobApplication job,
  ) async {
    final result = await JobEditorDialog.show(context, existing: job);
    if (result == null) return;

    try {
      await ref
          .read(jobApplicationRepositoryProvider)
          .update(
            job.id,
            company: result.company,
            role: result.role,
            status: result.status,
            summary: result.summary,
            location: result.location,
          );
      await ref.read(jobListProvider.notifier).refresh();
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not save the changes.');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    JobApplication job,
  ) async {
    try {
      await ref.read(jobApplicationRepositoryProvider).delete(job.id);
      await ref.read(jobListProvider.notifier).refresh();
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not delete the entry.');
      // Reload so a failed optimistic dismiss reappears.
      await ref.read(jobListProvider.notifier).refresh();
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add application',
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(jobListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, JobListState state) {
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
        subtitle: 'Scan your inbox to start, or add one with +.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      itemCount: state.jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final job = state.jobs[index];
        return Dismissible(
          key: ValueKey(job.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete application?'),
                    content: Text(
                      '"${jobDisplayTitle(company: job.company, role: job.role, status: job.status)}" will be removed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) => _delete(context, ref, job),
          child: _JobCard(job: job, onTap: () => _edit(context, ref, job)),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, this.onTap});

  final JobApplication job;

  /// Called when the card is tapped (opens the editor).
  final VoidCallback? onTap;

  /// The bold headline for the card — company, else role, else a
  /// status-based fallback so a company-less row never renders blank.
  String get _title {
    if (job.company.trim().isNotEmpty) return job.company.trim();
    if (job.role.trim().isNotEmpty) return job.role.trim();
    return jobStatusHeadline(job.status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          child: _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title is never blank: fall back to the role, then a
                    // status-based headline, when the company is unknown.
                    Text(
                      _title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Only show the role as a subtitle when it isn't already
                    // serving as the title (i.e. a company is present).
                    if (job.company.trim().isNotEmpty &&
                        job.role.trim().isNotEmpty) ...[
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
