import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/data/workout_plan_repository.dart';
import 'package:life_os/features/fitness/domain/plan_inputs.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';
import 'package:life_os/features/fitness/presentation/screens/fitness_hub_screen.dart';
import 'package:life_os/features/nutrition/data/calorie_profile_repository.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

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

class _PlanRepo implements WorkoutPlanRepository {
  @override
  Future<WorkoutPlan?> fetchActivePlan() async => null;

  @override
  Future<String> generate(PlanInputs inputs) async => 'x';
}

class _FakePlanNotifier extends WorkoutPlanNotifier {
  _FakePlanNotifier(WorkoutPlanState initial) : super(_PlanRepo()) {
    state = initial;
  }

  int loads = 0;

  @override
  Future<void> load([String? userId]) async {
    loads++;
  }
}

PlanExercise _ex(int i) => PlanExercise(
  id: 'e$i',
  position: i,
  name: 'Exercise $i',
  kind: 'reps',
  sets: 4,
  repsMin: 8,
  repsMax: 10,
  restSeconds: 90,
);

final _plan = WorkoutPlan(
  id: 'p',
  name: 'Plan',
  days: [
    PlanDay(
      id: 'd0',
      position: 0,
      title: 'Push',
      exercises: [for (var i = 0; i < 7; i++) _ex(i)],
    ),
    const PlanDay(id: 'd1', position: 1, title: 'Pull', exercises: []),
    const PlanDay(id: 'd2', position: 2, title: 'Legs', exercises: []),
  ],
);

Widget _app(
  WorkoutPlanState planState, {
  CalorieProfile profile = const CalorieProfile(),
  _FakePlanNotifier? planNotifier,
}) {
  return ProviderScope(
    overrides: [
      calorieProfileProvider.overrideWith(
        (ref) =>
            _FakeNotifier(CalorieProfileState(loaded: true, profile: profile)),
      ),
      workoutPlanProvider.overrideWith(
        (ref) => planNotifier ?? _FakePlanNotifier(planState),
      ),
    ],
    child: const MaterialApp(home: FitnessHubScreen()),
  );
}

void main() {
  testWidgets('loading keeps the card and shows a spinner', (tester) async {
    await tester.pumpWidget(_app(const WorkoutPlanState()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Build your plan'), findsNothing);
  });

  testWidgets('load error shows Retry, never the empty state', (tester) async {
    final notifier = _FakePlanNotifier(
      const WorkoutPlanState(loaded: true, loadFailed: true),
    );
    await tester.pumpWidget(
      _app(const WorkoutPlanState(), planNotifier: notifier),
    );
    expect(find.text("Couldn't load your plan."), findsOneWidget);
    expect(find.text('Build your plan'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(notifier.loads, 1);
  });

  testWidgets('no plan shows the build card', (tester) async {
    await tester.pumpWidget(_app(const WorkoutPlanState(loaded: true)));
    expect(find.text('Build your plan'), findsOneWidget);
    expect(find.text('6 quick questions'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Build my plan'), findsOneWidget);
  });

  testWidgets('plan shows next up day, 5 rows, +N more and the strip', (
    tester,
  ) async {
    await tester.pumpWidget(_app(WorkoutPlanState(loaded: true, plan: _plan)));
    expect(find.text('NEXT UP · DAY A OF 3'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Exercise 4'), findsOneWidget);
    expect(find.text('Exercise 5'), findsNothing);
    expect(find.text('+ 2 more'), findsOneWidget);
    expect(find.text('4 × 8-10 · 90s'), findsNWidgets(5));
    expect(find.text('B Pull'), findsOneWidget);
  });

  testWidgets('tapping a chip shows that day', (tester) async {
    await tester.pumpWidget(_app(WorkoutPlanState(loaded: true, plan: _plan)));
    await tester.tap(find.text('B Pull'));
    await tester.pump();
    expect(find.text('DAY B OF 3'), findsOneWidget);
    expect(find.text('NEXT UP · DAY A OF 3'), findsNothing);
  });

  testWidgets('body row shows set-your-target and BMI', (tester) async {
    await tester.pumpWidget(
      _app(
        const WorkoutPlanState(loaded: true),
        profile: const CalorieProfile(weightKg: 80, heightCm: 180),
      ),
    );
    expect(find.text('Set your target'), findsOneWidget);
    expect(find.text('24.7'), findsOneWidget);
  });

  testWidgets('body row shows the kcal target', (tester) async {
    await tester.pumpWidget(
      _app(
        const WorkoutPlanState(loaded: true),
        profile: CalorieProfile(
          weightKg: 80,
          heightCm: 180,
          birthYear: DateTime.now().year - 30,
          sex: Sex.male,
          activity: ActivityLevel.moderate,
          goal: CalorieGoal.maintain,
        ),
      ),
    );
    expect(find.textContaining('kcal/day'), findsOneWidget);
    expect(find.text('Maintain'), findsOneWidget);
  });
}
