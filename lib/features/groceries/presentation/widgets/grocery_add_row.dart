/// The add row pinned at the top of the grocery list.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A name field, an optional quantity field and an add button.
///
/// After a successful add both fields clear and focus returns to the name
/// field, so several items can be typed in a row.
class GroceryAddRow extends StatefulWidget {
  /// Creates a [GroceryAddRow].
  const GroceryAddRow({super.key, required this.onAdd});

  /// Called with a trimmed, non-blank name and the raw quantity text (null
  /// when empty). Returns whether the add succeeded.
  final Future<bool> Function(String name, String? quantity) onAdd;

  @override
  State<GroceryAddRow> createState() => _GroceryAddRowState();
}

class _GroceryAddRowState extends State<GroceryAddRow> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _busy) {
      _nameFocus.requestFocus();
      return;
    }
    final quantity = _quantityController.text.trim();

    setState(() => _busy = true);
    final ok = await widget.onAdd(name, quantity.isEmpty ? null : quantity);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _nameController.clear();
      _quantityController.clear();
    }
    _nameFocus.requestFocus();
  }

  InputDecoration _decoration(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: _decoration(theme, 'Add an item'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _quantityController,
            textInputAction: TextInputAction.done,
            decoration: _decoration(theme, 'Qty'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton.filled(
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          tooltip: 'Add item',
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }
}
