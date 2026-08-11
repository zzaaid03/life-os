/// Follow-up nudge card for job applications.
///
/// Renders when one or more tracked applications have had no employer
/// response for 14+ days ([staleApplications]). Shows at most 3 rows plus
/// a "+N more" line, each with a one-tap "Follow up" action that opens the
/// task editor prefilled with a follow-up task for that application.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/presentation/job_display.dart';

const _maxVisibleRows = 3;

/// A card listing stale job applications with a follow-up action each.
///
/// Renders nothing (not an empty box) when [applications] is empty.
class FollowUpCard extends StatelessWidget {
  /// Creates a [FollowUpCard].
  const FollowUpCard({
    super.key,
    required this.applications,
    required this.now,
    required this.onFollowUp,
  });

  /// The stale applications to show, oldest first (as returned by
  /// [staleApplications]).
  final List<JobApplication> applications;

  /// The current time, used to phrase "quiet for N days".
  final DateTime now;

  /// Called when the user taps "Follow up" on an application.
  final ValueChanged<JobApplication> onFollowUp;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final visible = applications.take(_maxVisibleRows).toList();
    final remaining = applications.length - visible.length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headline(applications.length),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final app in visible) ...[
            _FollowUpRow(
              application: app,
              now: now,
              onFollowUp: () => onFollowUp(app),
            ),
            if (app != visible.last) const SizedBox(height: AppSpacing.xs),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '+$remaining more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headline(int count) {
    final noun = count == 1 ? 'application' : 'applications';
    return '$count $noun with no reply in 14+ days';
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({
    required this.application,
    required this.now,
    required this.onFollowUp,
  });

  final JobApplication application;
  final DateTime now;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The reference date falls back to `updatedAt` when the application has
    // no recorded `appliedAt`, so this cannot claim "applied N days ago" —
    // that would state something the row does not actually say.
    final reference = application.appliedAt ?? application.updatedAt;
    final days = now.difference(reference).inDays;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                jobDisplayTitle(
                  company: application.company,
                  role: application.role,
                  status: application.status,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Quiet for $days days',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onFollowUp, child: const Text('Follow up')),
      ],
    );
  }
}
