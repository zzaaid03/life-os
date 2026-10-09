/// Saved recipes and the user's food preferences.
///
/// Written before any screen exists so parallel worker lanes can build
/// against it. Demo mode overrides both providers.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Saved recipes (`public.recipes`). Rows are hard deleted.
abstract class RecipeRepository {
  /// Every saved recipe for [userId], newest first.
  Future<List<SavedRecipe>> getAll(String userId);

  /// Saves [recipe]. Only ever called from an explicit Save tap.
  Future<SavedRecipe> save(String userId, Recipe recipe);

  /// Replaces a saved recipe's content (after a tweak the user kept).
  Future<SavedRecipe> replace(String id, Recipe recipe);

  /// Records one finished cook: times_cooked + 1, last_cooked_at = now.
  Future<SavedRecipe> markCooked(SavedRecipe saved);

  /// Deletes a saved recipe.
  Future<void> delete(String id);
}

/// The user's own food-preferences line (`profiles.food_preferences`).
abstract class FoodPreferencesRepository {
  /// The line, or null when unset.
  Future<String?> get(String userId);

  /// Sets the line. An empty or blank [value] clears it.
  Future<void> set(String userId, String? value);
}

/// Supabase-backed [RecipeRepository].
class SupabaseRecipeRepository implements RecipeRepository {
  /// Creates a [SupabaseRecipeRepository].
  const SupabaseRecipeRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'recipes';

  @override
  Future<List<SavedRecipe>> getAll(String userId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SavedRecipe.fromRow)
        .toList();
  }

  @override
  Future<SavedRecipe> save(String userId, Recipe recipe) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'title': recipe.title,
          'emoji': recipe.emoji,
          'data': recipe.toJson(),
        })
        .select()
        .single();
    return SavedRecipe.fromRow(row);
  }

  @override
  Future<SavedRecipe> replace(String id, Recipe recipe) async {
    final row = await _client
        .from(_table)
        .update({
          'title': recipe.title,
          'emoji': recipe.emoji,
          'data': recipe.toJson(),
        })
        .eq('id', id)
        .select()
        .single();
    return SavedRecipe.fromRow(row);
  }

  @override
  Future<SavedRecipe> markCooked(SavedRecipe saved) async {
    final row = await _client
        .from(_table)
        .update({
          'times_cooked': saved.timesCooked + 1,
          'last_cooked_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', saved.id)
        .select()
        .single();
    return SavedRecipe.fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

/// Supabase-backed [FoodPreferencesRepository].
class SupabaseFoodPreferencesRepository implements FoodPreferencesRepository {
  /// Creates a [SupabaseFoodPreferencesRepository].
  const SupabaseFoodPreferencesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> get(String userId) async {
    final row = await _client
        .from('profiles')
        .select('food_preferences')
        .eq('id', userId)
        .maybeSingle();
    final value = row?['food_preferences'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  @override
  Future<void> set(String userId, String? value) async {
    final trimmed = value?.trim();
    // Only this one column: never send the whole Profile, which would
    // overwrite fields this screen knows nothing about.
    await _client
        .from('profiles')
        .update({
          'food_preferences': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        })
        .eq('id', userId);
  }
}

/// Provides the [RecipeRepository]. Demo mode overrides it.
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return SupabaseRecipeRepository(ref.watch(supabaseClientProvider));
});

/// Provides the [FoodPreferencesRepository]. Demo mode overrides it.
final foodPreferencesRepositoryProvider = Provider<FoodPreferencesRepository>((ref) {
  return SupabaseFoodPreferencesRepository(ref.watch(supabaseClientProvider));
});
