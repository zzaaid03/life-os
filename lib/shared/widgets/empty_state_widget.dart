/// Reusable empty state widget.
///
/// Displays an icon, title, and subtitle with consistent
/// spacing and typography. Used across all dashboard cards
/// and feature screens when no data exists.
///
/// Optionally includes a call-to-action button to invite
/// the user to create their first item.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A premium empty state with icon, title, subtitle, and optional action.
///
/// Every empty state in Life OS uses this widget to ensure
/// consistent visual language and messaging tone.
class EmptyStateWidget extends StatelessWidget {
  /// Creates an [EmptyStateWidget].
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.compact = false,
    this.actionLabel,
    this.onAction,
  });

  /// The icon to display.
  final IconData icon;

  /// The primary message.
  final String title;

  /// The secondary message — usually a call to action.
  final String subtitle;

  /// Override the icon color. Defaults to a subtle tint.
  final Color? iconColor;

  /// When true, renders a smaller version for use inside cards.
  final bool compact;

  /// Optional action button label (e.g., "Create first task").
  final String? actionLabel;

  /// Callback when the action button is tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleColor =
        iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.15);

    if (compact) {
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: subtleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: subtleColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: subtleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(icon, size: 28, color: subtleColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
