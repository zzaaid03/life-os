import 'package:flutter_test/flutter_test.dart';

import 'package:life_os/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    // Verify that the app can be instantiated.
    // Full widget tests will be added as features are implemented.
    await tester.pumpWidget(const LifeOSApp());
    await tester.pump();

    // The splash screen should show the app name.
    expect(find.text('Life OS'), findsOneWidget);
  });
}
