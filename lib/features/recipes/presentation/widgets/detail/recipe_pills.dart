/// Small rounded labels used across the recipe page: the meta pills under the
/// title and the tiny tags on ingredient rows.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/scaling.dart';

/// A soft pill with a main label and optional smaller trailing text.
class RecipePill extends StatelessWidget {
  /// Creates a [RecipePill].
  const RecipePill({super.key, required this.label, this.detail});

  /// Main text, e.g. "⏱ 35 min".
  final String label;

  /// Smaller muted text after the label, e.g. "10 prep, 25 cook".
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.circular),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (detail != null)
              TextSpan(
                text: '  $detail',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tiny coloured tag, e.g. "Staple".
class IngredientTag extends StatelessWidget {
  /// Creates an [IngredientTag].
  const IngredientTag({super.key, required this.label, required this.color});

  /// Text.
  final String label;

  /// Accent colour; the background is a faint tint of it.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 2, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.circular),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The "Staple" / "You have it" / "On your list" tags for one ingredient.
List<Widget> ingredientTags(
  BuildContext context,
  RecipeIngredient ingredient,
  List<GroceryItem> groceryItems,
) {
  final scheme = Theme.of(context).colorScheme;
  return [
    if (ingredient.staple) IngredientTag(label: 'Staple', color: scheme.onSurfaceVariant),
    if (ingredient.have) IngredientTag(label: 'You have it', color: scheme.primary),
    if (isOnGroceryList(ingredient.name, groceryItems))
      IngredientTag(label: 'On your list', color: scheme.tertiary),
  ];
}
