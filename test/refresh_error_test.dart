import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/data/repositories/grocery_repository.dart';
import 'package:life_os/features/groceries/domain/providers/grocery_provider.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/data/repositories/recipe_repository.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';

class _FlakyGroceryRepository implements GroceryRepository {
  bool fail = false;

  @override
  Future<List<GroceryItem>> getAll(String userId) async {
    if (fail) throw Exception('offline');
    return [
      GroceryItem(
        id: '1',
        userId: userId,
        name: 'Milk',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FlakyRecipeRepository implements RecipeRepository {
  bool fail = false;

  @override
  Future<List<SavedRecipe>> getAll(String userId) async {
    if (fail) throw Exception('offline');
    return [
      SavedRecipe(
        id: '1',
        userId: userId,
        recipe: Recipe.fromJson(const {}),
        timesCooked: 0,
        createdAt: DateTime.utc(2026),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('grocery refresh failure keeps the list and sets an error', () async {
    final repo = _FlakyGroceryRepository();
    final notifier = GroceryListNotifier(repo);
    await notifier.load('u');
    expect(notifier.state.items, hasLength(1));

    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.status, GroceryListStatus.loaded);
    expect(notifier.state.items, hasLength(1));
    expect(notifier.state.error, isNotNull);
  });

  test('saved recipes refresh failure keeps the list and sets an error', () async {
    final repo = _FlakyRecipeRepository();
    final notifier = SavedRecipesNotifier(repo);
    await notifier.load('u');
    expect(notifier.state.recipes, hasLength(1));

    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.status, SavedRecipesStatus.loaded);
    expect(notifier.state.recipes, hasLength(1));
    expect(notifier.state.error, isNotNull);
  });
}
