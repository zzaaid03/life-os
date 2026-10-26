import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/utils/tap_outside_unfocus.dart';

void main() {
  Future<FocusNode> pump(WidgetTester tester, {required bool override}) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        actions: override ? tapOutsideUnfocusActions : null,
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: node),
              const SizedBox(height: 200, width: double.infinity),
            ],
          ),
        ),
      ),
    );
    return node;
  }

  testWidgets('tap outside unfocuses the field with the override',
      (tester) async {
    final node = await pump(tester, override: true);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tapAt(const Offset(400, 400));
    await tester.pump();
    expect(node.hasFocus, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('field keeps focus on tap outside without the override',
      (tester) async {
    final node = await pump(tester, override: false);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tapAt(const Offset(400, 400));
    await tester.pump();
    expect(node.hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
