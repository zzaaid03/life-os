import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/fitness/data/workout_checkin_repository.dart';
import 'package:life_os/features/fitness/domain/workout_checkin_providers.dart';
import 'package:life_os/features/fitness/presentation/widgets/checkin_card.dart';

class _Repo implements WorkoutCheckinRepository {
  _Repo({this.stored, this.failFetch = false, this.failSave = false});

  bool? stored;
  bool failFetch;
  bool failSave;
  final fetchedDates = <String>[];
  final savedDates = <String>[];

  @override
  Future<bool?> fetch(String localDate) async {
    fetchedDates.add(localDate);
    if (failFetch) throw StateError('offline');
    return stored;
  }

  @override
  Future<void> save(String localDate, {required bool trained}) async {
    if (failSave) throw StateError('offline');
    savedDates.add(localDate);
    stored = trained;
  }
}

Widget _app(_Repo repo) {
  return ProviderScope(
    overrides: [
      workoutCheckinProvider.overrideWith(
        (ref) => WorkoutCheckinNotifier(repo),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: CheckinCard())),
  );
}

void main() {
  group('WorkoutCheckinNotifier', () {
    test('loaded with no answer is null, not failed', () async {
      final n = WorkoutCheckinNotifier(_Repo());
      await n.load();
      expect(n.state.loaded, isTrue);
      expect(n.state.loadFailed, isFalse);
      expect(n.state.trained, isNull);
    });

    test('loaded true and false', () async {
      final repo = _Repo(stored: true);
      final n = WorkoutCheckinNotifier(repo);
      await n.load();
      expect(n.state.trained, isTrue);
      repo.stored = false;
      await n.load();
      expect(n.state.trained, isFalse);
    });

    test('load failure is flagged and keeps the earlier answer', () async {
      final repo = _Repo(stored: true);
      final n = WorkoutCheckinNotifier(repo);
      await n.load();
      repo.failFetch = true;
      await n.load();
      expect(n.state.loadFailed, isTrue);
      expect(n.state.trained, isTrue);
    });

    test('load uses the local date and recomputes it every time', () async {
      final repo = _Repo();
      var now = DateTime(2026, 10, 22, 23, 59);
      final n = WorkoutCheckinNotifier(repo, now: () => now);
      await n.load();
      now = DateTime(2026, 10, 23, 0, 1);
      await n.load();
      expect(repo.fetchedDates, ['2026-10-22', '2026-10-23']);
    });

    test('setTrained saves and updates state', () async {
      final repo = _Repo();
      final n = WorkoutCheckinNotifier(
        repo,
        now: () => DateTime(2026, 10, 22, 9),
      );
      await n.markTrainedToday();
      expect(repo.savedDates, ['2026-10-22']);
      expect(n.state.trained, isTrue);
    });

    test('failed save reloads and rethrows', () async {
      final repo = _Repo(failSave: true);
      final n = WorkoutCheckinNotifier(repo);
      await expectLater(n.setTrained(trained: true), throwsStateError);
      expect(repo.fetchedDates, hasLength(1));
      expect(n.state.trained, isNull);
    });

    test('trainedToday ignores an answer from another day', () {
      const s = WorkoutCheckinState(
        loaded: true,
        localDate: '2026-10-22',
        trained: true,
      );
      expect(trainedToday(s, DateTime(2026, 10, 22, 8)), isTrue);
      expect(trainedToday(s, DateTime(2026, 10, 23, 0, 1)), isFalse);
    });
  });

  group('CheckinCard', () {
    testWidgets('not answered shows the question and Yes / No', (tester) async {
      await tester.pumpWidget(_app(_Repo()));
      await tester.pump();
      expect(find.text('Did you train today?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('tapping Yes shows Trained today and Change', (tester) async {
      await tester.pumpWidget(_app(_Repo()));
      await tester.pump();
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(find.text('Trained today ✓'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('answered no shows Rest day and Change flips it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_Repo(stored: false)));
      await tester.pump();
      expect(find.text('Rest day'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pump();
      expect(find.text('Trained today ✓'), findsOneWidget);
    });

    testWidgets('failed load shows Retry, never the question', (tester) async {
      await tester.pumpWidget(_app(_Repo(failFetch: true)));
      await tester.pump();
      expect(find.text("Couldn't load today's check-in"), findsOneWidget);
      expect(find.text('Did you train today?'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('failed save shows a snackbar', (tester) async {
      await tester.pumpWidget(_app(_Repo(failSave: true)));
      await tester.pump();
      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining("Couldn't save"), findsOneWidget);
      expect(find.text('Did you train today?'), findsOneWidget);
    });
  });
}
