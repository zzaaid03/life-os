/// Arguments passed (via GoRouter `extra`) to the recipe page and cook mode.
///
/// `extra` does not survive a browser refresh on web. Both screens must
/// handle a null/wrong-typed `extra` by showing a short "Recipe not found"
/// message with a way back, never by throwing.
library;

import 'package:life_os/features/recipes/data/models/recipe.dart';

/// Opens the recipe page.
class RecipeViewArgs {
  /// Creates [RecipeViewArgs].
  const RecipeViewArgs({required this.recipe, required this.heroTag, this.saved});

  /// The recipe (for a saved one, `saved.recipe`).
  final Recipe recipe;

  /// The tag the badge flew in with; the page must reuse it.
  final String heroTag;

  /// The saved row, or null for a freshly generated, unsaved recipe.
  final SavedRecipe? saved;
}

/// Opens cook mode.
class CookModeArgs {
  /// Creates [CookModeArgs].
  const CookModeArgs({
    required this.recipe,
    required this.servings,
    required this.heroTag,
    this.savedId,
  });

  /// The recipe to cook.
  final Recipe recipe;

  /// Servings chosen on the recipe page; all amounts are scaled to this.
  final int servings;

  /// The recipe page's Hero tag, so the badge can fly into cook mode too.
  final String heroTag;

  /// The saved row id, if saved (finishing then records a cook).
  final String? savedId;
}
