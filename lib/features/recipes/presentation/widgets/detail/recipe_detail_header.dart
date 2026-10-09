/// The recipe page's collapsing header: the recipe's gradient, softened so it
/// sits well in light and dark mode, with the hero badge floating in the
/// middle and the title fading into the bar once collapsed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/presentation/widgets/recipe_hero_badge.dart';

/// Height of the header when fully expanded.
const double kRecipeHeaderHeight = 320;

/// The pinned [SliverAppBar] at the top of the recipe page.
class RecipeDetailHeader extends StatelessWidget {
  /// Creates a [RecipeDetailHeader].
  const RecipeDetailHeader({
    super.key,
    required this.recipe,
    required this.heroTag,
    required this.actions,
  });

  /// The recipe shown.
  final Recipe recipe;

  /// The tag the badge flew in with. Never changes while the page is open.
  final String heroTag;

  /// App bar actions (bookmark, menu).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.scaffoldBackgroundColor;
    // Pull the raw gradient towards the page colour so a saturated pair
    // still reads as a soft wash in both themes.
    final softened = [
      for (final c in recipe.gradient) Color.lerp(c, base, isDark ? 0.62 : 0.55)!,
    ];

    return SliverAppBar(
      pinned: true,
      expandedHeight: kRecipeHeaderHeight,
      backgroundColor: base,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minHeight = kToolbarHeight + topPadding;
          final range = kRecipeHeaderHeight + topPadding - minHeight;
          // 1 when fully expanded, 0 when collapsed.
          final expanded = range <= 0
              ? 0.0
              : ((constraints.maxHeight - minHeight) / range).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: expanded,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: softened,
                    ),
                  ),
                  child: DecoratedBox(
                    // Fade into the page so the header has no hard edge.
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.55, 1],
                        colors: [base.withValues(alpha: 0), base],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topPadding + kToolbarHeight * 0.5,
                bottom: 0,
                child: Opacity(
                  opacity: Curves.easeIn.transform(expanded),
                  child: Center(
                    child: RecipeHeroBadge(recipe: recipe, heroTag: heroTag, size: 132)
                        .animate(
                          delay: 450.ms,
                          onPlay: (controller) => controller.repeat(reverse: true),
                        )
                        .moveY(
                          begin: 0,
                          end: -8,
                          duration: 2600.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ),
              ),
              Positioned(
                left: 56,
                right: 56.0 * actions.length.clamp(1, 3),
                top: topPadding,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - expanded * 4).clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xs),
                        child: Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
