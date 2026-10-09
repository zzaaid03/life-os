/// One ingredient on the recipe page, with a tickable "gathered" circle.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/recipe_pills.dart';

/// An ingredient row. [quantity] is already scaled; null means "to taste".
class IngredientRow extends StatelessWidget {
  /// Creates an [IngredientRow].
  const IngredientRow({
    super.key,
    required this.ingredient,
    required this.quantity,
    required this.gathered,
    required this.onToggle,
    required this.groceryItems,
  });

  /// The ingredient.
  final RecipeIngredient ingredient;

  /// Scaled amount text, or null for "to taste".
  final String? quantity;

  /// Whether the user ticked it as gathered.
  final bool gathered;

  /// Toggles [gathered].
  final VoidCallback onToggle;

  /// The grocery list, for the "On your list" tag.
  final List<GroceryItem> groceryItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = ingredientTags(context, ingredient, groceryItems);
    final faded = gathered ? 0.45 : 1.0;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gathered ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: gathered ? scheme.primary : scheme.outline,
                  width: 1.6,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                scale: gathered ? 1 : 0,
                child: Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: faded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: Text(
                            quantity ?? 'to taste',
                            key: ValueKey(quantity),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: quantity == null ? FontWeight.w500 : FontWeight.w800,
                              fontStyle: quantity == null ? FontStyle.italic : null,
                              color: quantity == null ? scheme.onSurfaceVariant : scheme.onSurface,
                            ),
                          ),
                        ),
                        Text(ingredient.name, style: theme.textTheme.bodyLarge),
                        ...tags,
                      ],
                    ),
                    if (ingredient.prep != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          ingredient.prep!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
