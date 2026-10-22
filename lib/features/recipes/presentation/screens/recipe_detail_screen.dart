/// The recipe page: a cookbook-style spread for one recipe, with live
/// servings scaling, save/delete, tweak, add-to-list and the way into cook
/// mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/domain/providers/grocery_provider.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:life_os/features/recipes/domain/scaling.dart';
import 'package:life_os/features/recipes/presentation/recipe_routes.dart';
import 'package:life_os/features/recipes/presentation/sheets/tweak_recipe_sheet.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/add_to_list_sheet.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/ingredient_row.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/method_preview.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/nutrition_row.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/recipe_detail_header.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/recipe_pills.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/servings_stepper.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/start_cooking_button.dart';

/// Shows one recipe.
class RecipeDetailScreen extends StatelessWidget {
  /// Creates a [RecipeDetailScreen]. [args] is GoRouter's `extra` and is
  /// expected to be a `RecipeViewArgs`, but may be null after a web refresh.
  const RecipeDetailScreen({super.key, this.args});

  /// Untyped on purpose, see `recipe_routes.dart`.
  final Object? args;

  @override
  Widget build(BuildContext context) {
    final viewArgs = args;
    if (viewArgs is! RecipeViewArgs) return const _RecipeNotFound();
    return _RecipeDetailView(args: viewArgs);
  }
}

