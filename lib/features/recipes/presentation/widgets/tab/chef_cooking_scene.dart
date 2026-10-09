/// The animated "chef is cooking" scene shown while a recipe generates.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/presentation/widgets/recipe_hero_badge.dart';

const _emojis = ['🍅', '🧄', '🌶️', '🥕', '🍋', '🧅', '🫑'];

const _statuses = [
  'Raiding the pantry…',
  'Chopping onions…',
  'Tasting the sauce…',
  'Plating up…',
];

/// A breathing gradient orb with cycling ingredients and a rotating status
/// line. When [landed] is set, the orb is swapped for the recipe's
/// [RecipeHeroBadge] in the same spot, ready to fly to the recipe page.
class ChefCookingScene extends StatefulWidget {
  /// Creates a [ChefCookingScene].
  const ChefCookingScene({
    super.key,
    this.landed,
    this.heroTag,
    this.onCancel,
  });

  /// The finished recipe, or null while still cooking.
  final Recipe? landed;

  /// Hero tag for [landed]; required when [landed] is set.
  final String? heroTag;

  /// Called when the user taps Cancel. Hidden once [landed] is set.
  final VoidCallback? onCancel;

  @override
  State<ChefCookingScene> createState() => _ChefCookingSceneState();
}

class _ChefCookingSceneState extends State<ChefCookingScene>
    with TickerProviderStateMixin {
  static const double _orbSize = 168;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final Timer _emojiTimer;
  late final Timer _statusTimer;
  int _emojiIndex = 0;
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _emojiTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (widget.landed == null) {
        setState(() => _emojiIndex = (_emojiIndex + 1) % _emojis.length);
      }
    });
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (widget.landed == null) {
        setState(() => _statusIndex = (_statusIndex + 1) % _statuses.length);
      }
    });
  }

  @override
  void dispose() {
    _emojiTimer.cancel();
    _statusTimer.cancel();
    _breath.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final landed = widget.landed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _orbSize,
            height: _orbSize,
            child: Center(
              // Swapped with no transition so the Hero starts its flight
              // from a badge at rest, not one mid-fade.
              child: landed != null
                  ? RecipeHeroBadge(
                      recipe: landed,
                      heroTag: widget.heroTag!,
                      size: 120,
                    )
                  : _buildOrb(theme),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              landed != null ? _statuses.last : _statuses[_statusIndex],
              key: ValueKey(landed != null ? -1 : _statusIndex),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedOpacity(
            opacity: landed == null ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: TextButton(
              onPressed: landed == null ? widget.onCancel : null,
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final colors = [
      primary,
      AppColors.warning,
      AppColors.error,
      const Color(0xFFF6A15A),
      primary,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _spin]),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_breath.value);
        return Transform.scale(
          scale: 0.92 + 0.12 * t,
          child: Container(
            width: _orbSize,
            height: _orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: colors,
                transform: GradientRotation(_spin.value * 2 * math.pi),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warning.withValues(
                    alpha: (dark ? 0.25 : 0.35) + 0.15 * t,
                  ),
                  blurRadius: 36 + 18 * t,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: Container(
        width: _orbSize * 0.62,
        height: _orbSize * 0.62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface.withValues(alpha: dark ? 0.75 : 0.85),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          ),
          child: Text(
            _emojis[_emojiIndex],
            key: ValueKey(_emojiIndex),
            style: const TextStyle(fontSize: 52, height: 1),
          ),
        ),
      ),
    );
  }
}
