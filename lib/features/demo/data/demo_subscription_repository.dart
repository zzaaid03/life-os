/// In-memory [SubscriptionRepository] for the sandbox demo mode.
///
/// Demo mode makes zero network calls; that property is verified elsewhere
/// and must not regress. Without this override the subscriptions list would
/// query Supabase with the fake `demo-user` id, which is not even a valid
/// UUID, so the sandbox would make a real request and get a database error
/// back.
///
/// Seeded with a believable recurring-spend picture for "Alex," the demo
/// persona: two currencies on purpose, so the sandbox shows that totals are
/// grouped per currency and never converted.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/data/repositories/subscription_repository.dart';

/// Repository for [Subscription] records backed by an in-memory demo list.
class DemoSubscriptionRepository implements SubscriptionRepository {
  /// Creates a [DemoSubscriptionRepository] seeded with Alex's spend.
  DemoSubscriptionRepository() : _subscriptions = _buildDemoSubscriptions();

  final List<Subscription> _subscriptions;

  int _nextId = 0;

  @override
  Future<List<Subscription>> getAll(String userId) async {
    if (userId != demoUserId) return const [];
    final live = _subscriptions.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(live);
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
    final now = DateTime.now();
    final created = Subscription(
      id: 'demo-subscription-new-${_nextId++}',
      userId: demoUserId,
      name: name,
      amountCents: amountCents,
      currency: currency.toUpperCase(),
      cycle: cycle,
      nextChargeDate: nextChargeDate,
      notes: notes,
      sourceEmailId: sourceEmailId,
      createdAt: now,
      updatedAt: now,
    );
    _subscriptions.add(created);
    return created;
  }

  @override
  Future<Subscription> update(Subscription subscription) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index == -1) return subscription;
    _subscriptions[index] = subscription;
    return subscription;
  }

  @override
  Future<void> softDelete(String id) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index == -1) return;
    _subscriptions[index] = _subscriptions[index].copyWith(
      deletedAt: DateTime.now(),
    );
  }
}

List<Subscription> _buildDemoSubscriptions() {
  final now = DateTime.now();
  // Dates are relative to now so the seed never rots.
  Subscription build({
    required String id,
    required String name,
    required int amountCents,
    required String currency,
    required BillingCycle cycle,
    required int chargesInDays,
    SubscriptionStatus status = SubscriptionStatus.active,
    String? notes,
  }) {
    return Subscription(
      id: id,
      userId: demoUserId,
      name: name,
      amountCents: amountCents,
      currency: currency,
      cycle: cycle,
      nextChargeDate: now.add(Duration(days: chargesInDays)),
      status: status,
      notes: notes,
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 60)),
    );
  }

  return [
    build(
      id: 'demo-subscription-streaming',
      name: 'Streaming plan',
      amountCents: 1599,
      currency: 'USD',
      cycle: BillingCycle.monthly,
      chargesInDays: 4,
    ),
    build(
      id: 'demo-subscription-gym',
      name: 'Gym membership',
      amountCents: 3500,
      currency: 'USD',
      cycle: BillingCycle.monthly,
      chargesInDays: 12,
      notes: 'Cancel if the new place works out',
    ),
    build(
      id: 'demo-subscription-cloud-storage',
      name: 'Cloud storage',
      amountCents: 2400,
      currency: 'USD',
      cycle: BillingCycle.yearly,
      chargesInDays: 96,
    ),
    build(
      id: 'demo-subscription-design-tool',
      name: 'Design tool',
      amountCents: 1200,
      currency: 'EUR',
      cycle: BillingCycle.monthly,
      chargesInDays: 21,
      notes: 'Billed from the EU account',
    ),
    build(
      id: 'demo-subscription-news',
      name: 'News subscription',
      amountCents: 900,
      currency: 'USD',
      cycle: BillingCycle.monthly,
      chargesInDays: 30,
      status: SubscriptionStatus.cancelled,
    ),
  ];
}
