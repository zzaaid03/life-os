/// The Recipes tab of the Groceries screen.
///
/// Top: the last generated idea (so an unsaved recipe survives pressing
/// back), then the ask area, which turns into an animated "chef is cooking"
/// scene while a recipe generates. When the recipe arrives, its badge takes
/// the orb's place and flies into the recipe page. Below: saved recipes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/widgets/error_snackbar.dart';
import 'package:life_os/features/groceries/domain/providers/grocery_provider.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/recipe_chef_service.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:life_os/features/recipes/presentation/recipe_routes.dart';
import 'package:life_os/features/recipes/presentation/widgets/tab/chef_cooking_scene.dart';
import 'package:life_os/features/recipes/presentation/widgets/tab/last_recipe_provider.dart';
import 'package:life_os/features/recipes/presentation/widgets/tab/recipe_cards.dart';

enum _Phase { ask, cooking, landing, error }

/// One generate request, kept so "Try again" can repeat it exactly.
class _Request {
  const _Request({this.prompt, this.pantry, this.chips = const [], this.surprise = false});

  final String? prompt;
  final String? pantry;
  final List<RecipeChip> chips;
  final bool surprise;
}

/// Ask the chef for a recipe, and browse saved ones.
class RecipesTab extends ConsumerStatefulWidget {
  /// Creates a [RecipesTab].
  const RecipesTab({super.key});

