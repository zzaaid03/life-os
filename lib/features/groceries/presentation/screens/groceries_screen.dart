/// The groceries screen.
///
/// One list: an add row pinned at the top, items still to buy, then the
/// checked ones under an "In basket" header. Tick, tap to edit, swipe to
/// delete, and clear everything checked from the AppBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/domain/providers/grocery_provider.dart';
import 'package:life_os/features/groceries/presentation/widgets/grocery_add_row.dart';
import 'package:life_os/features/groceries/presentation/widgets/grocery_item_tile.dart';

/// Shows the grocery list.
class GroceriesScreen extends ConsumerStatefulWidget {
  /// Creates a [GroceriesScreen].
  const GroceriesScreen({super.key});

  @override
  ConsumerState<GroceriesScreen> createState() => _GroceriesScreenState();
}

class _GroceriesScreenState extends ConsumerState<GroceriesScreen> {
  /// Ids swiped away whose delete is still in flight. A dismissed
  /// [Dismissible] must leave the tree at once, but the notifier only drops
  /// the row after its refresh, so these are hidden locally until then.
  final Set<String> _removing = {};

  GroceryListNotifier get _notifier => ref.read(groceryListProvider.notifier);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _add(String name, String? quantity) async {
    try {
      await _notifier.add(name, quantity: quantity);
      return true;
    } catch (_) {
      _showError('Could not add the item.');
      return false;
    }
  }

  Future<void> _setChecked(GroceryItem item, bool checked) async {
    try {
      await _notifier.setChecked(item, checked: checked);
    } catch (_) {
      // The notifier has already put the checkbox back.
      _showError('Could not update the item.');
    }
  }

  Future<void> _edit(GroceryItem item) async {
    final result = await GroceryEditDialog.show(context, item);
    if (result == null) return;
    try {
      await _notifier.update(
        item.copyWith(
          name: result.name,
          quantity: result.quantity,
          clearQuantity: result.quantity == null,
        ),
      );
    } catch (_) {
      _showError('Could not save the changes.');
    }
  }

  Future<void> _delete(GroceryItem item) async {
    setState(() => _removing.add(item.id));
    try {
      await _notifier.delete(item.id);
    } catch (_) {
      if (mounted) setState(() => _removing.remove(item.id));
      _showError('Could not delete the item.');
    }
  }

  Future<void> _clearChecked() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear checked items?'),
        content: const Text(
          'Everything in your basket will be removed from the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _notifier.clearChecked();
    } catch (_) {
      _showError('Could not clear checked items.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groceryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groceries'),
        actions: [
          TextButton(
            onPressed: state.hasChecked ? _clearChecked : null,
            child: const Text('Clear checked'),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(GroceryListState state) {
    if (state.status == GroceryListStatus.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == GroceryListStatus.error && state.items.isEmpty) {
      return _ErrorState(
        message: state.error ?? 'Failed to load your grocery list.',
        onRetry: () => _notifier.refresh(),
      );
    }

    final items = state.items.where((i) => !_removing.contains(i.id)).toList();
    final unchecked = items.where((i) => !i.checked).toList();
    final checked = items.where((i) => i.checked).toList();

    return RefreshIndicator(
      onRefresh: () => _notifier.refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        children: [
          GroceryAddRow(onAdd: _add),
          const SizedBox(height: AppSpacing.lg),
          if (items.isEmpty) const _EmptyState(),
          for (final item in unchecked) ..._tile(item),
          if (unchecked.isNotEmpty && checked.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const _SectionLabel(label: 'In basket'),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final item in checked) ..._tile(item),
        ],
      ),
    );
  }

  List<Widget> _tile(GroceryItem item) {
    return [
      GroceryItemTile(
        key: ValueKey(item.id),
        item: item,
        onChecked: (value) => _setChecked(item, value),
        onTap: () => _edit(item),
        onDismissed: () => _delete(item),
      ),
      const SizedBox(height: AppSpacing.sm),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxxl * 2),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your list is empty',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              'Type something you need in the box above to add it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
