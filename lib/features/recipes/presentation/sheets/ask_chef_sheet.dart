/// "Ask the chef" bottom sheet. Placeholder seam; Lane D implements it.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// A mid-cook question to the chef about this recipe.
abstract final class AskChefSheet {
  /// Shows the sheet for [recipe]. [stepIndex] is the step on screen, or
  /// null before the steps (mise en place).
  static Future<void> show(
    BuildContext context, {
    required Recipe recipe,
    int? stepIndex,
  }) async {}
}
