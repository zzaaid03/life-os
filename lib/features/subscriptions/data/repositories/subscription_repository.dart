/// Repository interface for subscriptions.
///
/// Written before any implementation exists so parallel worker lanes can be
/// built and analyzed independently against it.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/data/repositories/supabase_subscription_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for [Subscription] records.
abstract class SubscriptionRepository {
  /// Fetches every live (not soft-deleted) subscription for [userId],
  /// including cancelled ones so the history stays visible.
  ///
  /// Ordered by name, case-insensitively.
  Future<List<Subscription>> getAll(String userId);

  /// Creates a subscription. Returns the inserted row as the database
  /// stored it, so the caller gets the real id and timestamps.
  Future<Subscription> create({
    required String userId,
    required String name,
    required int amountCents,
    required String currency,
    required BillingCycle cycle,
    DateTime? nextChargeDate,
    String? notes,
    String? sourceEmailId,
  });

  /// Updates an existing subscription's editable fields. Returns the row as
  /// stored after the write.
  Future<Subscription> update(Subscription subscription);

  /// Soft-deletes a subscription by setting `deleted_at`.
  ///
  /// Soft delete on purpose, matching tasks and goals. Note the consequence
  /// already learned the hard way in this codebase: a soft delete never
  /// issues a SQL DELETE, so any `ON DELETE CASCADE` is inert and cascade
  /// behaviour has to be written in Dart.
  Future<void> softDelete(String id);
}

/// Provides the [SubscriptionRepository].
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSubscriptionRepository(client);
});