class _RecipeNotFound extends StatelessWidget {
  const _RecipeNotFound();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: AppSpacing.lg),
              Text('Recipe not found', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.groceries);
                  }
                },
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailView extends ConsumerStatefulWidget {
  const _RecipeDetailView({required this.args});

  final RecipeViewArgs args;

  @override
  ConsumerState<_RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends ConsumerState<_RecipeDetailView> {
  late Recipe _recipe = widget.args.recipe;
  late SavedRecipe? _saved = widget.args.saved;
  late int _servings = widget.args.recipe.servings;

  /// Bumped on every tweak so the content crossfades to the new recipe.
  int _revision = 0;

  /// Ingredient indexes ticked as gathered. Local only.
  final Set<int> _gathered = {};

  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await ref.read(savedRecipesProvider.notifier).save(_recipe);
      if (!mounted) return;
      setState(() => _saved = saved);
      _snack('Saved to your recipes');
    } catch (_) {
      if (mounted) _snack('Could not save the recipe. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final saved = _saved;
    if (saved == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('"${_recipe.title}" will be removed from your recipes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(savedRecipesProvider.notifier).delete(saved.id);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not delete the recipe. Try again.');
      }
    }
  }

  Future<void> _tweak() async {
    if (_busy) return;
    final Recipe? revised;
    try {
      revised = await TweakRecipeSheet.show(context, _recipe);
    } catch (_) {
      if (mounted) _snack('Could not tweak the recipe. Try again.');
      return;
    }
    if (revised == null || !mounted) return;

    var next = revised;
    final saved = _saved;
    if (saved != null) {
      setState(() => _busy = true);
      try {
        final updated = await ref.read(savedRecipesProvider.notifier).replace(saved, revised);
        if (!mounted) return;
        _saved = updated;
        next = updated.recipe;
      } catch (_) {
        if (mounted) {
          setState(() => _busy = false);
          _snack('Could not save the tweak. Try again.');
        }
        return;
      }
    }
    setState(() {
      _busy = false;
      _recipe = next;
      _servings = next.servings;
      _gathered.clear();
      _revision++;
    });
  }

  Future<void> _addToList() async {
    final items = ref.read(groceryListProvider).items;
    final drafts = await AddToListSheet.show(
      context,
      recipe: _recipe,
      servings: _servings,
      groceryItems: items,
    );
    if (drafts == null || drafts.isEmpty || !mounted) return;
    try {
      await ref.read(groceryListProvider.notifier).addAll(drafts);
      if (!mounted) return;
      _snack(drafts.length == 1 ? 'Added 1 item to your list' : 'Added ${drafts.length} items to your list');
    } catch (_) {
      if (mounted) _snack('Could not add to your list. Try again.');
    }
  }

  void _startCooking() {
    context.push(
      AppRoutes.cookMode,
      extra: CookModeArgs(
        recipe: _recipe,
        servings: _servings,
        heroTag: widget.args.heroTag,
        savedId: _saved?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final live = saved == null ? null : ref.watch(savedRecipeByIdProvider(saved.id));
    final timesCooked = (live ?? saved)?.timesCooked ?? 0;
    final groceryItems = ref.watch(groceryListProvider).items;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          RecipeDetailHeader(
            recipe: _recipe,
            heroTag: widget.args.heroTag,
            actions: [_bookmark(saved != null), const SizedBox(width: AppSpacing.xs)],
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(
                key: ValueKey(_revision),
                child: _content(timesCooked, groceryItems),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StartCookingButton(
        gradient: _recipe.gradient,
        onPressed: _startCooking,
      ).animate().fadeIn(delay: 250.ms, duration: 300.ms).slideY(begin: 0.4, end: 0),
    );
  }

  Widget _bookmark(bool isSaved) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
        child: child,
      ),
      child: isSaved
          ? PopupMenuButton<String>(
              key: const ValueKey('saved'),
              tooltip: 'Saved',
              icon: const Icon(Icons.bookmark_rounded),
              onSelected: (value) {
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: AppSpacing.md),
                      const Text('Delete recipe'),
                    ],
                  ),
                ),
              ],
            )
          : IconButton(
              key: const ValueKey('unsaved'),
              tooltip: 'Save recipe',
              icon: const Icon(Icons.bookmark_border_rounded),
              onPressed: _busy ? null : _save,
            ),
    );
  }

  Widget _content(int timesCooked, List<GroceryItem> groceryItems) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recipe = _recipe;
    final accent = recipe.gradient.last;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl, bottom: AppSpacing.md),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );

    final blocks = <Widget>[
      Text(
        recipe.title,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      if (recipe.description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            recipe.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            RecipePill(
              label: '⏱ ${recipe.totalMinutes} min',
              detail: '${recipe.prepMinutes} prep, ${recipe.cookMinutes} cook',
            ),
            RecipePill(label: recipe.difficulty.label),
            if (timesCooked > 0)
              RecipePill(label: timesCooked == 1 ? 'Cooked once' : 'Cooked $timesCooked times'),
          ],
        ),
      ),
      if (recipe.nutrition != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: NutritionRow(
            nutrition: recipe.nutrition!,
            dailyTargetKcal: ref.watch(dailyTargetProvider),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _tweak,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Tweak'),
                style: _actionStyle(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _addToList,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text('Add to list', overflow: TextOverflow.ellipsis),
                style: _actionStyle(),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxxl, bottom: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Ingredients',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ServingsStepper(
              servings: _servings,
              onChanged: (value) => setState(() => _servings = value),
            ),
          ],
        ),
      ),
      for (var i = 0; i < recipe.ingredients.length; i++)
        IngredientRow(
          ingredient: recipe.ingredients[i],
          quantity: scaledQuantity(
            recipe.ingredients[i],
            baseServings: recipe.servings,
            servings: _servings,
          ),
          gathered: _gathered.contains(i),
          onToggle: () => setState(() {
            if (!_gathered.remove(i)) _gathered.add(i);
          }),
          groceryItems: groceryItems,
        ),
      if (recipe.steps.isNotEmpty) ...[
        section('Method'),
        MethodPreview(steps: recipe.steps, accent: accent),
      ],
      if (recipe.tips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: TipsCard(tips: recipe.tips),
        ),
      const SizedBox(height: AppSpacing.xxxl),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blocks
            .animate(interval: 40.ms)
            .fadeIn(duration: 320.ms)
            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  ButtonStyle _actionStyle() => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
  );
}
