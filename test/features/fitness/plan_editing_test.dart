import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/data/workout_plan_repository.dart';
import 'package:life_os/features/fitness/domain/exercise_draft.dart';
import 'package:life_os/features/fitness/domain/plan_inputs.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';

PlanExercise _ex(String id, int pos) => PlanExercise(
  id: id,
  position: pos,
  name: id,
  kind: 'reps',
  sets: 3,
  repsMin: 8,
  repsMax: 10,
  restSeconds: 60,
);

WorkoutPlan _plan(String id, List<PlanExercise> exercises) => WorkoutPlan(
  id: id,
  name: 'Plan',
  days: [PlanDay(id: 'd1', position: 0, title: 'Push', exercises: exercises)],
);

class _Repo extends Fake implements WorkoutPlanRepository {
  _Repo(this.plan);

  WorkoutPlan? plan;
  Object? generateError;
  WorkoutPlan? planAfterError;
  int fetches = 0;
  final List<List<String>> reorders = [];

  @override
  Future<WorkoutPlan?> fetchActivePlan() async {
    fetches++;
    return plan;
  }

  @override
  Future<String> generate(PlanInputs inputs) async {
    final err = generateError;
    if (err != null) {
      plan = planAfterError ?? plan;
      throw err;
    }
    return 'new';
  }

  @override
  Future<void> deleteExercise(String id) async {}

  @override
  Future<void> reorderExercises(List<String> orderedIds) async {
    reorders.add(orderedIds);
  }
}

void main() {
  group('reorder', () {
    test('moving down lands on the final index', () {
      expect(reorderItems(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
      expect(reorderItems(['a', 'b', 'c'], 0, 1), ['b', 'a', 'c']);
    });

    test('moving up', () {
      expect(reorderItems(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('positions are rewritten 0..n-1', () {
      expect(positionsFor(['c', 'a', 'b']), {'c': 0, 'a': 1, 'b': 2});
    });

    test('notifier shows the new order and writes it once', () async {
      final repo = _Repo(_plan('p', [_ex('a', 0), _ex('b', 1), _ex('c', 2)]));
      final n = WorkoutPlanNotifier(repo);
      await n.load();
      await n.reorderExercises('d1', 0, 2);
      expect(repo.reorders, [
        ['b', 'c', 'a'],
      ]);
    });

    test('remove renumbers the rest', () async {
      final repo = _Repo(_plan('p', [_ex('a', 0), _ex('b', 1), _ex('c', 2)]));
      final n = WorkoutPlanNotifier(repo);
      await n.load();
      await n.removeExercise('d1', 'b');
      expect(repo.reorders.last, ['a', 'c']);
    });
  });

  group('draft', () {
    test('switching to time clears the reps fields', () {
      final d = const ExerciseDraft(name: 'Plank').withKind('time');
      expect(d.repsMin, isNull);
      expect(d.repsMax, isNull);
      expect(d.holdSeconds, 30);
      expect(d.toRow()['reps_min'], isNull);
      expect(d.isValid, isTrue);
    });

    test('switching back to reps clears the hold', () {
      final d = const ExerciseDraft(
        name: 'Plank',
      ).withKind('time').withKind('reps');
      expect(d.holdSeconds, isNull);
      expect(d.repsMin, 8);
      expect(d.toRow()['hold_seconds'], isNull);
      expect(d.isValid, isTrue);
    });

    test('name is required and capped', () {
      expect(const ExerciseDraft().isValid, isFalse);
      expect(const ExerciseDraft(name: '   ').isValid, isFalse);
      expect(ExerciseDraft(name: 'x' * 61).isValid, isFalse);
      expect(ExerciseDraft(name: 'x' * 60).isValid, isTrue);
    });

    test('reps min never passes max', () {
      var d = const ExerciseDraft(name: 'Row', repsMin: 8, repsMax: 10);
      d = d.withRepsMin(20);
      expect(d.repsMax, 20);
      d = d.withRepsMax(5);
      expect(d.repsMin, 5);
      expect(d.isValid, isTrue);
    });

    test('values clamp to the column limits', () {
      final d = const ExerciseDraft(
        name: 'x',
      ).withSets(99).withRest(-5).withRepsMax(500);
      expect(d.sets, 10);
      expect(d.restSeconds, 0);
      expect(d.repsMax, 50);
      expect(
        const ExerciseDraft(name: 'x').withKind('time').withHold(1).holdSeconds,
        5,
      );
    });
  });

  group('generate error', () {
    test('reloads once and rethrows', () async {
      final repo = _Repo(_plan('old', [_ex('a', 0)]))
        ..generateError = StateError('timeout')
        ..planAfterError = _plan('new', [_ex('a', 0)]);
      final n = WorkoutPlanNotifier(repo);
      await n.load();
      final fetchesBefore = repo.fetches;
      await expectLater(
        n.generate(const PlanInputs()),
        throwsA(isA<StateError>()),
      );
      expect(repo.fetches, fetchesBefore + 1);
      expect(n.state.plan?.id, 'new');
    });

    test('daily limit does not reload', () async {
      final repo = _Repo(_plan('old', [_ex('a', 0)]))
        ..generateError = const DailyLimitReached();
      final n = WorkoutPlanNotifier(repo);
      await n.load();
      final fetchesBefore = repo.fetches;
      await expectLater(
        n.generate(const PlanInputs()),
        throwsA(isA<DailyLimitReached>()),
      );
      expect(repo.fetches, fetchesBefore);
    });
  });
}
