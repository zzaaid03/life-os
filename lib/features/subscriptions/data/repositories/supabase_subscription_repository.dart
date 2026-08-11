/// Supabase-backed [SubscriptionRepository].
///
/// STUB: the signatures and the provider wiring are planner-written so every
/// worker lane compiles against the real contract. The bodies are WORKER
/// LANE 1's job. Do not change any signature here without saying so.
library;

import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes subscriptions in the `public.subscriptions` table.
class SupabaseSubscriptionRepository implements SubscriptionRepository {
  /// Creates a [SupabaseSubscriptionRepository].
  const SupabaseSubscriptionRepository(this._client);

  final SupabaseClient _client;

  /// The backing table.
  static const String table = 'subscriptions';

  /// The Supabase client, for the implementing lane.
  SupabaseClient get client => _client;

  @override
  Future<List<Subscription>> getAll(String userId) {
    throw UnimplementedError('Worker lane 1: implement getAll');
  }

  @override
  Future<Subscription> create({
    required String userId,
    required String name,
    required int amountCents,
    required String currency,
    required BillingCycle cycle,
    DateTime? nextChargeDate,
    String? notes,
    String? sourceEmailId,
  }) {
    throw UnimplementedError('Worker lane 1: implement create');
  }

  @override
  Future<Subscription> update(Subscription subscription) {
    throw UnimplementedError('Worker lane 1: implement update');
  }

  @override
  Future<void> softDelete(String id) {
    throw UnimplementedError('Worker lane 1: implement softDelete');
  }
}
