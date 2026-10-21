/// The one-line nutrition estimate under the pills on the recipe page.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// "≈ 620 kcal per serving" with the macros and a small "Estimate" label.
/// Wraps onto a second line on a narrow phone.
class NutritionRow extends StatelessWidget {
  /// Creates a [NutritionRow].
  const NutritionRow({super.key, required this.nutrition});

  /// The per-serving estimate to show.
  final RecipeNutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = nutrition;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '≈ ${n.kcal} kcal per serving',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: '  ${n.protein}g protein, ${n.carbs}g carbs, ${n.fat}g fat',
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextSpan(
            text: '  Estimate',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
