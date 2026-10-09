/// The method on the recipe page (numbered steps) and the tips card.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/recipe_pills.dart';

/// Numbered steps, each with a "⏱ N min" tag when it has a timer.
class MethodPreview extends StatelessWidget {
  /// Creates a [MethodPreview].
  const MethodPreview({super.key, required this.steps, required this.accent});

  /// The steps.
  final List<RecipeStep> steps;

  /// Colour of the step numbers (the recipe's own colour).
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.16),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          steps[i].text,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                        ),
                      ),
                      if (steps[i].hasTimer)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: IngredientTag(
                            label: '⏱ ${math.max(1, (steps[i].timerSeconds! / 60).round())} min',
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A soft card listing the chef's tips.
class TipsCard extends StatelessWidget {
  /// Creates a [TipsCard].
  const TipsCard({super.key, required this.tips});

  /// The tips; the card should not be built when empty.
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Chef\'s tips',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Text(tip, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
