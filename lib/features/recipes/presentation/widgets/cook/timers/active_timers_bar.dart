/// Floating bar of running timers. Placeholder seam; Lane C2 implements it.
library;

import 'package:flutter/material.dart';

/// A compact strip of every live timer for [recipeTitle] EXCEPT the one
/// belonging to [currentStepIndex] (that one is already big on screen).
/// Tapping a timer calls [onJumpToStep] with its step index. Renders nothing
/// when there is nothing to show.
class ActiveTimersBar extends StatelessWidget {
  /// Creates an [ActiveTimersBar].
  const ActiveTimersBar({
    super.key,
    required this.recipeTitle,
    required this.onJumpToStep,
    this.currentStepIndex,
  });

  /// Only this recipe's timers are shown.
  final String recipeTitle;

  /// Called with a step index when a timer is tapped.
  final ValueChanged<int> onJumpToStep;

  /// The step on screen, or null on the mise en place / finish pages.
  final int? currentStepIndex;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
