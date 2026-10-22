import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/data/workout_history_repository.dart';
import 'package:life_os/features/fitness/data/workout_session_repository.dart';
import 'package:life_os/features/fitness/domain/personal_best.dart';
import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/track_notifier.dart';
import 'package:life_os/features/fitness/domain/track_state.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:life_os/features/fitness/presentation/widgets/exercise_history_line.dart';
import 'package:life_os/features/fitness/presentation/widgets/set_row_tile.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

WorkoutPlan _plan(int days) => WorkoutPlan(
  id: 'p',
  name: 'Plan',
  days: [
    for (var i = 0; i < days; i++)
      PlanDay(
        id: 'd$i',
        position: i,
        title: 'Day $i',
        exercises: [
          PlanExercise(
            id: 'e$i',
            position: 0,
            name: 'Squat',
            kind: 'reps',
            sets: 3,
            repsMin: 8,
            repsMax: 10,
            restSeconds: 60,
          ),
        ],
      ),
  ],
);

WorkoutSession _session(int position) => WorkoutSession(
  id: 's',
  dayTitle: 'Day $position',
  dayPosition: position,
  startedAt: DateTime(2026, 10, 22),
);

LoggedSet _set(
  String name,
  int n, {
  String session = 'old',
  int? reps = 10,
  double? kg = 60,
  int? hold,
  String kind = 'reps',
}) => LoggedSet(
  id: '$session-$name-$n',
  sessionId: session,
  exerciseName: name,
  kind: kind,
  setNumber: n,
  reps: reps,
  weightKg: kg,
  holdSeconds: hold,
);

class _FakeRepo implements WorkoutSessionRepository {
  final sets = <LoggedSet>[];
  Map<String, List<LoggedSet>> history = {};
  bool failLog = false;
  bool historyFails = false;
  final calls = <String>[];

  @override
  Future<WorkoutSession?> fetchSession(String id) async => _session(0);

  @override
  Future<List<LoggedSet>> fetchSets(String sessionId) async => [...sets];

  @override
  Future<Map<String, List<LoggedSet>>> fetchLastValues(
    List<String> names, {
    String? excludeSessionId,
  }) async {
    if (historyFails) throw StateError('offline');
    return history;
  }

  @override
  Future<LoggedSet> logSet({
    required String sessionId,
    required String exerciseName,
    required String kind,
    required int setNumber,
    required SetValues values,
  }) async {
    if (failLog) throw StateError('offline');
    final s = LoggedSet(
      id: 'new$setNumber',
      sessionId: sessionId,
      exerciseName: exerciseName,
      kind: kind,
      setNumber: setNumber,
      reps: values.reps,
      weightKg: values.weightKg,
      holdSeconds: values.holdSeconds,
    );
    sets.add(s);
    return s;
  }

  @override
  Future<void> finishSession(String id) async => calls.add('finish');

  @override
  Future<void> deleteSession(String id) async => calls.add('delete');

  @override
  Future<LoggedSet> updateSet(String id, SetValues values) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSet(String id) => throw UnimplementedError();

  @override
  Future<WorkoutSession> startSession({
    required String planId,
    required String dayTitle,
    required int dayPosition,
  }) => throw UnimplementedError();

  @override
  Future<WorkoutSession?> fetchLastSessionWithSets(String planId) =>
      throw UnimplementedError();

  @override
  Future<WorkoutSession?> fetchOpenSession(String planId, DateTime since) =>
      throw UnimplementedError();
}

class _FakeHistory implements WorkoutHistoryRepository {
  Map<String, LoggedSet> bests = {};
  bool fails = false;
  String? excluded;
  int calls = 0;

  @override
  Future<Map<String, LoggedSet>> fetchBests(
    List<({String name, String kind})> exercises, {
    String? excludeSessionId,
  }) async {
    calls++;
    excluded = excludeSessionId;
    if (fails) throw StateError('offline');
    return bests;
  }

  @override
  Future<WorkoutWindow> fetchWindow(DateTime startUtc, DateTime endUtc) =>
      throw UnimplementedError();
}

TrackExercise _exercise(
  List<LoggedSet?> rows, {
  LoggedSet? best,
  bool bestFailed = false,
  List<LoggedSet> last = const [],
}) => TrackExercise(
  key: 'ex',
  name: 'Squat',
  kind: 'reps',
  rows: [
    for (var i = 0; i < rows.length; i++)
      TrackRow(
        key: 'r$i',
        setNumber: i + 1,
        initial: const SetValues(reps: 8),
        logged: rows[i],
      ),
  ],
  best: best,
  bestFailed: bestFailed,
  lastSets: last,
);

