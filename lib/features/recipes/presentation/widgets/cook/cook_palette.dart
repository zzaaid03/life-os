/// Colours for cook mode, drawn from the recipe's gradient so every recipe
/// gets its own mood while text stays readable in light and dark mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// The cook-mode colour set for one recipe.
class CookPalette {
  const CookPalette._({
    required this.accent,
    required this.onAccent,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.track,
    required this.card,
  });

  /// Builds the palette for [recipe] under the current theme.
  factory CookPalette.of(BuildContext context, Recipe recipe) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final first = recipe.gradient.first;
    final last = recipe.gradient.last;
    final accent = dark ? Color.lerp(last, Colors.white, 0.12)! : last;
    final onAccent = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return CookPalette._(
      accent: accent,
      onAccent: onAccent,
      backgroundTop: Color.lerp(scheme.surface, first, dark ? 0.22 : 0.20)!,
      backgroundBottom: Color.lerp(scheme.surface, last, dark ? 0.08 : 0.06)!,
      track: scheme.onSurface.withValues(alpha: 0.12),
      card: Color.lerp(scheme.surface, first, dark ? 0.14 : 0.08)!.withValues(alpha: 0.9),
    );
  }

  /// Buttons, progress and highlights.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// Top of the screen background.
  final Color backgroundTop;

  /// Bottom of the screen background.
  final Color backgroundBottom;

  /// Unfilled progress segments.
  final Color track;

  /// Checklist tiles and ingredient chips.
  final Color card;
}

/// Skips an entrance animation when the system asks for reduced motion.
extension MaybeAnimate on Widget {
  /// Applies [effects] unless [reduceMotion] is true.
  Widget maybeAnimate(bool reduceMotion, Animate Function(Animate a) effects) =>
      reduceMotion ? this : effects(animate());
}
