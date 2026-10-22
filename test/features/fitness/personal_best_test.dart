import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/domain/personal_best.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';

LoggedSet _reps({double? kg, int reps = 8, String name = 'Bench press'}) =>
    LoggedSet(
      id: 'x',
      sessionId: 's',
      exerciseName: name,
      kind: 'reps',
      setNumber: 1,
      reps: reps,
      weightKg: kg,
    );

LoggedSet _hold(int seconds) => LoggedSet(
  id: 'x',
  sessionId: 's',
  exerciseName: 'Plank',
  kind: 'time',
  setNumber: 1,
  holdSeconds: seconds,
);

void main() {
  group('isBetterSet', () {
    test('heavier weight wins even with fewer reps', () {
      expect(
        isBetterSet(_reps(kg: 62.5, reps: 5), _reps(kg: 60, reps: 10)),
        true,
      );
      expect(
        isBetterSet(_reps(kg: 60, reps: 10), _reps(kg: 62.5, reps: 5)),
        false,
      );
    });

    test('same weight: more reps wins, equal is not better', () {
      expect(isBetterSet(_reps(kg: 60, reps: 9), _reps(kg: 60, reps: 8)), true);
      expect(
        isBetterSet(_reps(kg: 60, reps: 8), _reps(kg: 60, reps: 8)),
        false,
      );
    });

    test('bodyweight: most reps wins', () {
      expect(isBetterSet(_reps(reps: 12), _reps(reps: 10)), true);
      expect(isBetterSet(_reps(kg: 0, reps: 10), _reps(reps: 12)), false);
    });

    test('time: longest hold wins', () {
      expect(isBetterSet(_hold(75), _hold(60)), true);
      expect(isBetterSet(_hold(60), _hold(60)), false);
    });
  });

  group('bestSet', () {
    test('empty is null', () => expect(bestSet(const []), isNull));

    test('picks the best, first one on a tie', () {
      final a = _reps(kg: 60);
      final b = _reps(kg: 62.5, reps: 6);
      final c = _reps(kg: 62.5, reps: 6);
      expect(bestSet([a, b, c]), same(b));
    });
  });
}
