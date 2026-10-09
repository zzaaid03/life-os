/// In-memory [RecipeRepository] and [FoodPreferencesRepository] for the
/// sandbox demo mode.
///
/// Demo mode makes zero network calls. Without these overrides the recipes
/// tab would query Supabase with the fake `demo-user` id.
///
/// Seeded with two saved recipes for "Alex," one already cooked a few times,
/// and a food-preferences line so the chef has something to respect.
library;

import 'package:life_os/features/demo/data/demo_recipes.dart';
import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/repositories/recipe_repository.dart';

/// Saved recipes backed by an in-memory list.
class DemoRecipeRepository implements RecipeRepository {
  /// Creates a [DemoRecipeRepository] seeded with two saved recipes.
  DemoRecipeRepository() : _items = _buildDemoRecipes();

  final List<SavedRecipe> _items;

  int _nextId = 0;

  @override
  Future<List<SavedRecipe>> getAll(String userId) async {
    if (userId != demoUserId) return const [];
    final sorted = [..._items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  @override
  Future<SavedRecipe> save(String userId, Recipe recipe) async {
    final saved = SavedRecipe(
      id: 'demo-recipe-new-${_nextId++}',
      userId: demoUserId,
      recipe: recipe,
      timesCooked: 0,
      createdAt: DateTime.now(),
    );
    _items.add(saved);
    return saved;
  }

  @override
  Future<SavedRecipe> replace(String id, Recipe recipe) async {
    final index = _items.indexWhere((r) => r.id == id);
    if (index == -1) throw StateError('No saved recipe $id');
    final old = _items[index];
    final updated = SavedRecipe(
      id: old.id,
      userId: old.userId,
      recipe: recipe,
      timesCooked: old.timesCooked,
      lastCookedAt: old.lastCookedAt,
      createdAt: old.createdAt,
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<SavedRecipe> markCooked(SavedRecipe saved) async {
    final index = _items.indexWhere((r) => r.id == saved.id);
    final base = index == -1 ? saved : _items[index];
    final updated = SavedRecipe(
      id: base.id,
      userId: base.userId,
      recipe: base.recipe,
      timesCooked: base.timesCooked + 1,
      lastCookedAt: DateTime.now(),
      createdAt: base.createdAt,
    );
    if (index != -1) _items[index] = updated;
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((r) => r.id == id);
  }
}

/// Food preferences backed by a single in-memory value.
class DemoFoodPreferencesRepository implements FoodPreferencesRepository {
  String? _value = 'No mushrooms please';

  @override
  Future<String?> get(String userId) async => _value;

  @override
  Future<void> set(String userId, String? value) async {
    final trimmed = value?.trim();
    _value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

List<SavedRecipe> _buildDemoRecipes() {
  // Dates are relative to now so the seed never rots.
  final now = DateTime.now();
  return [
    SavedRecipe(
      id: 'demo-recipe-1',
      userId: demoUserId,
      recipe: demoRecipe(0),
      timesCooked: 3,
      lastCookedAt: now.subtract(const Duration(days: 4)),
      createdAt: now.subtract(const Duration(days: 21)),
    ),
    SavedRecipe(
      id: 'demo-recipe-2',
      userId: demoUserId,
      recipe: demoRecipe(2),
      timesCooked: 0,
      createdAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}