void main() {
  group('nextUpDay', () {
    test('no session means the first day', () {
      expect(nextUpDay(_plan(3), null), 0);
    });
    test('goes to the day after the last session', () {
      expect(nextUpDay(_plan(3), _session(0)), 1);
      expect(nextUpDay(_plan(3), _session(1)), 2);
    });
    test('wraps from the last day to the first', () {
      expect(nextUpDay(_plan(3), _session(2)), 0);
    });
    test('a one-day plan always points at its only day', () {
      expect(nextUpDay(_plan(1), null), 0);
      expect(nextUpDay(_plan(1), _session(0)), 0);
    });
  });

  group('prefillSet', () {
    test('history wins over the plan', () {
      final v = prefillSet(
        kind: 'reps',
        index: 0,
        history: [_set('Squat', 1, reps: 12, kg: 80)],
        planReps: 8,
      );
      expect(v.reps, 12);
      expect(v.weightKg, 80);
    });
    test('extra rows reuse the last logged set', () {
      final v = prefillSet(
        kind: 'reps',
        index: 4,
        history: [_set('Squat', 1, reps: 12), _set('Squat', 2, reps: 9)],
      );
      expect(v.reps, 9);
    });
    test('no history falls back to the plan, weight empty', () {
      final v = prefillSet(kind: 'reps', index: 0, history: [], planReps: 8);
      expect(v.reps, 8);
      expect(v.weightKg, isNull);
      final t = prefillSet(kind: 'time', index: 0, history: [], planHold: 30);
      expect(t.holdSeconds, 30);
    });
    test('history of another kind is ignored', () {
      final v = prefillSet(
        kind: 'time',
        index: 0,
        history: [_set('Plank', 1, reps: 10)],
        planHold: 45,
      );
      expect(v.holdSeconds, 45);
    });
  });

  group('weight units', () {
    test('lb round trips through stored kg', () {
      for (final lb in ['135', '22.5', '45.5', '10']) {
        final r = parseSetInput(
          kind: 'reps',
          reps: '5',
          hold: '',
          weight: lb,
          units: UnitSystem.imperial,
        );
        expect(weightText(r.values!.weightKg, UnitSystem.imperial), lb);
      }
    });
    test('kg shows up to 2 decimals without trailing zeros', () {
      expect(weightText(60, UnitSystem.metric), '60');
      expect(weightText(62.5, UnitSystem.metric), '62.5');
      expect(weightText(61.23, UnitSystem.metric), '61.23');
      expect(weightText(null, UnitSystem.metric), '');
    });
    test('stored weight is kg rounded to 2 decimals', () {
      final r = parseSetInput(
        kind: 'reps',
        reps: '5',
        hold: '',
        weight: '135',
        units: UnitSystem.imperial,
      );
      expect(r.values!.weightKg, 61.23);
    });
  });

  group('parseSetInput', () {
    SetParseResult p(
      String kind, {
      String reps = '',
      String hold = '',
      String w = '',
    }) => parseSetInput(
      kind: kind,
      reps: reps,
      hold: hold,
      weight: w,
      units: UnitSystem.metric,
    );

    test('reps set needs reps 1-200 and has no hold', () {
      expect(p('reps', reps: '').error, isNotNull);
      expect(p('reps', reps: '0').error, isNotNull);
      expect(p('reps', reps: '201').error, isNotNull);
      expect(p('reps', reps: '8.5').error, isNotNull);
      final ok = p('reps', reps: '200', hold: '30');
      expect(ok.values!.reps, 200);
      expect(ok.values!.holdSeconds, isNull);
    });
    test('time set needs seconds 1-3600 and has no reps', () {
      expect(p('time', hold: '0').error, isNotNull);
      expect(p('time', hold: '3601').error, isNotNull);
      final ok = p('time', hold: '3600', reps: '5');
      expect(ok.values!.holdSeconds, 3600);
      expect(ok.values!.reps, isNull);
    });
    test('weight is optional, 0-1000 kg, finite', () {
      expect(p('reps', reps: '5').values!.weightKg, isNull);
      expect(p('reps', reps: '5', w: '0').values!.weightKg, 0);
      expect(p('reps', reps: '5', w: '1000').values!.weightKg, 1000);
      expect(p('reps', reps: '5', w: '1000.01').error, isNotNull);
      expect(p('reps', reps: '5', w: '-1').error, isNotNull);
      expect(p('reps', reps: '5', w: 'NaN').error, isNotNull);
      expect(p('reps', reps: '5', w: '62,5').values!.weightKg, 62.5);
    });
    test('weight is allowed on a time set', () {
      expect(p('time', hold: '30', w: '10').values!.weightKg, 10);
    });
  });

  group('lastSessionSets', () {
    test('keeps only the newest session per exercise, by set number', () {
      final out = lastSessionSets([
        _set('Squat', 2, session: 'b'),
        _set('Squat', 1, session: 'b'),
        _set('Squat', 1, session: 'a'),
        _set('Bench', 1, session: 'a'),
      ]);
      expect(out['Squat']!.map((s) => s.setNumber), [1, 2]);
      expect(out['Squat']!.every((s) => s.sessionId == 'b'), isTrue);
      expect(out['Bench']!.length, 1);
    });
  });

  group('TrackNotifier', () {
    late _FakeRepo repo;
    late int trained;
    late int refreshed;
    late bool trainedFails;
    late _FakeHistory history;

    TrackNotifier make() => TrackNotifier(
      repository: repo,
      historyRepository: history,
      sessionId: 's',
      readPlan: () => _plan(2),
      markTrained: () async {
        if (trainedFails) throw StateError('offline');
        trained++;
      },
      onChanged: () async => refreshed++,
    );

    setUp(() {
      repo = _FakeRepo();
      history = _FakeHistory();
      trained = 0;
      refreshed = 0;
      trainedFails = false;
    });

    test('rows are prefilled from history, else from the plan', () async {
      repo.history = {
        'Squat': [_set('Squat', 1, reps: 12, kg: 70)],
      };
      final n = make();
      await n.load();
      expect(n.state.exercises.single.rows.length, 3);
      expect(n.state.exercises.single.rows.first.initial.reps, 12);
      repo.history = {};
      final m = make();
      await m.load();
      expect(m.state.exercises.single.rows.first.initial.reps, 8);
    });

    test('a failed history load is flagged, not hidden', () async {
      repo.historyFails = true;
      final n = make();
      await n.load();
      expect(n.state.historyFailed, isTrue);
      expect(n.state.exercises.single.rows.first.initial.reps, 8);
    });

    test('a row is logged only after the insert succeeds', () async {
      final n = make();
      await n.load();
      repo.failLog = true;
      await expectLater(
        n.logRow(0, 0, const SetValues(reps: 8)),
        throwsA(isA<StateError>()),
      );
      expect(n.state.exercises.single.rows.first.logged, isNull);
      expect(n.state.exercises.single.rows.first.saving, isFalse);
      repo.failLog = false;
      await n.logRow(0, 0, const SetValues(reps: 8));
      expect(n.state.exercises.single.rows.first.logged, isNotNull);
    });

    test('quit with 0 sets deletes the session, no check-in', () async {
      final n = make();
      await n.load();
      expect(await n.leave(), WorkoutExit.discarded);
      expect(repo.calls, ['delete']);
      expect(trained, 0);
      expect(refreshed, 1);
    });

    test('quit with 1+ sets finishes and marks trained', () async {
      final n = make();
      await n.load();
      await n.logRow(0, 0, const SetValues(reps: 8));
      expect(await n.leave(), WorkoutExit.saved);
      expect(repo.calls, ['finish']);
      expect(trained, 1);
    });

    test('a failed check-in still closes the session and says so', () async {
      final n = make();
      await n.load();
      await n.logRow(0, 0, const SetValues(reps: 8));
      trainedFails = true;
      expect(await n.leave(), WorkoutExit.savedCheckinFailed);
      expect(repo.calls, ['finish']);
    });

    test('bests are loaded, excluding the current session', () async {
      history.bests = {
        setGroupKey('Squat', 'reps'): _set('Squat', 1, kg: 100, reps: 5),
      };
      final n = make();
      await n.load();
      expect(n.state.exercises.single.best!.weightKg, 100);
      expect(n.state.exercises.single.bestFailed, isFalse);
      expect(history.excluded, 's');
    });

    test('a failed best load only sets bestFailed', () async {
      history.fails = true;
      repo.history = {
        'Squat': [_set('Squat', 1, reps: 12, kg: 70)],
      };
      final n = make();
      await n.load();
      expect(n.state.exercises.single.bestFailed, isTrue);
      expect(n.state.exercises.single.best, isNull);
      expect(n.state.historyFailed, isFalse);
      expect(n.state.error, isNull);
      expect(n.state.exercises.single.lastSets.length, 1);
    });

    test('an exercise added mid-workout loads its best', () async {
      history.bests = {
        setGroupKey('Curl', 'reps'): _set('Curl', 1, kg: 20, reps: 8),
      };
      final n = make();
      await n.load();
      await n.addExercise('Curl', 'reps');
      expect(n.state.exercises.last.best!.weightKg, 20);
      expect(history.excluded, 's');
    });
  });

  group('new best marker', () {
    final before = _set('Squat', 1, kg: 100, reps: 5);
    LoggedSet mine(int n, double kg, int reps) =>
        _set('Squat', n, session: 's', kg: kg, reps: reps);

    test('the top set that beats the best is marked', () {
      final ex = _exercise([mine(1, 90, 8), mine(2, 105, 5)], best: before);
      expect(ex.newBestRow!.setNumber, 2);
    });

    test('a tie is not marked', () {
      expect(_exercise([mine(1, 100, 5)], best: before).newBestRow, isNull);
    });

    test('with two beating sets only the top one is marked', () {
      final ex = _exercise([mine(1, 105, 5), mine(2, 110, 3)], best: before);
      expect(ex.newBestRow!.setNumber, 2);
    });

    test('a first-time exercise is never marked', () {
      expect(_exercise([mine(1, 200, 5)]).newBestRow, isNull);
    });

    test('nothing is marked while the best failed to load', () {
      final ex = _exercise([mine(1, 200, 5)], bestFailed: true);
      expect(ex.newBestRow, isNull);
    });

    test('unlogged rows are ignored', () {
      expect(_exercise([null, null], best: before).newBestRow, isNull);
    });

    test('removing the top set moves the mark or clears it', () {
      final both = _exercise([mine(1, 105, 5), mine(2, 110, 3)], best: before);
      expect(both.newBestRow!.setNumber, 2);
      final one = both.copyWith(
        rows: [both.rows[0], both.rows[1].copyWith(clearLogged: true)],
      );
      expect(one.newBestRow!.setNumber, 1);
      final none = one.copyWith(
        rows: [one.rows[0].copyWith(clearLogged: true), one.rows[1]],
      );
      expect(none.newBestRow, isNull);
    });
  });

  group('track widgets', () {
    Future<void> pump(WidgetTester tester, Widget child) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

    testWidgets('history line with last time and best', (tester) async {
      final last = [
        for (var i = 1; i <= 7; i++) _set('Squat', i, kg: 60, reps: 8),
      ];
      await pump(
        tester,
        ExerciseHistoryLine(
          exercise: _exercise(
            [null],
            best: _set('Squat', 1, kg: 62.5, reps: 8),
            last: last,
          ),
          units: UnitSystem.metric,
        ),
      );
      expect(
        find.text(
          'Last time: 60 kg × 8, 60 kg × 8, 60 kg × 8, 60 kg × 8, 60 kg × 8 +2 more',
        ),
        findsOneWidget,
      );
      expect(find.text('Best: 62.5 kg × 8'), findsOneWidget);
    });

    testWidgets('history line for a first time exercise', (tester) async {
      await pump(
        tester,
        ExerciseHistoryLine(
          exercise: _exercise([null]),
          units: UnitSystem.metric,
        ),
      );
      expect(find.text('First time doing this one.'), findsOneWidget);
      expect(find.textContaining('Best'), findsNothing);
    });

    testWidgets('history line when the best failed', (tester) async {
      await pump(
        tester,
        ExerciseHistoryLine(
          exercise: _exercise([null], bestFailed: true),
          units: UnitSystem.metric,
        ),
      );
      expect(find.text("Couldn't load your best."), findsOneWidget);
      expect(find.textContaining('Best:'), findsNothing);
    });

    for (final marked in [true, false]) {
      testWidgets('logged row ${marked ? 'shows' : 'hides'} New best', (
        tester,
      ) async {
        final logged = _set('Squat', 1, session: 's', kg: 105, reps: 5);
        await pump(
          tester,
          SetRowTile(
            row: TrackRow(
              key: 'r',
              setNumber: 1,
              initial: const SetValues(reps: 5),
              logged: logged,
            ),
            kind: 'reps',
            units: UnitSystem.metric,
            newBest: marked,
            onLog: (_) async {},
            onUpdate: (_) async {},
            onRemove: () async {},
          ),
        );
        expect(find.text('New best'), marked ? findsOneWidget : findsNothing);
        expect(
          find.byIcon(Icons.emoji_events_outlined),
          marked ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
