/// The "Add to grocery list" sheet: every ingredient with a checkbox,
/// pre-ticked with what the user probably needs to buy.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/scaling.dart';
import 'package:life_os/features/recipes/presentation/widgets/detail/recipe_pills.dart';

/// Shows the sheet. Resolves to the drafts to add, or null if dismissed.
/// Adding them is the caller's job, so failures surface on the page.
abstract final class AddToListSheet {
  /// Shows the sheet for [recipe] at [servings].
  static Future<List<GroceryDraft>?> show(
    BuildContext context, {
    required Recipe recipe,
    required int servings,
    required List<GroceryItem> groceryItems,
  }) {
    return showModalBottomSheet<List<GroceryDraft>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (_) => _AddToListBody(
        recipe: recipe,
        servings: servings,
        groceryItems: groceryItems,
      ),
    );
  }
}

class _AddToListBody extends StatefulWidget {
  const _AddToListBody({
    required this.recipe,
    required this.servings,
    required this.groceryItems,
  });

  final Recipe recipe;
  final int servings;
  final List<GroceryItem> groceryItems;

  @override
  State<_AddToListBody> createState() => _AddToListBodyState();
}

class _AddToListBodyState extends State<_AddToListBody> {
  late final Set<int> _selected = {
    for (var i = 0; i < widget.recipe.ingredients.length; i++)
      if (shouldPreselectForList(widget.recipe.ingredients[i], widget.groceryItems)) i,
  };

  String? _quantity(RecipeIngredient ingredient) => scaledQuantity(
    ingredient,
    baseServings: widget.recipe.servings,
    servings: widget.servings,
  );

  void _submit() {
    final ingredients = widget.recipe.ingredients;
    final drafts = [
      for (var i = 0; i < ingredients.length; i++)
        if (_selected.contains(i))
          GroceryDraft(
            name: _capitalise(ingredients[i].name),
            quantity: _quantity(ingredients[i]),
          ),
    ];
    Navigator.of(context).pop(drafts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ingredients = widget.recipe.ingredients;
    final count = _selected.length;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: Text(
              'Add to grocery list',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
            child: Text(
              'For ${widget.servings} ${widget.servings == 1 ? 'serving' : 'servings'}. '
              'Staples and things you have are left unticked.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ingredients.length,
              itemBuilder: (context, i) {
                final ingredient = ingredients[i];
                final quantity = _quantity(ingredient);
                final tags = ingredientTags(context, ingredient, widget.groceryItems);
                return CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: (value) => setState(() {
                    if (value ?? false) {
                      _selected.add(i);
                    } else {
                      _selected.remove(i);
                    }
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        if (quantity != null)
                          TextSpan(
                            text: '$quantity  ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        TextSpan(text: ingredient.name),
                      ],
                    ),
                  ),
                  subtitle: tags.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: tags,
                          ),
                        ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: count == 0 ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(count == 1 ? 'Add 1 item' : 'Add $count items'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalise(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