  @override
  ConsumerState<RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<RecipesTab>
    with AutomaticKeepAliveClientMixin {
  final _prompt = TextEditingController();
  final _pantry = TextEditingController();
  final Set<RecipeChip> _chips = {};
  bool _usePantry = false;

  _Phase _phase = _Phase.ask;
  _Request? _lastRequest;
  String? _error;

  /// The recipe currently sitting where the orb was, about to fly.
  Recipe? _landed;
  String? _landedTag;

  /// Bumped on every request and on Cancel; a result whose token is stale
  /// is ignored.
  int _token = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _prompt.addListener(_onTextChanged);
    _pantry.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _prompt.dispose();
    _pantry.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canCook =>
      _prompt.text.trim().isNotEmpty ||
      _chips.isNotEmpty ||
      (_usePantry && _pantry.text.trim().isNotEmpty);

  void _cook() {
    _run(
      _Request(
        prompt: _prompt.text,
        pantry: _usePantry ? _pantry.text : null,
        chips: _chips.toList(),
      ),
    );
  }

  void _surprise() {
    _run(
      _Request(
        pantry: _usePantry ? _pantry.text : null,
        chips: _chips.toList(),
        surprise: true,
      ),
    );
  }

  Future<void> _run(_Request request) async {
    FocusScope.of(context).unfocus();
    final token = ++_token;
    setState(() {
      _lastRequest = request;
      _phase = _Phase.cooking;
      _error = null;
    });

    final Recipe recipe;
    try {
      recipe = await ref.read(recipeChefServiceProvider).generate(
        prompt: request.prompt,
        pantry: request.pantry,
        chips: request.chips,
        surprise: request.surprise,
      );
    } on RecipeChefException catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
      });
      return;
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _phase = _Phase.error;
        _error = '$e';
      });
      return;
    }
    if (!mounted || token != _token) return;

    final tag = recipeHeroTag(recipe);
    ref.read(lastGeneratedRecipeProvider.notifier).state = recipe;
    setState(() {
      _phase = _Phase.landing;
      _landed = recipe;
      _landedTag = tag;
    });

    // Let the badge paint once in the orb's place, then fly it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || token != _token) return;
      await context.push(
        AppRoutes.recipeDetail,
        extra: RecipeViewArgs(recipe: recipe, heroTag: tag),
      );
      // Reset only once the page is popped: until then the landed badge is
      // the Hero the return flight looks for, and the last-idea card (same
      // tag) stays hidden so the tag is never on screen twice.
      if (!mounted || token != _token) return;
      setState(() {
        _phase = _Phase.ask;
        _landed = null;
        _landedTag = null;
      });
    });
  }

  void _cancel() {
    _token++;
    setState(() => _phase = _Phase.ask);
  }

  void _retry() {
    final request = _lastRequest;
    if (request != null) _run(request);
  }

  void _addCheckedGroceries(List<String> names) {
    final current = _pantry.text.trim();
    final have = current
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    final fresh = names.where((n) => !have.contains(n.trim().toLowerCase()));
    if (fresh.isEmpty) return;
    final joined = fresh.join(', ');
    final text = current.isEmpty
        ? joined
        : '${current.endsWith(',') ? current : '$current,'} $joined';
    _pantry.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _openRecipe(Recipe recipe, String tag, {SavedRecipe? saved}) {
    context.push(
      AppRoutes.recipeDetail,
      extra: RecipeViewArgs(recipe: recipe, heroTag: tag, saved: saved),
    );
  }

  Future<void> _confirmDelete(SavedRecipe saved) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this recipe?'),
        content: Text('"${saved.recipe.title}" will be removed from your recipes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(savedRecipesProvider.notifier).delete(saved.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the recipe.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final last = ref.watch(lastGeneratedRecipeProvider);
    final saved = ref.watch(savedRecipesProvider);
    listenForRefreshError(ref, context, savedRecipesProvider.select((s) => s.status == SavedRecipesStatus.loaded ? s.error : null));
    final showLast = last != null && (_phase == _Phase.ask || _phase == _Phase.error);

    return RefreshIndicator(
      onRefresh: () => ref.read(savedRecipesProvider.notifier).refresh(),
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverList.list(
              children: [
                if (showLast) ...[
                  LastIdeaCard(
                    recipe: last,
                    heroTag: recipeHeroTag(last),
                    onTap: () => _openRecipe(last, recipeHeroTag(last)),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0),
                  const SizedBox(height: AppSpacing.xl),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _buildTop(),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  'Your recipes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          _buildSaved(saved),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.massive)),
        ],
      ),
    );
  }

  Widget _buildTop() {
    switch (_phase) {
      case _Phase.cooking:
      case _Phase.landing:
        return ChefCookingScene(
          key: const ValueKey('cooking'),
          landed: _landed,
          heroTag: _landedTag,
          onCancel: _cancel,
        );
      case _Phase.error:
        return _ChefErrorCard(
          key: const ValueKey('error'),
          message: _error ?? 'Something went wrong.',
          onRetry: _retry,
          onBack: () => setState(() => _phase = _Phase.ask),
        );
      case _Phase.ask:
        return KeyedSubtree(key: const ValueKey('ask'), child: _buildAsk());
    }
  }

  Widget _buildAsk() {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final prefs = ref.watch(foodPreferencesProvider);
    final checkedNames = ref
        .watch(groceryListProvider)
        .items
        .where((i) => i.checked)
        .map((i) => i.name)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you feel like?',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _prompt,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Something cosy with chicken…',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final chip in RecipeChip.values)
              FilterChip(
                label: Text(chip.label),
                selected: _chips.contains(chip),
                onSelected: (on) => setState(() => on ? _chips.add(chip) : _chips.remove(chip)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use what I have'),
          value: _usePantry,
          onChanged: (on) => setState(() => _usePantry = on),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _usePantry
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _pantry,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "What's in your fridge?",
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (checkedNames.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _addCheckedGroceries(checkedNames),
                        icon: const Icon(Icons.shopping_basket_outlined, size: 18),
                        label: const Text('Add what I just bought'),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (prefs.value != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cooking for: ${prefs.value}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.settings),
                child: const Text('Edit'),
              ),
            ],
          )
        else if (prefs.loaded)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: muted,
            ),
            onPressed: () => context.push(AppRoutes.settings),
            child: const Text('Add food preferences'),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _canCook ? _cook : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                ),
                child: const Text('Cook something up'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton.tonal(
              onPressed: _surprise,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.lg,
                ),
              ),
              child: const Text('🎲 Surprise me'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaved(SavedRecipesState state) {
    const horizontal = EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal);
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      mainAxisExtent: 196,
    );

    if (state.status == SavedRecipesStatus.loading && state.recipes.isEmpty) {
      return SliverPadding(
        padding: horizontal,
        sliver: SliverGrid(
          gridDelegate: gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (_, _) => const SavedRecipePlaceholder(),
            childCount: 4,
          ),
        ),
      );
    }

    if (state.status == SavedRecipesStatus.error && state.recipes.isEmpty) {
      return SliverPadding(
        padding: horizontal,
        sliver: SliverToBoxAdapter(
          child: _SavedMessage(
            message: state.error ?? 'Failed to load your recipes.',
            onRetry: () => ref.read(savedRecipesProvider.notifier).refresh(),
          ),
        ),
      );
    }

    if (state.recipes.isEmpty) {
      return const SliverPadding(
        padding: horizontal,
        sliver: SliverToBoxAdapter(
          child: _SavedMessage(message: 'Recipes you save will live here'),
        ),
      );
    }

    return SliverPadding(
      padding: horizontal,
      sliver: SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final s = state.recipes[index];
            final tag = recipeHeroTag(s.recipe, saved: s);
            final delay = (index.clamp(0, 8) * 60).ms;
            return SavedRecipeCard(
              key: ValueKey(s.id),
              saved: s,
              heroTag: tag,
              onTap: () => _openRecipe(s.recipe, tag, saved: s),
              onLongPress: () => _confirmDelete(s),
            )
                .animate(delay: delay)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, end: 0, duration: 300.ms);
          },
          childCount: state.recipes.length,
        ),
      ),
    );
  }
}

class _ChefErrorCard extends StatelessWidget {
  const _ChefErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧑‍🍳', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'The chef hit a snag',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // The raw provider error, shown on purpose: it is how outages get
          // diagnosed.
          SelectableText(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedMessage extends StatelessWidget {
  const _SavedMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            onRetry == null ? '📖' : '😕',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
