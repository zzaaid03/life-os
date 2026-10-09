/// "Tweak this recipe" bottom sheet. Placeholder seam; Lane D implements it.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// Asks the chef to rewrite a recipe ("make it spicier").
abstract final class TweakRecipeSheet {
  /// Shows the sheet for [recipe]. Resolves to the revised recipe once the
  /// user accepts it, or null if they cancel or keep the original.
  static Future<Recipe?> show(BuildContext context, Recipe recipe) async => null;
}
