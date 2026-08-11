/// Riverpod providers for the subscriptions feature.
///
/// Mirrors the load/auto-load pattern in `job_provider.dart` so cold-start
/// behaves consistently: load on a real auth change, plus an eager load for
/// the case where the session was already restored before this provider
/// existed and `ref.listen` therefore never fires.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the subscriptions list.
enum SubscriptionListStatus { loading, loaded, error }

/// State managed by [SubscriptionListNotifier].
class SubscriptionListState {
  /// Creates a [SubscriptionListState].
  const SubscriptionListState({
    this.status = SubscriptionListStatus.loading,
    this.subscriptions = const <Subscription>[],
    this.error,
  });

  /// The current loading status.
  final SubscriptionListStatus status;

  /// The loaded subscriptions, including cancelled ones.
  final List<Subscription> subscriptions;

  /// An error message, if loading failed.
  final String? error;

  /// Returns a copy with the given overrides.
  SubscriptionListState copyWith({
    SubscriptionListStatus? status,
    List<Subscription>? subscriptions,
    String? error,
  }) {
    return SubscriptionListState(
      status: status ?? this.status,
      subscriptions: subscriptions ?? this.subscriptions,
      error: error,
    );
  }
}

/// Loads and mutates the user's subscriptions.
class SubscriptionListNotifier extends StateNotifier<SubscriptionListState> {
  /// Creates a [SubscriptionListNotifier].
  SubscriptionListNotifier(this._repository)
    : super(const SubscriptionListState());

  final SubscriptionRepository _repository;

  String? _userId;

  /// The user this notifier last loaded for, or null before any load.
  String? get userId => _userId;

  /// Loads subscriptions for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.subscriptions.isEmpty) {
      state = const SubscriptionListState(
        status: SubscriptionListStatus.loading,
      );
    }
    try {
      final subscriptions = await _repository.getAll(userId);
      state = SubscriptionListState(
        status: SubscriptionListStatus.loaded,
        subscriptions: subscriptions,
      );
    } catch (_) {
      // Keep whatever is already on screen rather than blanking it: a failed
      // refresh should not erase a list the user is reading.
      if (state.subscriptions.isNotEmpty) {
        state = state.copyWith(status: SubscriptionListStatus.loaded);
      } else {
        state = const SubscriptionListState(
          status: SubscriptionListStatus.error,
          error: 'Failed to load subscriptions.',
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

  /// Creates a subscription and refreshes the list.
  Future<void> create({
    required String name,
    required int amountCents,
    required String currency,
    required BillingCycle cycle,
    DateTime? nextChargeDate,
    String? notes,
    String? sourceEmailId,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Cannot create a subscription before a user is loaded');
    }
    await _repository.create(
      userId: userId,
      name: name,
      amountCents: amountCents,
      currency: currency,
      cycle: cycle,
      nextChargeDate: nextChargeDate,
      notes: notes,
      sourceEmailId: sourceEmailId,
    );
    await refresh();
  }

  /// Updates a subscription and refreshes the list.
  Future<void> update(Subscription subscription) async {
    await _repository.update(subscription);
    await refresh();
  }

  /// Soft-deletes a subscription and refreshes the list.
  Future<void> softDelete(String id) async {
    await _repository.softDelete(id);
    await refresh();
  }
}

/// Provides the [SubscriptionListNotifier] and its state.
final subscriptionListProvider =
    StateNotifierProvider<SubscriptionListNotifier, SubscriptionListState>((
      ref,
    ) {
      final repository = ref.watch(subscriptionRepositoryProvider);
      final notifier = SubscriptionListNotifier(repository);

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold-start: if the session was already restored before this provider
      // was created, `ref.listen` won't fire, so load eagerly.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });

/// Total monthly spend per currency, in cents, derived from the loaded list.
final monthlySpendProvider = Provider<Map<String, int>>((ref) {
  return monthlyTotalsByCurrency(
    ref.watch(subscriptionListProvider).subscriptions,
  );
});
