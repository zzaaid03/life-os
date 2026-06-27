/// Setup progress card.
///
/// Shows the user's onboarding progress in a calm,
/// premium card with status indicators.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A card showing setup progress during first experience.
class SetupProgressCard extends StatelessWidget {
  /// Creates a [SetupProgressCard].
  const SetupProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Setup Progress',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _SetupItem(
            icon: Icons.check_circle_rounded,
            label: 'Account',
            isComplete: true,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SetupItem(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            isComplete: true,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SetupItem(
            icon: Icons.calendar_today_rounded,
            label: 'Calendar',
            isComplete: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SetupItem(
            icon: Icons.task_alt_rounded,
            label: 'First Task',
            isComplete: false,
          ),
        ],
      ),
    );
  }
}

class _SetupItem extends StatelessWidget {
  const _SetupItem({
    required this.icon,
    required this.label,
    required this.isComplete,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool isComplete;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: isComplete
              ? (color ?? AppColors.success)
              : theme.colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isComplete
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontWeight: isComplete ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
        if (isComplete)
          const Icon(Icons.check_rounded, size: 20, color: AppColors.success)
        else
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
