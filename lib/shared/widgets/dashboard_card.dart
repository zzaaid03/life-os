/// Dashboard card widget.
///
/// A premium card container for dashboard sections.
/// Includes a header with icon, title, and optional trailing,
/// plus a content area for the card body.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A dashboard card with an optional header and content.
class DashboardCard extends StatelessWidget {
  /// Creates a [DashboardCard].
  const DashboardCard({
    super.key,
    required this.child,
    this.icon,
    this.title,
    this.trailing,
    this.onTap,
    this.padding,
  });

  /// The card content.
  final Widget child;

  /// Optional header icon.
  final IconData? icon;

  /// Optional header title.
  final String? title;

  /// Optional trailing widget in the header (e.g., a count badge).
  final Widget? trailing;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Override the content padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeader = icon != null || title != null || trailing != null;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader) ...[
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 20,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
