import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/sync/sync_state.dart';
import 'package:life_os/features/tasks/presentation/widgets/sync_status_banner.dart';

class _FakeSyncState extends SyncStateNotifier {
  _FakeSyncState(SyncState initial) {
    state = initial;
  }
}

Future<void> _pump(WidgetTester tester, SyncState state) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncStateProvider.overrideWith((ref) => _FakeSyncState(state)),
      ],
      child: const MaterialApp(home: Scaffold(body: SyncStatusBanner())),
    ),
  );
}

void main() {
  const message =
      'Some changes haven’t synced yet. They’re saved on this phone.';

  testWidgets('is hidden when there is no error', (tester) async {
    await _pump(tester, const SyncState(pendingCount: 3));
    expect(find.text(message), findsNothing);
  });

  testWidgets('is shown with an error and pending tasks', (tester) async {
    await _pump(tester, const SyncState(lastError: 'boom', pendingCount: 2));
    expect(find.text(message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('is hidden with an error but nothing pending', (tester) async {
    await _pump(tester, const SyncState(lastError: 'boom'));
    expect(find.text(message), findsNothing);
  });
}
