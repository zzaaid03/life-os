import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/scaling.dart';

GroceryItem _item(String name, {bool checked = false}) => GroceryItem(
  id: name,
  userId: 'u',
  name: name,
  checked: checked,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('formatFraction', () {
    test('whole numbers stay whole', () {
      expect(formatFraction(3), '3');
      expect(formatFraction(2.97), '3');
    });
    test('nearest kitchen fraction', () {
      expect(formatFraction(1.5), '1½');
      expect(formatFraction(0.33), '⅓');
      expect(formatFraction(0.7), '⅔');
      expect(formatFraction(2.75), '2¾');
      expect(formatFraction(0.25), '¼');
    });
    test('a tiny amount is never shown as zero', () {
      expect(formatFraction(0.05), '¼');
    });
  });

  group('formatQuantity', () {
    test('grams round sensibly and roll over to kg', () {
      expect(formatQuantity(40, 'g'), '40 g');
      expect(formatQuantity(333.3, 'g'), '335 g');
      expect(formatQuantity(1500, 'g'), '1.5 kg');
      expect(formatQuantity(1000, 'ml'), '1 l');
      expect(formatQuantity(0.4, 'g'), '1 g');
    });
    test('spoons and counts use fractions', () {
      expect(formatQuantity(1.5, 'tbsp'), '1½ tbsp');
      expect(formatQuantity(0.5, 'tsp'), '½ tsp');
      expect(formatQuantity(4.5, null), '4½');
    });
    test('kg keeps up to two decimals', () {
      expect(formatQuantity(1.25, 'kg'), '1.25 kg');
      expect(formatQuantity(2.0, 'kg'), '2 kg');
    });
  });

  group('scaledQuantity', () {
    test('scales from base servings', () {
      const egg = RecipeIngredient(name: 'eggs', amount: 3);
      expect(scaledQuantity(egg, baseServings: 1, servings: 2), '6');
      const feta = RecipeIngredient(name: 'feta', amount: 30, unit: 'g');
      expect(scaledQuantity(feta, baseServings: 2, servings: 5), '75 g');
    });
    test('"to taste" never scales', () {
      const salt = RecipeIngredient(name: 'salt', staple: true);
      expect(scaledQuantity(salt, baseServings: 2, servings: 8), isNull);
    });
  });

  group('isOnGroceryList', () {
    test('matches plurals and case', () {
      expect(isOnGroceryList('egg', [_item('Eggs')]), isTrue);
      expect(isOnGroceryList('cherry tomatoes', [_item('Cherry tomato')]), isTrue);
    });
    test('matches when one name contains the other as words', () {
      expect(isOnGroceryList('baby spinach', [_item('Spinach')]), isTrue);
      expect(isOnGroceryList('spinach', [_item('baby spinach')]), isTrue);
    });
    test('does not match part of a word', () {
      expect(isOnGroceryList('oil', [_item('Foil')]), isFalse);
    });
    test('checked items do not count, they were already bought', () {
      expect(isOnGroceryList('eggs', [_item('Eggs', checked: true)]), isFalse);
    });
    test('preselect skips staples, owned and listed items', () {
      const salt = RecipeIngredient(name: 'salt', staple: true);
      const egg = RecipeIngredient(name: 'eggs', amount: 3, have: true);
      const feta = RecipeIngredient(name: 'feta', amount: 30, unit: 'g');
      const milk = RecipeIngredient(name: 'milk', amount: 200, unit: 'ml');
      final list = [_item('Milk')];
      expect(shouldPreselectForList(salt, list), isFalse);
      expect(shouldPreselectForList(egg, list), isFalse);
      expect(shouldPreselectForList(milk, list), isFalse);
      expect(shouldPreselectForList(feta, list), isTrue);
    });
  });

  group('Recipe.fromJson', () {
    test('drops bad step indexes and tiny timers', () {
      final r = Recipe.fromJson({
        'title': 'Test',
        'servings': 2,
        'ingredients': [
          {'name': 'a', 'amount': 1},
          {'name': 'b', 'amount': -1},
        ],
        'steps': [
          {'text': 'one', 'timerSeconds': 3, 'ingredients': [0, 1, 7, 0]},
          {'text': 'two', 'timerSeconds': 600},
        ],
      });
      expect(r.ingredients[1].amount, isNull);
      expect(r.steps[0].ingredientIndexes, [0, 1]);
      expect(r.steps[0].hasTimer, isFalse);
      expect(r.steps[1].timerSeconds, 600);
      expect(r.steps[1].timerLabel, 'Timer');
    });
    test('survives garbage without throwing', () {
      final r = Recipe.fromJson({'gradient': 'red', 'servings': 'many', 'steps': 'no'});
      expect(r.title, 'Untitled recipe');
      expect(r.servings, 2);
      expect(r.steps, isEmpty);
      expect(r.gradient.length, 2);
    });
    test('round-trips through toJson', () {
      final original = Recipe.fromJson({
        'title': 'Omelette',
        'emoji': '🍳',
        'gradient': ['#F9D976', '#7FB069'],
        'servings': 1,
        'difficulty': 'medium',
        'ingredients': [
          {'name': 'eggs', 'amount': 3, 'have': true},
        ],
        'steps': [
          {'text': 'Cook', 'timerSeconds': 120, 'timerLabel': 'Set eggs', 'ingredients': [0]},
        ],
      });
      final again = Recipe.fromJson(original.toJson());
      expect(again.toJson(), original.toJson());
      expect(again.toJson()['gradient'], ['#F9D976', '#7FB069']);
    });
  });
}
