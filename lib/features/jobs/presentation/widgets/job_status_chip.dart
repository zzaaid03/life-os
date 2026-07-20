/// Job application status chip.
///
/// A compact colored chip conveying an application's status at a glance:
/// rejected = red, accepted/interview = green, viewed = blue,
/// applied = neutral.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A small chip displaying a job application [status].
class JobStatusChip extends StatelessWidget {
  /// Creates a [JobStatusChip].
  const JobStatusChip({super.key, required this.status});

  /// The status string: applied | viewed | interview | rejected | accepted
  /// (unknown values render neutral).
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _style(status, theme);

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
  ///
  /// The "applied" neutral reads from the theme so it stays legible in
  /// both light and dark modes.
  static (String, Color) _style(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'rejected':
        return ('Rejected', AppColors.error);
      case 'accepted':
        return ('Accepted', AppColors.success);
      case 'interview':
        return ('Interview', AppColors.success);
      case 'viewed':
        return ('Viewed', AppColors.info);
      case 'applied':
        return (
          'Applied',
          theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );
      default:
        // Legacy/unknown statuses render as a neutral "Applied"-style chip.
        return (
          _capitalize(status),
          theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );
    }
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return 'Applied';
    return value[0].toUpperCase() + value.substring(1);
  }
}
