/// Supabase-backed [SubscriptionRepository].
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
  Future<List<Subscription>> getAll(String userId) async {
    final response = await _client
        .from(table)
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null);
    final subscriptions = (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Subscription.fromJson)
        .toList();
    subscriptions.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return subscriptions;
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
  }) async {
    // Built purely to reuse Subscription.toJson()'s `yyyy-mm-dd` date
    // formatting and currency uppercasing; id/createdAt/updatedAt are
    // placeholders the database overwrites on insert.
    final draft = Subscription(
      id: '',
      userId: userId,
      name: name,
      amountCents: amountCents,
      currency: currency,
      cycle: cycle,
      nextChargeDate: nextChargeDate,
      notes: notes,
      sourceEmailId: sourceEmailId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final response = await _client
        .from(table)
        .insert(draft.toJson())
        .select()
        .single();
    return Subscription.fromJson(response);
  }

  @override
  Future<Subscription> update(Subscription subscription) async {
    final json = subscription.toJson();
    final values = {
      'name': json['name'],
      'amount_cents': json['amount_cents'],
      'currency': json['currency'],
      'cycle': json['cycle'],
      'next_charge_date': json['next_charge_date'],
      'status': json['status'],
      'notes': json['notes'],
    };
    final response = await _client
        .from(table)
        .update(values)
        .eq('id', subscription.id)
        .select()
        .single();
    return Subscription.fromJson(response);
  }

  @override
  Future<void> softDelete(String id) async {
    await _client
        .from(table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
