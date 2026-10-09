/// Remembers the most recently generated recipe, so pressing back on an
/// unsaved recipe never loses it.
library;

import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:riverpod/riverpod.dart';

/// The last recipe the chef generated, or null. In memory only, and reset
/// when the signed-in user changes so one account never sees another's idea.
final lastGeneratedRecipeProvider = StateProvider<Recipe?>((ref) {
  ref.watch(authProvider.select((a) => a.userId));
  return null;
});
