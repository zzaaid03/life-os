/// Supabase-backed [GroceryRepository].
library;

import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/data/repositories/grocery_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes the `public.grocery_items` table.
class SupabaseGroceryRepository implements GroceryRepository {
  /// Creates a [SupabaseGroceryRepository].
  const SupabaseGroceryRepository(this._client);

  final SupabaseClient _client;

  /// The backing table.
  static const String table = 'grocery_items';

  @override
  Future<List<GroceryItem>> getAll(String userId) async {
    // No limit on purpose: the screen shows every item and one user has far
    // fewer than the 1000-row response cap.
    final response = await _client.from(table).select().eq('user_id', userId);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GroceryItem.fromJson)
        .toList();
  }

  @override
  Future<void> addAll(String userId, List<GroceryDraft> drafts) async {
    final rows = drafts
        .where((d) => d.name.trim().isNotEmpty)
        .map((d) => d.toInsertJson(userId))
        .toList();
    if (rows.isEmpty) return;
    await _client.from(table).insert(rows);
  }

  @override
  Future<void> update(GroceryItem item) async {
    final q = item.quantity?.trim();
    await _client
        .from(table)
        .update({
          'name': item.name.trim(),
          'quantity': (q == null || q.isEmpty) ? null : q,
          'checked': item.checked,
        })
        .eq('id', item.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(table).delete().eq('id', id);
  }

  @override
  Future<void> deleteChecked(String userId) async {
    await _client
        .from(table)
        .delete()
        .eq('user_id', userId)
        .eq('checked', true);
  }
}
