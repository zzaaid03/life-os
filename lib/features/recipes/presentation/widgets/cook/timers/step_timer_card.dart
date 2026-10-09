/// The timer for one cook-mode step. Placeholder seam; Lane C2 implements it.
library;

import 'package:flutter/material.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// Shows and controls the timer for step [stepIndex] of [recipe]. Renders
/// nothing when that step has no timer. Reads and drives
/// `cookTimersProvider` itself; the cook screen only places it.
class StepTimerCard extends StatelessWidget {
  /// Creates a [StepTimerCard].
  const StepTimerCard({super.key, required this.recipe, required this.stepIndex});

  /// The recipe being cooked.
  final Recipe recipe;

  /// Index into `recipe.steps`.
  final int stepIndex;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
