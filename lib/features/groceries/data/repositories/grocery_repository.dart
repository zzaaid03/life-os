/// Repository interface for the grocery list.
///
/// Written before any implementation exists so parallel worker lanes can be
/// built and analyzed independently against it.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/data/repositories/supabase_grocery_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for [GroceryItem] records.
abstract class GroceryRepository {
  /// Fetches every grocery item for [userId], checked ones included.
  /// Order is not guaranteed; callers use [sortForDisplay].
  Future<List<GroceryItem>> getAll(String userId);

  /// Adds every draft in one request. Recipes (slice 2) add several
  /// ingredients at once, so this is the primitive and a single add is just
  /// a one-element list.
  Future<void> addAll(String userId, List<GroceryDraft> drafts);

  /// Updates an item's name, quantity and checked state.
  Future<void> update(GroceryItem item);

  /// Hard-deletes one item.
  Future<void> delete(String id);

  /// Hard-deletes every checked item for [userId].
  Future<void> deleteChecked(String userId);
}

/// Provides the [GroceryRepository].
final groceryRepositoryProvider = Provider<GroceryRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseGroceryRepository(client);
});
