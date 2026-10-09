/// Small pieces shared by the recipe chef sheets.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A friendly failure line plus the raw provider message in monospace.
/// The raw message is never hidden: it is what diagnoses AI outages.
class ChefErrorBox extends StatelessWidget {
  /// Creates a [ChefErrorBox].
  const ChefErrorBox({super.key, required this.title, required this.message});

  /// Friendly headline.
  final String title;

  /// Raw message from [RecipeChefException].
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ChefRawMessage(
            message: message,
            color: theme.colorScheme.onErrorContainer,
          ),
        ],
      ),
    );
  }
}

/// The raw error text in small monospace, selectable so it can be copied.
class ChefRawMessage extends StatelessWidget {
  /// Creates a [ChefRawMessage].
  const ChefRawMessage({super.key, required this.message, this.color});

  /// The raw message.
  final String message;

  /// Text colour; defaults to the variant colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SelectableText(
      message,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        fontSize: 11,
        color: (color ?? theme.colorScheme.onSurfaceVariant).withValues(
          alpha: 0.85,
        ),
      ),
    );
  }
}
