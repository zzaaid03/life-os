/// Servings scaling and amount formatting for recipes, plus the "already on
/// the grocery list" check. Pure functions, unit tested in
/// `test/recipe_scaling_test.dart`.
///
/// Scaling happens here, never by asking the model again: it is instant,
/// free, and cannot change the dish.
library;

import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';

/// The text for [ingredient]'s amount scaled from the recipe's base servings
/// to [servings], e.g. "1.5 kg", "1½", "2 tbsp". Null for a "to taste"
/// ingredient, which never scales.
String? scaledQuantity(
  RecipeIngredient ingredient, {
  required int baseServings,
  required int servings,
}) {
  final amount = ingredient.amount;
  if (amount == null) return null;
  final scaled = amount * servings / baseServings;
  return formatQuantity(scaled, ingredient.unit);
}

/// Formats [amount] of [unit] for a cook to read.
///
/// - grams / millilitres: whole numbers, rounded to 5 from 100 up, and
///   rolled over to kg / l from 1000 ("1500 g" reads as "1.5 kg").
/// - kg / l: up to two decimals, trailing zeros dropped.
/// - spoons and plain counts: the nearest kitchen fraction ("1½", "¾ tsp"),
///   because nobody measures 0.67 of a teaspoon.
/// - any other unit: up to one decimal.
String formatQuantity(double amount, String? unit) {
  final u = unit?.trim();
  final lower = u?.toLowerCase();

  if (lower == 'g' || lower == 'ml') {
    if (amount >= 1000) {
      return '${_decimal(amount / 1000, 2)} ${lower == 'g' ? 'kg' : 'l'}';
    }
    final rounded = amount >= 100
        ? (amount / 5).round() * 5
        : (amount < 1 ? 1 : amount.round());
    return '$rounded $u';
  }

  if (lower == 'kg' || lower == 'l') return '${_decimal(amount, 2)} $u';

  if (u == null || lower == 'tsp' || lower == 'tbsp' || lower == 'cup' || lower == 'cups') {
    final text = formatFraction(amount);
    return u == null ? text : '$text $u';
  }

  return '${_decimal(amount, 1)} $u';
}

const _fractions = <(double, String)>[
  (0.25, '¼'),
  (1 / 3, '⅓'),
  (0.5, '½'),
  (2 / 3, '⅔'),
  (0.75, '¾'),
];

/// [value] as a whole number plus the nearest of ¼ ⅓ ½ ⅔ ¾, e.g. 1.5 → "1½",
/// 0.33 → "⅓", 2.9 → "3". Anything under ⅛ shows as "¼" rather than "0",
/// since the ingredient is still needed.
String formatFraction(double value) {
  var whole = value.floor();
  final rest = value - whole;

  String? glyph;
  var best = rest; // distance to rounding down to the whole number
  if (1 - rest < best) {
    best = 1 - rest;
    glyph = '';
  }
  for (final (fraction, text) in _fractions) {
    final d = (rest - fraction).abs();
    if (d < best) {
      best = d;
      glyph = text;
    }
  }

  if (glyph == '') {
    whole += 1;
    glyph = null;
  }
  if (whole == 0 && glyph == null) return '¼';
  if (whole == 0) return glyph!;
  return glyph == null ? '$whole' : '$whole$glyph';
}

String _decimal(double value, int places) {
  var text = value.toStringAsFixed(places);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

/// Lowercase, letters and spaces only, each word's simple plural stripped,
/// so "Eggs" and "egg" or "Cherry tomatoes" and "cherry tomato" compare equal.
String normalizeIngredientName(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(_singular)
      .join(' ');
}

String _singular(String word) {
  if (word.length > 4 && word.endsWith('oes')) return word.substring(0, word.length - 2);
  if (word.length > 3 && word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Whether [ingredientName] is already on the list as an UNCHECKED item.
/// Checked (already bought) items do not count.
///
/// Matches when the normalized names are equal or one contains the other as
/// whole words ("spinach" vs "baby spinach"). That can over-match ("pepper"
/// vs "bell pepper"), which is acceptable because the result only decides
/// what the add-to-list sheet pre-ticks; the user can always change it.
bool isOnGroceryList(String ingredientName, List<GroceryItem> items) {
  final target = normalizeIngredientName(ingredientName);
  if (target.isEmpty) return false;
  for (final item in items) {
    if (item.checked) continue;
    final name = normalizeIngredientName(item.name);
    if (name.isEmpty) continue;
    if (name == target || _containsWords(name, target) || _containsWords(target, name)) {
      return true;
    }
  }
  return false;
}

bool _containsWords(String haystack, String needle) =>
    ' $haystack '.contains(' $needle ');

/// Which ingredients the add-to-list sheet pre-ticks: not a staple, not
/// something the user said they have, and not already on the list.
bool shouldPreselectForList(RecipeIngredient ingredient, List<GroceryItem> list) =>
    !ingredient.staple && !ingredient.have && !isOnGroceryList(ingredient.name, list);
