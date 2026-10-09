/// The big gradient "Start cooking" button pinned to the bottom of the page.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A full-width gradient button in the recipe's own colours.
class StartCookingButton extends StatelessWidget {
  /// Creates a [StartCookingButton].
  const StartCookingButton({super.key, required this.gradient, required this.onPressed});

  /// The recipe's gradient.
  final List<Color> gradient;

  /// Called on tap.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Darken slightly so white text stays readable on pale gradients.
    final colors = [for (final c in gradient) Color.lerp(c, Colors.black, 0.12)!];
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: onPressed,
                child: SizedBox(
                  height: 58,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Start cooking',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
