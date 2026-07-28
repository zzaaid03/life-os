/// Riverpod providers for the learning system.
///
/// Mirrors the goals provider pattern: a list notifier that loads on auth and
/// exposes the one mutation the user has, rejecting a wrong fact.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/learning/data/models/user_fact.dart';
import 'package:life_os/features/learning/data/repositories/fact_repository.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the fact list.
enum FactListStatus { loading, loaded, error }

/// State managed by [FactListNotifier].
class FactListState {
  /// Creates a [FactListState].
  const FactListState({
    this.status = FactListStatus.loading,
    this.facts = const <UserFact>[],
    this.error,
  });

  /// The current loading status.
  final FactListStatus status;

  /// The user's live facts, most recently confirmed first.
  final List<UserFact> facts;

  /// An error message, if loading failed.
  final String? error;

  /// True when loading finished and there is genuinely nothing to show.
  ///
  /// This is a REAL state, not a failure. A brand-new account, or one with
  /// only a handful of tasks, has nothing to infer from and should be told
  /// so plainly rather than shown an empty box that reads as broken.
  bool get isEmptyButLoaded =>
      status == FactListStatus.loaded && facts.isEmpty;

  /// Returns a copy with the given overrides.
  FactListState copyWith({
    FactListStatus? status,
    List<UserFact>? facts,
    String? error,
  }) {
    return FactListState(
      status: status ?? this.status,
      facts: facts ?? this.facts,
      error: error,
    );
  }
}

/// Loads the user's inferred facts and lets them reject one.
class FactListNotifier extends StateNotifier<FactListState> {
  /// Creates a [FactListNotifier].
  FactListNotifier(this._repository) : super(const FactListState());

  final FactRepository _repository;

  String? _userId;

  /// The user whose facts are currently loaded, if any.
  String? get userId => _userId;

  /// Loads facts for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.facts.isEmpty) {
      state = const FactListState(status: FactListStatus.loading);
    }
    try {
      final facts = await _repository.getAll(userId);
      // Guard against a slow response for a user who has since signed out or
      // switched accounts landing on top of the new one.
      if (_userId != userId) return;
      state = FactListState(status: FactListStatus.loaded, facts: facts);
    } catch (e) {
      if (_userId != userId) return;
      if (state.facts.isNotEmpty) {
        // Keep showing what we already have rather than blanking the mirror.
        state = state.copyWith(error: e.toString());
      } else {
        state = FactListState(
          status: FactListStatus.error,
          error: e.toString(),
        );
      }
    }
  }

  /// Re-reads the current user's facts, if one is loaded.
  Future<void> refresh() async {
    final id = _userId;
    if (id == null) return;
    await load(id);
  }

  /// Rejects [fact]: hides it immediately and suppresses it server-side.
  ///
  /// The row is removed from local state first so the tap feels instant, then
  /// restored if the write fails, so the UI never claims a rejection that did
  /// not persist.
  Future<void> reject(UserFact fact) async {
    final previous = state.facts;
    state = state.copyWith(
      facts: previous.where((f) => f.id != fact.id).toList(),
    );
    try {
      await _repository.suppress(fact);
    } catch (e) {
      state = state.copyWith(facts: previous, error: e.toString());
      rethrow;
    }
  }
}

/// The user's inferred facts.
final factListProvider =
    StateNotifierProvider<FactListNotifier, FactListState>((ref) {
      final repository = ref.watch(factRepositoryProvider);
      final notifier = FactListNotifier(repository);

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold-start: load eagerly if the session was already restored.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });

/// The user's live facts grouped by category, in a stable display order.
///
/// Empty categories are omitted, so the mirror shows only headings that have
/// something under them.
final factsByCategoryProvider = Provider<Map<FactCategory, List<UserFact>>>((
  ref,
) {
  final facts = ref.watch(factListProvider).facts;
  final grouped = <FactCategory, List<UserFact>>{};
  for (final category in FactCategory.values) {
    final forCategory = facts.where((f) => f.category == category).toList();
    if (forCategory.isNotEmpty) grouped[category] = forCategory;
  }
  return grouped;
});
