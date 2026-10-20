/// Riverpod providers for saved recipes and food preferences.
///
/// Same load/auto-load pattern as `grocery_provider.dart`.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/repositories/recipe_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Loading status of the saved recipes.
enum SavedRecipesStatus { loading, loaded, error }

/// State managed by [SavedRecipesNotifier].
class SavedRecipesState {
  /// Creates a [SavedRecipesState].
  const SavedRecipesState({
    this.status = SavedRecipesStatus.loading,
    this.recipes = const [],
    this.error,
  });

  /// Loading status.
  final SavedRecipesStatus status;

  /// Saved recipes, newest first.
  final List<SavedRecipe> recipes;

  /// Error message when loading failed.
  final String? error;
}

/// Loads and mutates saved recipes.
class SavedRecipesNotifier extends StateNotifier<SavedRecipesState> {
  /// Creates a [SavedRecipesNotifier].
  SavedRecipesNotifier(this._repository) : super(const SavedRecipesState());

  final RecipeRepository _repository;
  String? _userId;

  /// Loads for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.recipes.isNotEmpty && state.error != null) {
      state = SavedRecipesState(status: SavedRecipesStatus.loaded, recipes: state.recipes);
    }
    try {
      final recipes = await _repository.getAll(userId);
      state = SavedRecipesState(status: SavedRecipesStatus.loaded, recipes: recipes);
    } catch (e) {
      debugPrint('Saved recipes load failed: $e');
      state = state.recipes.isNotEmpty
          ? SavedRecipesState(
              status: SavedRecipesStatus.loaded,
              recipes: state.recipes,
              error: "Couldn't refresh your recipes. Check your connection and try again.",
            )
          : const SavedRecipesState(
              status: SavedRecipesStatus.error,
              error: 'Failed to load your recipes.',
            );
    }
  }

  /// Reloads for the last user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId != null) await load(userId);
  }

  String _requireUser() {
    final userId = _userId;
    if (userId == null) throw StateError('No user loaded');
    return userId;
  }

  /// Saves [recipe] and returns the stored row, so the caller can switch
  /// from "unsaved" to "saved" (and to the saved Hero tag).
  Future<SavedRecipe> save(Recipe recipe) async {
    final saved = await _repository.save(_requireUser(), recipe);
    state = SavedRecipesState(
      status: SavedRecipesStatus.loaded,
      recipes: [saved, ...state.recipes],
    );
    return saved;
  }

  /// Replaces a saved recipe's content (a kept tweak).
  Future<SavedRecipe> replace(SavedRecipe saved, Recipe recipe) async {
    final updated = await _repository.replace(saved.id, recipe);
    _swap(updated);
    return updated;
  }

  /// Records a finished cook.
  Future<SavedRecipe> markCooked(SavedRecipe saved) async {
    final updated = await _repository.markCooked(saved);
    _swap(updated);
    return updated;
  }

  /// Deletes a saved recipe.
  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = SavedRecipesState(
      status: state.status,
      recipes: state.recipes.where((r) => r.id != id).toList(),
    );
  }

  void _swap(SavedRecipe updated) {
    state = SavedRecipesState(
      status: state.status,
      recipes: [for (final r in state.recipes) r.id == updated.id ? updated : r],
    );
  }
}

/// Provides the [SavedRecipesNotifier].
final savedRecipesProvider =
    StateNotifierProvider<SavedRecipesNotifier, SavedRecipesState>((ref) {
      final notifier = SavedRecipesNotifier(ref.watch(recipeRepositoryProvider));
      _autoLoad(ref, notifier.load);
      return notifier;
    });

/// The saved row for a recipe id, or null. Lets the recipe page and cook mode
/// see the latest times-cooked count without holding a stale copy.
final savedRecipeByIdProvider = Provider.family<SavedRecipe?, String>((ref, id) {
  for (final r in ref.watch(savedRecipesProvider).recipes) {
    if (r.id == id) return r;
  }
  return null;
});

/// State of the food-preferences line.
class FoodPreferencesState {
  /// Creates a [FoodPreferencesState].
  const FoodPreferencesState({
    this.loaded = false,
    this.value,
    this.loadFailed = false,
  });

  /// Whether the first load finished (successfully or not).
  final bool loaded;

  /// True when the load failed, so a null [value] means "unknown", not "unset".
  final bool loadFailed;

  /// The line, or null when unset.
  final String? value;
}

/// Loads and saves the user's food-preferences line.
class FoodPreferencesNotifier extends StateNotifier<FoodPreferencesState> {
  /// Creates a [FoodPreferencesNotifier].
  FoodPreferencesNotifier(this._repository) : super(const FoodPreferencesState());

  final FoodPreferencesRepository _repository;
  String? _userId;

  /// Loads for [userId]. A failure marks loaded with [FoodPreferencesState.loadFailed]
  /// set, so the dialog can refuse to save over preferences it never saw.
  Future<void> load(String userId) async {
    _userId = userId;
    try {
      final value = await _repository.get(userId);
      state = FoodPreferencesState(loaded: true, value: value);
    } catch (e) {
      debugPrint('Food preferences load failed: $e');
      state = FoodPreferencesState(
        loaded: true,
        value: state.value,
        loadFailed: true,
      );
    }
  }

  /// Saves [value] (blank clears it). Throws on failure so the caller can
  /// say so; the stored value only changes once the write succeeded.
  Future<void> save(String? value) async {
    final userId = _userId;
    if (userId == null) throw StateError('No user loaded');
    if (state.loadFailed) throw StateError('Preferences never loaded');
    await _repository.set(userId, value);
    final trimmed = value?.trim();
    state = FoodPreferencesState(
      loaded: true,
      value: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }
}

/// Provides the [FoodPreferencesNotifier].
final foodPreferencesProvider =
    StateNotifierProvider<FoodPreferencesNotifier, FoodPreferencesState>((ref) {
      final notifier = FoodPreferencesNotifier(ref.watch(foodPreferencesRepositoryProvider));
      _autoLoad(ref, notifier.load);
      return notifier;
    });

/// Loads on a real sign-in change, plus eagerly when a session was restored
/// before the provider existed (where `ref.listen` never fires).
void _autoLoad(Ref ref, Future<void> Function(String userId) load) {
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.isAuthenticated &&
        next.userId != null &&
        (previous == null || !previous.isAuthenticated || previous.userId != next.userId)) {
      load(next.userId!);
    }
  });
  final current = ref.read(authProvider);
  if (current.isAuthenticated && current.userId != null) {
    Future.microtask(() => load(current.userId!));
  }
}
