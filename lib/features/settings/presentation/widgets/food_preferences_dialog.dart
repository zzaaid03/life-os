/// Dialog for editing the food-preferences line the recipe chef follows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';

/// Edits the user's food preferences. Saving an empty field clears them.
class FoodPreferencesDialog extends ConsumerStatefulWidget {
  /// Creates a [FoodPreferencesDialog].
  const FoodPreferencesDialog({super.key});

  /// Shows the dialog, then a SnackBar with the outcome.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const FoodPreferencesDialog(),
    );
  }

  @override
  ConsumerState<FoodPreferencesDialog> createState() =>
      _FoodPreferencesDialogState();
}

class _FoodPreferencesDialogState extends ConsumerState<FoodPreferencesDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(foodPreferencesProvider).value ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final text = _controller.text.trim();
    try {
      await ref
          .read(foodPreferencesProvider.notifier)
          .save(text.isEmpty ? null : text);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text("Couldn't save your food preferences. ($e)"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Food preferences'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. vegetarian, no mushrooms, allergic to peanuts',
            helperText: 'Diet, allergies, dislikes. The chef always follows these.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
