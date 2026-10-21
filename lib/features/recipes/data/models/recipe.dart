/// The recipe model shared by the recipes tab, the recipe page and cook mode.
///
/// Its JSON shape is owned jointly with `supabase/functions/recipe-chef`,
/// whose `sanitizeRecipe()` guarantees it on the way out of the server.
/// [Recipe.fromJson] is still tolerant (missing or wrong-typed fields fall
/// back to safe defaults) because saved rows outlive any one version of the
/// prompt, and a single odd field must never make a saved recipe unopenable.
library;

import 'package:flutter/painting.dart';

/// How hard a recipe is.
enum RecipeDifficulty {
  /// Easy.
  easy,

  /// Medium.
  medium,

  /// Hard.
  hard;

  /// Parses the wire value, defaulting to [easy].
  static RecipeDifficulty parse(Object? value) => switch (value) {
    'medium' => medium,
    'hard' => hard,
    _ => easy,
  };

  /// A display label: "Easy", "Medium", "Hard".
  String get label => switch (this) {
    easy => 'Easy',
    medium => 'Medium',
    hard => 'Hard',
  };
}

/// One ingredient, at the recipe's base [Recipe.servings].
class RecipeIngredient {
  /// Creates a [RecipeIngredient].
  const RecipeIngredient({
    required this.name,
    this.amount,
    this.unit,
    this.prep,
    this.staple = false,
    this.have = false,
  });

  /// Parses one ingredient.
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return RecipeIngredient(
      name: (json['name'] as String?)?.trim() ?? '',
      amount: amount is num && amount > 0 ? amount.toDouble() : null,
      unit: _optString(json['unit']),
      prep: _optString(json['prep']),
      staple: json['staple'] == true,
      have: json['have'] == true,
    );
  }

  /// The ingredient, lowercase, e.g. "baby spinach".
  final String name;

  /// Amount at base servings. Null means "to taste" and never scales.
  final double? amount;

  /// Metric unit (g, kg, ml, l, tsp, tbsp) or null for a plain count.
  final String? unit;

  /// Preparation before cooking, e.g. "finely diced". Drives mise en place.
  final String? prep;

  /// Salt, pepper, oil, water: assumed to be in the kitchen already.
  final bool staple;

  /// The user said they have it ("use what I have").
  final bool have;

  /// Serialises back to the wire shape.
  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'prep': prep,
    'staple': staple,
    'have': have,
  };
}

/// One step of the method.
class RecipeStep {
  /// Creates a [RecipeStep].
  const RecipeStep({
    required this.text,
    this.timerSeconds,
    this.timerLabel,
    this.ingredientIndexes = const [],
  });

  /// Parses one step. Ingredient indexes outside [ingredientCount] are
  /// dropped so cook mode can index without checking.
  factory RecipeStep.fromJson(Map<String, dynamic> json, int ingredientCount) {
    final seconds = json['timerSeconds'];
    final timer = seconds is num && seconds >= 5 ? seconds.round() : null;
    final raw = json['ingredients'];
    return RecipeStep(
      text: (json['text'] as String?)?.trim() ?? '',
      timerSeconds: timer,
      timerLabel: timer == null ? null : (_optString(json['timerLabel']) ?? 'Timer'),
      ingredientIndexes: raw is List
          ? raw
                .whereType<num>()
                .map((n) => n.toInt())
                .where((i) => i >= 0 && i < ingredientCount)
                .toSet()
                .toList()
          : const [],
    );
  }

  /// What to do.
  final String text;

  /// Seconds to time, or null when the step has no waiting.
  final int? timerSeconds;

  /// A short timer name, e.g. "Simmer sauce". Non-null whenever
  /// [timerSeconds] is.
  final String? timerLabel;

  /// Indexes into [Recipe.ingredients] first used in this step. Always valid.
  final List<int> ingredientIndexes;

  /// Whether this step has a timer.
  bool get hasTimer => timerSeconds != null;

  /// Serialises back to the wire shape.
  Map<String, dynamic> toJson() => {
    'text': text,
    'timerSeconds': timerSeconds,
    'timerLabel': timerLabel,
    'ingredients': ingredientIndexes,
  };
}

