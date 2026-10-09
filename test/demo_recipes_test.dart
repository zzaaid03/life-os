import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/demo/data/demo_recipes.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

void main() {
  test('every demo recipe survives parsing intact and exercises cook mode', () {
    for (final map in demoRecipeMaps) {
      final raw = map['steps'] as List<dynamic>;
      final recipe = Recipe.fromJson(map);
      expect(recipe.steps.length, raw.length, reason: '${recipe.title}: a step was dropped');
      expect(recipe.ingredients, isNotEmpty);
      for (var i = 0; i < raw.length; i++) {
        final rawIdx = (raw[i] as Map<String, dynamic>)['ingredients'] as List<dynamic>? ?? [];
        expect(
          recipe.steps[i].ingredientIndexes.length,
          rawIdx.toSet().length,
          reason: '${recipe.title} step ${i + 1}: an ingredient index is out of range',
        );
      }
      expect(recipe.steps.where((s) => s.hasTimer).length, greaterThanOrEqualTo(2));
    }
  });

  test('one demo recipe has a 30 second timer so visitors see one finish', () {
    final timers = demoRecipeMaps
        .map(Recipe.fromJson)
        .expand((r) => r.steps)
        .map((s) => s.timerSeconds);
    expect(timers, contains(30));
  });
}
