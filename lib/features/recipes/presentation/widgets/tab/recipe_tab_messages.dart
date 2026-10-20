import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class ChefErrorCard extends StatelessWidget {
  const ChefErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧑‍🍳', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'The chef hit a snag',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // The raw provider error, shown on purpose: it is how outages get
          // diagnosed.
          SelectableText(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ],
      ),
    );
  }
}

class SavedRecipesMessage extends StatelessWidget {
  const SavedRecipesMessage({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            onRetry == null ? '📖' : '😕',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
