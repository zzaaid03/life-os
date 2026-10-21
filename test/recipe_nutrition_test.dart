import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

Map<String, dynamic> _recipeJson({Object? nutrition, bool withNutrition = true}) => {
  'title': 'Pasta',
  'servings': 2,
  'ingredients': [
    {'name': 'pasta', 'amount': 200, 'unit': 'g'},
  ],
  'steps': [
    {'text': 'Boil the pasta.'},
  ],
  if (withNutrition) 'nutrition': nutrition,
};

const _valid = {'kcal': 620, 'protein': 28, 'carbs': 60, 'fat': 22};

void main() {
  test('parses a valid nutrition block', () {
    final n = Recipe.fromJson(_recipeJson(nutrition: _valid)).nutrition;
    expect(n, isNotNull);
    expect(n!.kcal, 620);
    expect(n.protein, 28);
    expect(n.carbs, 60);
    expect(n.fat, 22);
  });

  test('rounds fractional values', () {
    final n = RecipeNutrition.fromJson({'kcal': 619.6, 'protein': 27.5, 'carbs': 60.2, 'fat': 21.9});
    expect(n!.kcal, 620);
    expect(n.protein, 28);
    expect(n.carbs, 60);
    expect(n.fat, 22);
  });

  test('missing nutrition (old recipe) is null and the recipe still parses', () {
    final r = Recipe.fromJson(_recipeJson(withNutrition: false));
    expect(r.nutrition, isNull);
    expect(r.title, 'Pasta');
    expect(r.ingredients, hasLength(1));
  });

  test('null, wrong-typed or out-of-range values give null', () {
    expect(RecipeNutrition.fromJson(null), isNull);
    expect(RecipeNutrition.fromJson('620 kcal'), isNull);
    expect(RecipeNutrition.fromJson({..._valid, 'kcal': '620'}), isNull);
    expect(RecipeNutrition.fromJson({..._valid, 'protein': null}), isNull);
    expect(RecipeNutrition.fromJson({'kcal': 620}), isNull);
    expect(RecipeNutrition.fromJson({..._valid, 'kcal': 0}), isNull);
    expect(RecipeNutrition.fromJson({..._valid, 'kcal': 5001}), isNull);
    expect(RecipeNutrition.fromJson({..._valid, 'fat': -1}), isNull);
    expect(RecipeNutrition.fromJson({..._valid, 'carbs': 1001}), isNull);
    expect(Recipe.fromJson(_recipeJson(nutrition: {..._valid, 'kcal': 9999})).nutrition, isNull);
  });

  test('toJson round-trip keeps nutrition', () {
    final r = Recipe.fromJson(_recipeJson(nutrition: _valid));
    final back = Recipe.fromJson(r.toJson());
    expect(back.nutrition, isNotNull);
    expect(back.nutrition!.toJson(), _valid);
  });

  test('a recipe without nutrition has no nutrition key in toJson', () {
    final r = Recipe.fromJson(_recipeJson(withNutrition: false));
    expect(r.toJson().containsKey('nutrition'), isFalse);
  });
}
