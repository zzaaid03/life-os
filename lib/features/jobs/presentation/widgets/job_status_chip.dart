/// Job application status chip.
///
/// A compact colored chip conveying an application's status at a glance:
/// rejected = red, interview/offer = green, viewed/applied = neutral,
/// deadline = amber, anything else = neutral.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A small chip displaying a job application [status].
class JobStatusChip extends StatelessWidget {
  /// Creates a [JobStatusChip].
  const JobStatusChip({super.key, required this.status});

  /// The status string: applied | viewed | rejected | interview | offer |
  /// deadline | other (unknown values render neutral).
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _style(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Maps a status string to its display label and color.
  static (String, Color) _style(String status) {
    switch (status.toLowerCase()) {
      case 'rejected':
        return ('Rejected', AppColors.error);
      case 'interview':
        return ('Interview', AppColors.success);
      case 'offer':
        return ('Offer', AppColors.success);
      case 'viewed':
        return ('Viewed', AppColors.info);
      case 'applied':
        return ('Applied', AppColors.info);
      case 'deadline':
        return ('Deadline', AppColors.warning);
      default:
        return (_capitalize(status), AppColors.textSecondaryLight);
    }
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return 'Other';
    return value[0].toUpperCase() + value.substring(1);
  }
}
