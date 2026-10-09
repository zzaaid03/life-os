/// In-memory [GroceryRepository] for the sandbox demo mode.
///
/// Demo mode makes zero network calls; that property is verified elsewhere
/// and must not regress. Without this override the grocery list would query
/// Supabase with the fake `demo-user` id, so the sandbox would make a real
/// request and the list would fail without saying so.
///
/// Seeded with a short, ordinary shopping list for "Alex," the demo persona:
/// some items have an amount and some don't, and two are already ticked so
/// the sandbox shows the clear-ticked action doing something.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/data/repositories/grocery_repository.dart';

/// Repository for [GroceryItem] records backed by an in-memory demo list.
class DemoGroceryRepository implements GroceryRepository {
  /// Creates a [DemoGroceryRepository] seeded with Alex's shopping list.
  DemoGroceryRepository() : _items = _buildDemoGroceries();

  final List<GroceryItem> _items;

  int _nextId = 0;

  @override
  Future<List<GroceryItem>> getAll(String userId) async {
    if (userId != demoUserId) return const [];
    return List.unmodifiable(_items);
  }

  @override
  Future<void> addAll(String userId, List<GroceryDraft> drafts) async {
    final now = DateTime.now();
    for (final draft in drafts) {
      final name = draft.name.trim();
      if (name.isEmpty) continue;
      final q = draft.quantity?.trim();
      _items.add(
        GroceryItem(
          id: 'demo-grocery-new-${_nextId++}',
          userId: demoUserId,
          name: name,
          quantity: (q == null || q.isEmpty) ? null : q,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  @override
  Future<void> update(GroceryItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    _items[index] = item;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> deleteChecked(String userId) async {
    if (userId != demoUserId) return;
    _items.removeWhere((i) => i.checked);
  }
}

List<GroceryItem> _buildDemoGroceries() {
  final now = DateTime.now();
  // Times are relative to now so the seed never rots. Each item is a minute
  // older than the next so the display order matches the list below.
  var minutesAgo = 60;
  GroceryItem build({
    required String id,
    required String name,
    String? quantity,
    bool checked = false,
  }) {
    final at = now.subtract(Duration(minutes: minutesAgo--));
    return GroceryItem(
      id: id,
      userId: demoUserId,
      name: name,
      quantity: quantity,
      checked: checked,
      createdAt: at,
      updatedAt: at,
    );
  }

  return [
    build(id: 'demo-grocery-eggs', name: 'Eggs', quantity: '12'),
    build(
      id: 'demo-grocery-chicken',
      name: 'Chicken thighs',
      quantity: '500 g',
    ),
    build(id: 'demo-grocery-spinach', name: 'Spinach'),
    build(id: 'demo-grocery-oat-milk', name: 'Oat milk', quantity: '2'),
    build(
      id: 'demo-grocery-bread',
      name: 'Sourdough bread',
      checked: true,
    ),
    build(
      id: 'demo-grocery-bananas',
      name: 'Bananas',
      quantity: '6',
      checked: true,
    ),
  ];
}
