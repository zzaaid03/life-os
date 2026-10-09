/// One row in the grocery list, plus its edit dialog.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';

/// A grocery item with a checkbox. Swipe to delete, tap to edit.
class GroceryItemTile extends StatelessWidget {
  /// Creates a [GroceryItemTile].
  const GroceryItemTile({
    super.key,
    required this.item,
    required this.onChecked,
    required this.onTap,
    required this.onDismissed,
  });

  /// The item shown.
  final GroceryItem item;

  /// Called when the checkbox is toggled.
  final ValueChanged<bool> onChecked;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Called once the row has been swiped away.
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: item.checked,
                  onChanged: (v) => onChecked(v ?? false),
                ),
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: item.checked ? dim : null,
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
                if (item.quantity != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    item.quantity!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.checked
                          ? dim
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The result of [GroceryEditDialog]: a trimmed name and a quantity that is
/// null when the field was emptied.
typedef GroceryEdit = ({String name, String? quantity});

/// A small dialog that edits an item's name and quantity.
class GroceryEditDialog extends StatefulWidget {
  /// Creates a [GroceryEditDialog].
  const GroceryEditDialog({super.key, required this.item});

  /// The item being edited.
  final GroceryItem item;

  /// Shows the dialog. Returns null when cancelled.
  static Future<GroceryEdit?> show(BuildContext context, GroceryItem item) {
    return showDialog<GroceryEdit>(
      context: context,
      builder: (_) => GroceryEditDialog(item: item),
    );
  }

  @override
  State<GroceryEditDialog> createState() => _GroceryEditDialogState();
}

class _GroceryEditDialogState extends State<GroceryEditDialog> {
  late final _nameController = TextEditingController(text: widget.item.name);
  late final _quantityController = TextEditingController(
    text: widget.item.quantity ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    final quantity = _quantityController.text.trim();
    Navigator.of(context).pop<GroceryEdit>((
      name: _nameController.text.trim(),
      quantity: quantity.isEmpty ? null : quantity,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: 'Optional, e.g. 500 g',
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
