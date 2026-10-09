/// "Tweak this recipe" bottom sheet: ask the chef for a rewrite, preview
/// what changed, then keep it or not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/recipe_chef_service.dart';
import 'package:life_os/features/recipes/presentation/sheets/chef_sheet_parts.dart';
import 'package:life_os/features/recipes/presentation/widgets/recipe_hero_badge.dart';

/// Asks the chef to rewrite a recipe ("make it spicier").
abstract final class TweakRecipeSheet {
  /// Shows the sheet for [recipe]. Resolves to the revised recipe once the
  /// user accepts it, or null if they cancel or keep the original.
  static Future<Recipe?> show(BuildContext context, Recipe recipe) {
    return showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (_) => _TweakRecipeBody(recipe: recipe),
    );
  }
}

const _suggestions = [
  'Make it spicier',
  'Make it vegetarian',
  'Fewer ingredients',
  'No oven',
  'More protein',
  'Kid friendly',
];

/// What the rewrite changed, worked out locally from the two recipes.
class RecipeChanges {
  /// Compares [before] and [after]. Ingredient names match case-insensitively.
  factory RecipeChanges.between(Recipe before, Recipe after) {
    String key(RecipeIngredient i) => i.name.trim().toLowerCase();
    final oldKeys = before.ingredients.map(key).toSet();
    final newKeys = after.ingredients.map(key).toSet();
    return RecipeChanges._(
      added: [
        for (final i in after.ingredients)
          if (!oldKeys.contains(key(i))) i.name.trim(),
      ],
      removed: [
        for (final i in before.ingredients)
          if (!newKeys.contains(key(i))) i.name.trim(),
      ],
      servingsBefore: before.servings,
      servingsAfter: after.servings,
    );
  }

  const RecipeChanges._({
    required this.added,
    required this.removed,
    required this.servingsBefore,
    required this.servingsAfter,
  });

  /// Ingredient names only in the new version.
  final List<String> added;

  /// Ingredient names only in the old version.
  final List<String> removed;

  /// Servings before the rewrite.
  final int servingsBefore;

  /// Servings after the rewrite.
  final int servingsAfter;

  /// Whether the ingredient list is unchanged by name.
  bool get sameIngredients => added.isEmpty && removed.isEmpty;

  /// Whether the servings changed.
  bool get servingsChanged => servingsBefore != servingsAfter;
}

enum _Phase { input, loading, preview }

class _TweakRecipeBody extends ConsumerStatefulWidget {
  const _TweakRecipeBody({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_TweakRecipeBody> createState() => _TweakRecipeBodyState();
}

class _TweakRecipeBodyState extends ConsumerState<_TweakRecipeBody> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  _Phase _phase = _Phase.input;
  String? _error;
  late Recipe _result;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _useSuggestion(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  Future<void> _rewrite() async {
    final instruction = _controller.text.trim();
    if (instruction.isEmpty || _phase == _Phase.loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final result = await ref
          .read(recipeChefServiceProvider)
          .tweak(widget.recipe, instruction);
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.preview;
      });
    } on RecipeChefException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = _Phase.input;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: insets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_phase) {
              _Phase.input => _buildInput(context),
              _Phase.loading => const _RewritingState(key: ValueKey('loading')),
              _Phase.preview => _buildPreview(context, _result),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _controller.text.trim().isNotEmpty;
    return Column(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tweak this recipe',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.recipe.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (i, s) in _suggestions.indexed)
              ActionChip(
                label: Text(s),
                onPressed: () => _useSuggestion(s),
              )
                  .animate()
                  .fadeIn(duration: 250.ms, delay: (40 * i).ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _controller,
          focusNode: _focus,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _rewrite(),
          decoration: const InputDecoration(
            hintText: 'How should the chef change it?',
            border: OutlineInputBorder(borderRadius: AppRadius.input),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          ChefErrorBox(title: "Couldn't rewrite it", message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: canSend ? _rewrite : null,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Rewrite it'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, Recipe result) {
    final theme = Theme.of(context);
    final changes = RecipeChanges.between(widget.recipe, result);
    final added = theme.colorScheme.primary;
    final removed = theme.colorScheme.error;

    final lines = <Widget>[
      for (final name in changes.added)
        _ChangeLine(text: '+ $name', color: added),
      for (final name in changes.removed)
        _ChangeLine(text: '− $name', color: removed),
      if (changes.sameIngredients)
        _ChangeLine(
          text: 'Same ingredients, method adjusted',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      if (changes.servingsChanged)
        _ChangeLine(
          text:
              'Serves ${changes.servingsAfter} (was ${changes.servingsBefore})',
          color: theme.colorScheme.onSurface,
        ),
    ];

    return Column(
      key: const ValueKey('preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecipeBadgeFace(recipe: result, size: 64)
                .animate()
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 450.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 200.ms),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (result.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      result.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: AppRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What changed',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final (i, line) in lines.indexed)
                line
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (150 + 50 * i).ms)
                    .slideX(begin: -0.1, end: 0),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(result),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: const Text('Use this version'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: const Text('Keep original'),
        ),
      ],
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A bobbing chef with a shimmering caption while the rewrite runs.
class _RewritingState extends StatelessWidget {
  const _RewritingState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍳', style: TextStyle(fontSize: 40))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(begin: -0.04, end: 0.04, duration: 500.ms),
              const SizedBox(width: AppSpacing.sm),
              const Text('👨‍🍳', style: TextStyle(fontSize: 48))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -8, duration: 450.ms, curve: Curves.easeInOut),
              const SizedBox(width: AppSpacing.sm),
              const Text('🧂', style: TextStyle(fontSize: 32))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(begin: 0.1, end: -0.15, duration: 350.ms),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'The chef is rewriting…',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1400.ms,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
        ],
      ),
    );
  }
}
