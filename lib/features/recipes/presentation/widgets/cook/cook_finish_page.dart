/// Cook mode's last page: the celebration.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/cook_palette.dart';

/// Where the save button stands for an unsaved recipe.
enum CookSaveState {
  /// Not saved, button shown.
  idle,

  /// Save in flight.
  saving,

  /// Saved during this cook.
  saved,
}

/// The finish page. The screen owns all the logic (recording the cook,
/// saving, clearing timers); this only shows it.
class CookFinishPage extends StatelessWidget {
  /// Creates a [CookFinishPage].
  const CookFinishPage({
    super.key,
    required this.recipe,
    required this.palette,
    required this.isSaved,
    required this.timesCooked,
    required this.saveState,
    required this.onSave,
    required this.onDone,
  });

  /// The recipe just cooked.
  final Recipe recipe;

  /// Cook-mode colours.
  final CookPalette palette;

  /// Whether the recipe was saved before cook mode opened.
  final bool isSaved;

  /// The new times-cooked count once recorded, or null while it is pending
  /// (or if recording failed).
  final int? timesCooked;

  /// Save button state, for an unsaved recipe.
  final CookSaveState saveState;

  /// "Save this recipe".
  final VoidCallback onSave;

  /// "Done".
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - AppSpacing.xxl * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!reduceMotion) _Burst(colors: [...recipe.gradient, palette.accent]),
                    _Medal(recipe: recipe).maybeAnimate(
                      reduceMotion,
                      (a) => a
                          .scale(
                            begin: const Offset(0.3, 0.3),
                            end: const Offset(1, 1),
                            duration: 900.ms,
                            curve: Curves.elasticOut,
                          )
                          .fadeIn(duration: 200.ms),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Bon appétit!',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ).maybeAnimate(
                reduceMotion,
                (a) => a.fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.2, end: 0),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                recipe.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _status(theme),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    textStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(ThemeData theme) {
    final style = theme.textTheme.titleMedium?.copyWith(
      color: palette.accent,
      fontWeight: FontWeight.w700,
    );
    if (isSaved) {
      final count = timesCooked;
      if (count == null) return const SizedBox(height: 24);
      return Text(
        count == 1 ? 'Cooked 1 time' : 'Cooked $count times',
        style: style,
      ).animate().fadeIn(duration: 300.ms);
    }
    return switch (saveState) {
      CookSaveState.saved => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_added_rounded, color: palette.accent),
          const SizedBox(width: AppSpacing.sm),
          Text('Saved to your recipes', style: style),
        ],
      ),
      _ => SizedBox(
        width: double.infinity,
        height: 64,
        child: OutlinedButton.icon(
          onPressed: saveState == CookSaveState.saving ? null : onSave,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.accent,
            side: BorderSide(color: palette.accent, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          icon: saveState == CookSaveState.saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.bookmark_add_rounded, size: 26),
          label: const Text('Save this recipe'),
        ),
      ),
    };
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final colors = recipe.gradient;
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.4),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(recipe.emoji, style: const TextStyle(fontSize: 76, height: 1)),
    );
  }
}

/// A ring of dots that fly outward and fade, once.
class _Burst extends StatelessWidget {
  const _Burst({required this.colors});

  final List<Color> colors;

  static const _count = 14;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < _count; i++)
          _dot(i)
              .animate()
              .move(
                delay: 120.ms,
                begin: Offset.zero,
                end: Offset(
                  math.cos(2 * math.pi * i / _count) * (i.isEven ? 112 : 92),
                  math.sin(2 * math.pi * i / _count) * (i.isEven ? 112 : 92),
                ),
                duration: 750.ms,
                curve: Curves.easeOutCubic,
              )
              .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), duration: 300.ms)
              .then(delay: 150.ms)
              .fadeOut(duration: 450.ms),
      ],
    );
  }

  Widget _dot(int i) {
    final size = i.isEven ? 12.0 : 8.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors[i % colors.length],
      ),
    );
  }
}
