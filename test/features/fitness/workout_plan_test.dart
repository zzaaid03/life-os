import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';

PlanExercise _ex({
  String kind = 'reps',
  int sets = 4,
  int? repsMin,
  int? repsMax,
  int? hold,
  int rest = 90,
}) {
  return PlanExercise(
    id: 'e',
    position: 0,
    name: 'Squat',
    kind: kind,
    sets: sets,
    repsMin: repsMin,
    repsMax: repsMax,
    holdSeconds: hold,
    restSeconds: rest,
  );
}

void main() {
  group('formatPrescription', () {
    test('rep range with seconds rest', () {
      expect(
        formatPrescription(_ex(repsMin: 8, repsMax: 10)),
        '4 × 8-10 · 90s',
      );
    });

    test('timed hold', () {
      expect(
        formatPrescription(_ex(kind: 'time', sets: 3, hold: 30, rest: 60)),
        '3 × 30s hold · 60s',
      );
    });

    test('whole minutes show as Nm', () {
      expect(
        formatPrescription(_ex(repsMin: 8, repsMax: 8, rest: 120)),
        '4 × 8 · 2m',
      );
    });

    test('short rest stays in seconds', () {
      expect(
        formatPrescription(_ex(repsMin: 12, repsMax: 15, rest: 45)),
        '4 × 12-15 · 45s',
      );
    });

    test('never uses an en dash', () {
      expect(
        formatPrescription(_ex(repsMin: 6, repsMax: 8)).contains(String.fromCharCode(0x2013)),
        isFalse,
      );
    });
  });

  test('fromJson tolerates nulls and sorts by position', () {
    final plan = WorkoutPlan.fromJson({
      'id': 'p',
      'name': null,
      'workout_plan_days': [
        {
          'id': 'd2',
          'position': 1,
          'title': 'Pull',
          'workout_plan_exercises': null,
        },
        {
          'id': 'd1',
          'position': 0,
          'title': 'Push',
          'workout_plan_exercises': [
            {
              'id': 'b',
              'position': 1,
              'name': 'B',
              'kind': 'reps',
              'sets': 3,
              'rest_seconds': 60,
            },
            {
              'id': 'a',
              'position': 0,
              'name': 'A',
              'kind': 'reps',
              'sets': 3,
              'rest_seconds': 60,
            },
          ],
        },
      ],
    });
    expect(plan.days.map((d) => d.title), ['Push', 'Pull']);
    expect(plan.days.first.exercises.map((e) => e.name), ['A', 'B']);
    expect(plan.days.last.exercises, isEmpty);
    expect(nextUpDay(plan), 0);
  });
}
