import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/domain/personal_best.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';
import 'package:life_os/features/review/domain/weekly_workouts.dart';

LoggedSet _set(
  String session,
  String name, {
  String kind = 'reps',
  double? kg,
  int? reps,
  int? hold,
}) => LoggedSet(
  id: '$session$name${kg ?? hold}$reps',
  sessionId: session,
  exerciseName: name,
  kind: kind,
  setNumber: 1,
  reps: reps,
  weightKg: kg,
  holdSeconds: hold,
);

void main() {
  test('counts distinct sessions and all sets', () {
    final w = buildWeeklyWorkouts(
      windowSets: [
        _set('a', 'Squat', kg: 80, reps: 5),
        _set('a', 'Squat', kg: 80, reps: 5),
        _set('b', 'Squat', kg: 80, reps: 5),
      ],
      priorBests: {},
    );
    expect(w.sessionCount, 2);
    expect(w.setCount, 3);
  });

  test('no sets means zero everything', () {
    final w = buildWeeklyWorkouts(windowSets: [], priorBests: {});
    expect(w.sessionCount, 0);
    expect(w.setCount, 0);
    expect(w.personalBests, isEmpty);
  });

  test('first log of an exercise is not a PB', () {
    final w = buildWeeklyWorkouts(
      windowSets: [_set('a', 'Bench press', kg: 60, reps: 8)],
      priorBests: {},
    );
    expect(w.personalBests, isEmpty);
  });

  test('only a strictly better set than the prior best counts', () {
    final prior = _set('old', 'Bench press', kg: 60, reps: 8);
    final key = setGroupKey('Bench press', 'reps');
    final tie = buildWeeklyWorkouts(
      windowSets: [_set('a', 'Bench press', kg: 60, reps: 8)],
      priorBests: {key: prior},
    );
    expect(tie.personalBests, isEmpty);

    final win = buildWeeklyWorkouts(
      windowSets: [
        _set('a', 'Bench press', kg: 60, reps: 8),
        _set('a', 'Bench press', kg: 62.5, reps: 8),
      ],
      priorBests: {key: prior},
    );
    expect(win.personalBests, hasLength(1));
    expect(win.personalBests.single.set.weightKg, 62.5);
    expect(win.personalBests.single.previous, same(prior));
  });

  test('same name with a different kind is a separate exercise', () {
    final w = buildWeeklyWorkouts(
      windowSets: [_set('a', 'Plank', kind: 'time', hold: 75)],
      priorBests: {setGroupKey('Plank', 'reps'): _set('old', 'Plank', reps: 5)},
    );
    expect(w.personalBests, isEmpty);
  });

  test('describes sets and bests in the user units', () {
    final prior = _set('old', 'Bench press', kg: 60, reps: 8);
    final best = _set('a', 'Bench press', kg: 62.5, reps: 8);
    final pb = NewPersonalBest(set: best, previous: prior);
    expect(
      describePersonalBest(pb, UnitSystem.metric),
      'Bench press: 62.5 kg × 8 (best was 60 kg × 8)',
    );
    expect(
      describePersonalBest(pb, UnitSystem.imperial),
      'Bench press: 137.8 lb × 8 (best was 132.3 lb × 8)',
    );
    final plank = NewPersonalBest(
      set: _set('a', 'Plank', kind: 'time', hold: 75),
      previous: _set('old', 'Plank', kind: 'time', hold: 60),
    );
    expect(describePersonalBest(plank, UnitSystem.metric), 'Plank: 75s');
    expect(
      describeSet(_set('a', 'Pull-up', reps: 12), UnitSystem.metric),
      '12 reps',
    );
  });
}
