/// In-memory demo override of [RecipeChefService]: plays a realistic
/// thinking beat then returns canned answers. Never calls the `recipe-chef`
/// edge function.
library;

import 'dart:math';

import 'package:life_os/features/demo/data/demo_recipes.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/recipe_chef_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [RecipeChefService] that never hits the network. All three methods are
/// overridden and none of them calls the base class.
class DemoRecipeChefService extends RecipeChefService {
  /// Creates a [DemoRecipeChefService].
  DemoRecipeChefService() : super(Supabase.instance.client);

  int _next = 0;
  final Random _random = Random();

  @override
  Future<Recipe> generate({
    String? prompt,
    String? pantry,
    List<RecipeChip> chips = const [],
    bool surprise = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (surprise) return demoRecipe(_random.nextInt(demoRecipeMaps.length));
    return demoRecipe(_next++);
  }

  @override
  Future<Recipe> tweak(Recipe recipe, String instruction) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final json = recipe.toJson();
    return Recipe.fromJson({
      ...json,
      'title': 'Spicy ${recipe.title}',
      'description':
          '${recipe.description} Made spicier with a pinch of chili flakes.'
              .trim(),
      'ingredients': [
        ...json['ingredients'] as List<dynamic>,
        {'name': 'chili flakes', 'amount': 1, 'unit': 'tsp'},
      ],
    });
  }

  @override
  Future<String> ask(Recipe recipe, String question, {int? stepIndex}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (stepIndex != null) {
      return 'For step ${stepIndex + 1}, take it at your own pace. Keep the '
          'heat moderate and go by look and smell as well as the timer. If '
          'it starts to catch, turn the heat down a little and stir.';
    }
    return 'Good question. Get every ingredient prepped and measured before '
        'you start, and you can swap anything you are missing for something '
        'similar you already have.';
  }
}
