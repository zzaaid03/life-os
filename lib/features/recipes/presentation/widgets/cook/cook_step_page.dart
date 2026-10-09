/// One method step in cook mode, written large enough to read from the stove.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/scaling.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_palette.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/timers/step_timer_card.dart';

/// Step [stepIndex] of [recipe]: the text, the ingredients it uses, and its
/// timer (if it has one).
class CookStepPage extends StatelessWidget {
  /// Creates a [CookStepPage].
  const CookStepPage({
    super.key,
    required this.recipe,
    required this.stepIndex,
    required this.servings,
    required this.palette,
  });

  /// The recipe being cooked.
  final Recipe recipe;

  /// Index into `recipe.steps`.
  final int stepIndex;

  /// Servings to scale ingredient amounts to.
  final int servings;

  /// Cook-mode colours.
  final CookPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = recipe.steps[stepIndex];
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.xxxl,
      ),
      children: [
        Text(
          'Step ${stepIndex + 1} of ${recipe.steps.length}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: palette.accent,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          step.text,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 30,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ).maybeAnimate(
          reduceMotion,
          (a) => a.fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
        ),
        if (step.ingredientIndexes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final i in step.ingredientIndexes)
                _IngredientChip(
                  ingredient: recipe.ingredients[i],
                  quantity: scaledQuantity(
                    recipe.ingredients[i],
                    baseServings: recipe.servings,
                    servings: servings,
                  ),
                  palette: palette,
                ),
            ],
          ).maybeAnimate(reduceMotion, (a) => a.fadeIn(delay: 150.ms, duration: 350.ms)),
        ],
        const SizedBox(height: AppSpacing.xxl),
        StepTimerCard(recipe: recipe, stepIndex: stepIndex),
      ],
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({
    required this.ingredient,
    required this.quantity,
    required this.palette,
  });

  final RecipeIngredient ingredient;
  final String? quantity;
  final CookPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadius.circular),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            if (quantity != null)
              TextSpan(
                text: '$quantity ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            TextSpan(text: ingredient.name),
          ],
        ),
      ),
    );
  }
}
