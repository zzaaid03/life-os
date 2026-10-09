/// Cards used by the Recipes tab: the "Your last idea" card, a saved recipe
/// grid card, and its loading placeholder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/presentation/widgets/recipe_hero_badge.dart';

/// A very soft tint of [recipe]'s gradient over the card surface, opaque so
/// it reads the same in light and dark mode.
Gradient recipeTint(BuildContext context, Recipe recipe) {
  final theme = Theme.of(context);
  final surface = theme.colorScheme.surface;
  final alpha = theme.brightness == Brightness.dark ? 0.18 : 0.12;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      for (final c in recipe.gradient)
        Color.alphaBlend(c.withValues(alpha: alpha), surface),
    ],
  );
}

/// Shows the most recent unsaved idea so it is never lost by pressing back.
class LastIdeaCard extends StatelessWidget {
  /// Creates a [LastIdeaCard].
  const LastIdeaCard({
    super.key,
    required this.recipe,
    required this.heroTag,
    required this.onTap,
  });

  /// The recipe.
  final Recipe recipe;

  /// Its Hero tag; the recipe page reuses it.
  final String heroTag;

  /// Opens the recipe.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = recipe.totalMinutes;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: recipeTint(context, recipe),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Row(
              children: [
                RecipeHeroBadge(recipe: recipe, heroTag: heroTag, size: 56),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your last idea',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (minutes > 0) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '⏱ $minutes min',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One saved recipe in the grid.
class SavedRecipeCard extends StatelessWidget {
  /// Creates a [SavedRecipeCard].
  const SavedRecipeCard({
    super.key,
    required this.saved,
    required this.heroTag,
    required this.onTap,
    required this.onLongPress,
  });

  /// The saved row.
  final SavedRecipe saved;

  /// Its Hero tag.
  final String heroTag;

  /// Opens the recipe.
  final VoidCallback onTap;

  /// Asks to delete it.
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = saved.recipe;
    final minutes = recipe.totalMinutes;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: recipeTint(context, recipe),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecipeHeroBadge(recipe: recipe, heroTag: heroTag, size: 64),
                const SizedBox(height: AppSpacing.md),
                Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (minutes > 0) Text('⏱ $minutes min', style: muted),
                    if (saved.timesCooked > 0)
                      Text('Cooked ${saved.timesCooked}×', style: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A shimmering stand-in for a [SavedRecipeCard] while recipes load.
class SavedRecipePlaceholder extends StatelessWidget {
  /// Creates a [SavedRecipePlaceholder].
  const SavedRecipePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    Widget bar(double width) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(64 * 0.28),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          bar(110),
          const SizedBox(height: AppSpacing.sm),
          bar(70),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: theme.colorScheme.surface.withValues(alpha: 0.6),
        );
  }
}
