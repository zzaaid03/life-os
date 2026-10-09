/// The recipe's emoji on its gradient: the visual identity of a recipe, and
/// the widget that flies between screens.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// The emoji badge, wrapped in a [Hero] with [heroTag].
///
/// Every screen showing the same recipe MUST pass the same tag (use
/// [recipeHeroTag]) and use this widget, so the flight starts and lands on
/// identical pixels. Only [size] and [radius] may differ between the two
/// ends; the emoji scales with the size, which is what makes the flight look
/// like the same object growing.
class RecipeHeroBadge extends StatelessWidget {
  /// Creates a [RecipeHeroBadge].
  const RecipeHeroBadge({
    super.key,
    required this.recipe,
    required this.heroTag,
    this.size = 72,
    this.radius,
  });

  /// The recipe shown.
  final Recipe recipe;

  /// Shared Hero tag, from [recipeHeroTag].
  final String heroTag;

  /// Width and height.
  final double size;

  /// Corner radius; defaults to a soft square (28% of [size]).
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: RecipeBadgeFace(recipe: recipe, size: size, radius: radius),
    );
  }
}

/// The badge without the [Hero], for places that must not fly (e.g. a
/// second copy of the same recipe on one screen).
class RecipeBadgeFace extends StatelessWidget {
  /// Creates a [RecipeBadgeFace].
  const RecipeBadgeFace({super.key, required this.recipe, this.size = 72, this.radius});

  /// The recipe shown.
  final Recipe recipe;

  /// Width and height.
  final double size;

  /// Corner radius.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final colors = recipe.gradient;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      alignment: Alignment.center,
      // Material ancestor keeps emoji text styling stable mid-flight, when
      // the Hero is drawn in the overlay outside any Scaffold.
      child: Material(
        type: MaterialType.transparency,
        child: Text(
          recipe.emoji,
          style: TextStyle(fontSize: size * 0.5, height: 1),
        ),
      ),
    );
  }
}
