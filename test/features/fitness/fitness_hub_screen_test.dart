import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/presentation/screens/fitness_hub_screen.dart';
import 'package:life_os/features/nutrition/data/calorie_profile_repository.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';
import 'package:life_os/features/nutrition/presentation/bmi_card.dart';

class _FakeRepo implements CalorieProfileRepository {
  @override
  Future<CalorieProfile> load() async => const CalorieProfile();

  @override
  Future<void> save(CalorieProfile p) async {}
}

class _FakeNotifier extends CalorieProfileNotifier {
  _FakeNotifier(CalorieProfileState initial) : super(_FakeRepo()) {
    state = initial;
  }

  @override
  Future<void> load([String? userId]) async {}
}

Widget _app(CalorieProfile profile) {
  return ProviderScope(
    overrides: [
      calorieProfileProvider.overrideWith(
        (ref) => _FakeNotifier(
          CalorieProfileState(loaded: true, profile: profile),
        ),
      ),
    ],
    child: const MaterialApp(home: FitnessHubScreen()),
  );
}

void main() {
  testWidgets('shows Not set when there is no target', (tester) async {
    await tester.pumpWidget(_app(const CalorieProfile()));
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Set your target'), findsOneWidget);
    expect(find.byType(BmiCard), findsNothing);
  });

  testWidgets('shows the kcal text and BMI for a full profile', (tester) async {
    await tester.pumpWidget(
      _app(
        CalorieProfile(
          weightKg: 80,
          heightCm: 180,
          birthYear: DateTime.now().year - 30,
          sex: Sex.male,
          activity: ActivityLevel.moderate,
          goal: CalorieGoal.maintain,
        ),
      ),
    );
    expect(find.textContaining('kcal a day'), findsOneWidget);
    expect(find.text('Not set'), findsNothing);
    expect(find.byType(BmiCard), findsOneWidget);
  });

  testWidgets('shows BMI with weight and height but no target', (tester) async {
    await tester.pumpWidget(
      _app(const CalorieProfile(weightKg: 80, heightCm: 180)),
    );
    expect(find.text('Not set'), findsOneWidget);
    expect(find.byType(BmiCard), findsOneWidget);
  });
}