/// An estimated nutrition block, per serving at the recipe's base servings.
class RecipeNutrition {
  /// Creates a [RecipeNutrition].
  const RecipeNutrition({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Parses a nutrition block. Returns null unless [json] is a map with all
  /// four values numeric and in range, so a bad block never breaks a recipe.
  static RecipeNutrition? fromJson(Object? json) {
    if (json is! Map) return null;
    final kcal = json['kcal'];
    final protein = json['protein'];
    final carbs = json['carbs'];
    final fat = json['fat'];
    if (kcal is! num || protein is! num || carbs is! num || fat is! num) return null;
    final k = kcal.round();
    final p = protein.round();
    final c = carbs.round();
    final f = fat.round();
    if (k < 1 || k > 5000) return null;
    if (p < 0 || p > 1000 || c < 0 || c > 1000 || f < 0 || f > 1000) return null;
    return RecipeNutrition(kcal: k, protein: p, carbs: c, fat: f);
  }

  /// Energy per serving.
  final int kcal;

  /// Protein per serving, in grams.
  final int protein;

  /// Carbohydrates per serving, in grams.
  final int carbs;

  /// Fat per serving, in grams.
  final int fat;

  /// Serialises back to the wire shape.
  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

/// A complete recipe, saved or not.
class Recipe {
  /// Creates a [Recipe].
  const Recipe({
    required this.title,
    required this.emoji,
    required this.description,
    required this.gradient,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    this.tips = const [],
    this.nutrition,
  });

  /// Parses a recipe. Never throws on a malformed field; see the library doc.
  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredients = _maps(json['ingredients'])
        .map(RecipeIngredient.fromJson)
        .where((i) => i.name.isNotEmpty)
        .toList();
    return Recipe(
      title: (json['title'] as String?)?.trim() ?? 'Untitled recipe',
      emoji: _optString(json['emoji']) ?? '🍽️',
      description: (json['description'] as String?)?.trim() ?? '',
      gradient: _parseGradient(json['gradient']),
      servings: _int(json['servings'], fallback: 2).clamp(1, 12),
      prepMinutes: _int(json['prepMinutes'], fallback: 0),
      cookMinutes: _int(json['cookMinutes'], fallback: 0),
      difficulty: RecipeDifficulty.parse(json['difficulty']),
      ingredients: ingredients,
      steps: _maps(json['steps'])
          .map((s) => RecipeStep.fromJson(s, ingredients.length))
          .where((s) => s.text.isNotEmpty)
          .toList(),
      tips: json['tips'] is List
          ? (json['tips'] as List).whereType<String>().toList()
          : const [],
      nutrition: RecipeNutrition.fromJson(json['nutrition']),
    );
  }

  /// The dish name.
  final String title;

  /// One emoji shown in the hero badge.
  final String emoji;

  /// One appetising sentence. Also where the chef explains a preference
  /// conflict or a refused tweak.
  final String description;

  /// Two colours for the hero badge background.
  final List<Color> gradient;

  /// The servings every [RecipeIngredient.amount] is written for.
  final int servings;

  /// Minutes of preparation.
  final int prepMinutes;

  /// Minutes of cooking.
  final int cookMinutes;

  /// How hard it is.
  final RecipeDifficulty difficulty;

  /// Ingredients at base [servings].
  final List<RecipeIngredient> ingredients;

  /// The method, in order.
  final List<RecipeStep> steps;

  /// Zero to three short tips.
  final List<String> tips;

  /// Estimated nutrition per serving at base [servings]. Null on older recipes.
  final RecipeNutrition? nutrition;

  /// Total minutes, prep plus cook.
  int get totalMinutes => prepMinutes + cookMinutes;

  /// Serialises back to the wire shape (sent to `recipe-chef` for tweak/ask
  /// and stored in `recipes.data`).
  Map<String, dynamic> toJson() => {
    'title': title,
    'emoji': emoji,
    'description': description,
    'gradient': gradient.map(_hex).toList(),
    'servings': servings,
    'prepMinutes': prepMinutes,
    'cookMinutes': cookMinutes,
    'difficulty': difficulty.name,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'tips': tips,
    if (nutrition != null) 'nutrition': nutrition!.toJson(),
  };
}

/// A recipe the user tapped Save on: a row in `public.recipes`.
class SavedRecipe {
  /// Creates a [SavedRecipe].
  const SavedRecipe({
    required this.id,
    required this.userId,
    required this.recipe,
    required this.timesCooked,
    this.lastCookedAt,
    required this.createdAt,
  });

  /// Parses a `public.recipes` row.
  factory SavedRecipe.fromRow(Map<String, dynamic> row) {
    final data = row['data'];
    return SavedRecipe(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      recipe: Recipe.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : const {},
      ),
      timesCooked: _int(row['times_cooked'], fallback: 0),
      lastCookedAt: row['last_cooked_at'] == null
          ? null
          : DateTime.parse(row['last_cooked_at'] as String).toLocal(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  /// Row id.
  final String id;

  /// Owning user.
  final String userId;

  /// The recipe itself.
  final Recipe recipe;

  /// How many times cook mode was finished for it.
  final int timesCooked;

  /// When it was last cooked.
  final DateTime? lastCookedAt;

  /// When it was saved.
  final DateTime createdAt;
}

/// The Hero tag shared by every widget showing [recipe]'s badge. A saved
/// recipe keys on its id so the tag survives rebuilds; an unsaved one keys
/// on the object, which is stable while it is passed between screens.
String recipeHeroTag(Recipe recipe, {SavedRecipe? saved}) =>
    saved != null ? 'recipe-hero-${saved.id}' : 'recipe-hero-${identityHashCode(recipe)}';

String? _optString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? value, {required int fallback}) =>
    value is num ? value.round() : fallback;

Iterable<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map<dynamic, dynamic>>().map(Map<String, dynamic>.from)
    : const [];

const _fallbackGradient = [Color(0xFFF6A15A), Color(0xFFD9534F)];

List<Color> _parseGradient(Object? value) {
  if (value is! List || value.length < 2) return _fallbackGradient;
  final colors = value.take(2).map(_parseHex).toList();
  if (colors.any((c) => c == null)) return _fallbackGradient;
  return colors.cast<Color>();
}

Color? _parseHex(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

String _hex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
