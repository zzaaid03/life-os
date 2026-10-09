/// Client for the `recipe-chef` edge function.
///
/// A concrete class whose entire network surface is the three public
/// methods, so demo mode can subclass it and override all three with canned
/// answers and stay zero-network (same pattern as `GoalBreakdownService`).
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quick request chips the server understands. Anything else is ignored.
enum RecipeChip {
  /// 30 minutes or less.
  quick('Quick'),

  /// Light and nutritious.
  healthy('Healthy'),

  /// Hearty comfort food.
  comfort('Comfort food'),

  /// Budget friendly.
  cheap('On a budget');

  const RecipeChip(this.label);

  /// Display label.
  final String label;
}

/// Thrown for any recipe-chef failure. [message] is safe to show, and
/// includes the provider's raw detail when there is one: that raw line is
/// what diagnosed every past AI outage in this app, do not hide it.
class RecipeChefException implements Exception {
  /// Creates a [RecipeChefException].
  const RecipeChefException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// Talks to the AI chef.
class RecipeChefService {
  /// Creates a [RecipeChefService].
  const RecipeChefService(this.client);

  /// Supabase client; the user's JWT is attached automatically.
  final SupabaseClient client;

  /// Generates a new recipe. At least one of [prompt], [pantry], [chips] or
  /// [surprise] must be given.
  Future<Recipe> generate({
    String? prompt,
    String? pantry,
    List<RecipeChip> chips = const [],
    bool surprise = false,
  }) async {
    final map = await _invoke({
      'action': 'generate',
      if (prompt != null && prompt.trim().isNotEmpty) 'prompt': prompt.trim(),
      if (pantry != null && pantry.trim().isNotEmpty) 'pantry': pantry.trim(),
      'chips': chips.map((c) => c.name).toList(),
      'surprise': surprise,
    });
    return _recipeFrom(map);
  }

  /// Rewrites [recipe] per [instruction] ("make it spicier"). Returns the
  /// full revised recipe.
  Future<Recipe> tweak(Recipe recipe, String instruction) async {
    final map = await _invoke({
      'action': 'tweak',
      'recipe': recipe.toJson(),
      'instruction': instruction.trim(),
    });
    return _recipeFrom(map);
  }

  /// Answers a question about [recipe] while cooking. [stepIndex] is the
  /// step on screen, or null before the steps (e.g. during mise en place).
  Future<String> ask(Recipe recipe, String question, {int? stepIndex}) async {
    final map = await _invoke({
      'action': 'ask',
      'recipe': recipe.toJson(),
      'question': question.trim(),
      'stepIndex': ?stepIndex,
    });
    final answer = map['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw const RecipeChefException('The chef had no answer. Try again.');
    }
    return answer.trim();
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final FunctionResponse response;
    try {
      response = await client.functions.invoke('recipe-chef', body: body);
    } on FunctionException catch (e) {
      throw RecipeChefException(_describe(e.details) ?? 'The chef is unavailable (${e.status}).');
    } catch (e) {
      throw RecipeChefException('Could not reach the chef. ($e)');
    }
    final data = response.data;
    if (data is! Map) {
      throw const RecipeChefException('The chef returned nothing.');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['error'] != null && map['recipe'] == null && map['answer'] == null) {
      throw RecipeChefException(_describe(map) ?? 'The chef failed.');
    }
    return map;
  }

  Recipe _recipeFrom(Map<String, dynamic> map) {
    final raw = map['recipe'];
    if (raw is! Map) throw const RecipeChefException('The chef returned no recipe.');
    final recipe = Recipe.fromJson(Map<String, dynamic>.from(raw));
    if (recipe.ingredients.isEmpty || recipe.steps.isEmpty) {
      throw const RecipeChefException('The chef returned an incomplete recipe. Try again.');
    }
    return recipe;
  }

  static String? _describe(Object? details) {
    if (details is! Map) return details is String && details.isNotEmpty ? details : null;
    final error = details['error'];
    final detail = details['detail'];
    if (error == null) return null;
    return detail == null ? '$error' : '$error\n$detail';
  }
}

/// Provides the [RecipeChefService]. Demo mode overrides it.
final recipeChefServiceProvider = Provider<RecipeChefService>((ref) {
  return RecipeChefService(ref.watch(supabaseClientProvider));
});
