/// Riverpod providers for the grocery list.
///
/// Same load/auto-load pattern as `subscription_provider.dart`: load on a
/// real auth change, plus an eager load for a session restored before this
/// provider existed (where `ref.listen` never fires).
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/groceries/data/models/grocery_item.dart';
import 'package:life_os/features/groceries/data/repositories/grocery_repository.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the grocery list.
enum GroceryListStatus { loading, loaded, error }

/// State managed by [GroceryListNotifier].
class GroceryListState {
  /// Creates a [GroceryListState].
  const GroceryListState({
    this.status = GroceryListStatus.loading,
    this.items = const <GroceryItem>[],
    this.error,
  });

  /// The current loading status.
  final GroceryListStatus status;

  /// The items, already in display order (see [sortForDisplay]).
  final List<GroceryItem> items;

  /// An error message, if loading failed.
  final String? error;

  /// Items still to buy.
  int get uncheckedCount => items.where((i) => !i.checked).length;

  /// Whether any item is checked, i.e. "clear checked" has something to do.
  bool get hasChecked => items.any((i) => i.checked);
}

/// Loads and mutates the user's grocery list.
class GroceryListNotifier extends StateNotifier<GroceryListState> {
  /// Creates a [GroceryListNotifier].
  GroceryListNotifier(this._repository) : super(const GroceryListState());

  final GroceryRepository _repository;

  String? _userId;

  /// The user this notifier last loaded for, or null before any load.
  String? get userId => _userId;

  /// Loads the list for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    try {
      final items = await _repository.getAll(userId);
      state = GroceryListState(
        status: GroceryListStatus.loaded,
        items: sortForDisplay(items),
      );
    } catch (_) {
      // A failed refresh keeps what is on screen rather than blanking it.
      if (state.items.isNotEmpty) {
        state = GroceryListState(
          status: GroceryListStatus.loaded,
          items: state.items,
        );
      } else {
        state = const GroceryListState(
          status: GroceryListStatus.error,
          error: 'Failed to load your grocery list.',
        );
      }
    }
  }

  /// Reloads for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  String _requireUser() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Cannot change the grocery list before a user is loaded');
    }
    return userId;
  }

  /// Adds one item.
  Future<void> add(String name, {String? quantity}) =>
      addAll([GroceryDraft(name: name, quantity: quantity)]);

  /// Adds several items at once (used by recipes in slice 2).
  Future<void> addAll(List<GroceryDraft> drafts) async {
    await _repository.addAll(_requireUser(), drafts);
    await refresh();
  }

  /// Ticks or unticks [item]. The screen updates immediately and reverts if
  /// the write fails, because this is tapped in a shop on bad signal. The
  /// error is rethrown so the caller can tell the user.
  Future<void> setChecked(GroceryItem item, {required bool checked}) async {
    final before = state.items;
    state = GroceryListState(
      status: state.status,
      items: sortForDisplay([
        for (final i in before)
          if (i.id == item.id) i.copyWith(checked: checked) else i,
      ]),
    );
    try {
      await _repository.update(item.copyWith(checked: checked));
    } catch (_) {
      state = GroceryListState(status: state.status, items: before);
      rethrow;
    }
  }

  /// Saves an edited name or quantity.
  Future<void> update(GroceryItem item) async {
    await _repository.update(item);
    await refresh();
  }

  /// Removes one item.
  Future<void> delete(String id) async {
    await _repository.delete(id);
    await refresh();
  }

  /// Removes every checked item.
  Future<void> clearChecked() async {
    await _repository.deleteChecked(_requireUser());
    await refresh();
  }
}

/// Provides the [GroceryListNotifier] and its state.
final groceryListProvider =
    StateNotifierProvider<GroceryListNotifier, GroceryListState>((ref) {
      final repository = ref.watch(groceryRepositoryProvider);
      final notifier = GroceryListNotifier(repository);

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });
