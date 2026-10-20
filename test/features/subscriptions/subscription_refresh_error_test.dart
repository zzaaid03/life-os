import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:life_os/features/subscriptions/domain/providers/subscription_provider.dart';

class _FakeSubscriptionRepository extends Fake
    implements SubscriptionRepository {
  bool fail = false;

  @override
  Future<List<Subscription>> getAll(String userId) async {
    if (fail) throw StateError('offline');
    return [
      Subscription(
        id: 's1',
        userId: userId,
        name: 'Netflix',
        amountCents: 1299,
        currency: 'EUR',
        cycle: BillingCycle.monthly,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
  }
}

void main() {
  test('a failed refresh keeps the subscriptions and sets an error', () async {
    final repo = _FakeSubscriptionRepository();
    final notifier = SubscriptionListNotifier(repo);

    await notifier.load('user-1');
    expect(notifier.state.subscriptions, hasLength(1));
    expect(notifier.state.error, isNull);

    repo.fail = true;
    await notifier.refresh();

    expect(notifier.state.status, SubscriptionListStatus.loaded);
    expect(notifier.state.subscriptions, hasLength(1));
    expect(
      notifier.state.error,
      "Couldn't refresh your subscriptions. Check your connection and try again.",
    );
  });

  test('a later successful refresh clears the error', () async {
    final repo = _FakeSubscriptionRepository();
    final notifier = SubscriptionListNotifier(repo);
    await notifier.load('user-1');
    repo.fail = true;
    await notifier.refresh();
    repo.fail = false;
    await notifier.refresh();

    expect(notifier.state.error, isNull);
  });
}
