/// Cook mode's first page: gather and prep every ingredient before the heat
/// goes on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/scaling.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_palette.dart';

/// A big tickable checklist of every ingredient, scaled to [servings].
///
/// The ticks live in the cook screen ([checked]) so they survive swiping to
/// a step and back.
class MiseEnPlacePage extends StatelessWidget {
  /// Creates a [MiseEnPlacePage].
  const MiseEnPlacePage({
    super.key,
    required this.recipe,
    required this.servings,
    required this.palette,
    required this.checked,
    required this.onToggle,
    required this.onReady,
  });

  /// The recipe being cooked.
  final Recipe recipe;

  /// Servings to scale to.
  final int servings;

  /// Cook-mode colours.
  final CookPalette palette;

  /// Ticked ingredient indexes.
  final Set<int> checked;

  /// Called with an ingredient index when its tile is tapped.
  final ValueChanged<int> onToggle;

  /// "Ready, let's cook".
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredients = recipe.ingredients;
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
          'Get ready',
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Gather and prep everything first',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${checked.length} of ${ingredients.length} ready',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (ingredients.isEmpty)
          Text('Nothing to gather for this one.', style: theme.textTheme.titleMedium),
        for (var i = 0; i < ingredients.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _IngredientTile(
              ingredient: ingredients[i],
              quantity: scaledQuantity(
                ingredients[i],
                baseServings: recipe.servings,
                servings: servings,
              ),
              checked: checked.contains(i),
              palette: palette,
              onTap: () => onToggle(i),
            ),
          ).maybeAnimate(
            reduceMotion,
            (a) => a
                .fadeIn(delay: (40 * i.clamp(0, 10)).ms, duration: 300.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 64,
          child: FilledButton.icon(
            onPressed: onReady,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
              textStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.local_fire_department_rounded, size: 28),
            label: const Text("Ready, let's cook"),
          ),
        ),
      ],
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({
    required this.ingredient,
    required this.quantity,
    required this.checked,
    required this.palette,
    required this.onTap,
  });

  final RecipeIngredient ingredient;
  final String? quantity;
  final bool checked;
  final CookPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final nameStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: checked ? muted : null,
      decoration: checked ? TextDecoration.lineThrough : null,
    );

    return Semantics(
      checked: checked,
      button: true,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: checked ? palette.accent : Colors.transparent,
                      border: Border.all(
                        color: checked ? palette.accent : theme.colorScheme.outline,
                        width: 2.5,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: checked
                          ? Icon(
                              Icons.check_rounded,
                              key: const ValueKey('on'),
                              color: palette.onAccent,
                              size: 24,
                            )
                          : const SizedBox.shrink(key: ValueKey('off')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: nameStyle ?? const TextStyle(),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (quantity != null)
                                  TextSpan(
                                    text: '$quantity  ',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                TextSpan(text: ingredient.name),
                                if (quantity == null)
                                  const TextSpan(
                                    text: '  to taste',
                                    style: TextStyle(fontWeight: FontWeight.w400),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (ingredient.prep != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            ingredient.prep!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: checked ? muted : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
