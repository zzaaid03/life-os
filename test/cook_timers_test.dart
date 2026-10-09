import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/notifications/domain/notification_service.dart';
import 'package:life_os/features/notifications/domain/reminder_schedule.dart';
import 'package:life_os/features/recipes/domain/cook_timers.dart';

class _FakeNotifications implements NotificationService {
  final scheduled = <int>{};
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> syncSchedule(List<PendingReminder> reminders) async {}
  @override
  Future<void> cancelReminders() async {}
  @override
  Future<void> scheduleCookTimer({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
  }) async => scheduled.add(id);
  @override
  Future<void> cancelCookTimer(int id) async => scheduled.remove(id);
}

void main() {
  late DateTime now;
  late _FakeNotifications notifications;
  late CookTimersNotifier timers;

  setUp(() {
    now = DateTime(2026, 10, 9, 18);
    notifications = _FakeNotifications();
    timers = CookTimersNotifier(notifications, clock: () => now);
  });
  tearDown(() => timers.dispose());

  CookTimer start({int step = 0, int seconds = 600}) => timers.start(
    recipeTitle: 'Curry',
    stepIndex: step,
    label: 'Simmer',
    seconds: seconds,
  );

  test('counts down from an end time and schedules a notification', () {
    final t = start();
    expect(t.id, greaterThanOrEqualTo(kCookTimerIdBase));
    expect(notifications.scheduled, {t.id});
    now = now.add(const Duration(minutes: 4));
    expect(timers.state.single.remaining(now), const Duration(minutes: 6));
    expect(timers.state.single.progress(now), closeTo(0.4, 0.001));
  });

  test('pause freezes the time left and cancels the notification', () {
    final t = start();
    now = now.add(const Duration(minutes: 1));
    timers.pause(t.id);
    expect(notifications.scheduled, isEmpty);
    now = now.add(const Duration(minutes: 30));
    expect(timers.state.single.remaining(now), const Duration(minutes: 9));

    timers.resume(t.id);
    expect(notifications.scheduled, {t.id});
    now = now.add(const Duration(minutes: 2));
    expect(timers.state.single.remaining(now), const Duration(minutes: 7));
  });

  test('several timers run at once; restarting a step replaces its timer', () {
    start(step: 0);
    start(step: 2, seconds: 300);
    expect(timers.state.length, 2);
    start(step: 0, seconds: 60);
    expect(timers.state.length, 2);
    expect(timers.forStep('Curry', 0)!.totalSeconds, 60);
  });

  test('add time extends a running timer', () {
    final t = start(seconds: 120);
    timers.addTime(t.id, 60);
    expect(timers.state.single.remaining(now), const Duration(minutes: 3));
    expect(timers.state.single.totalSeconds, 180);
  });

  test('cancel and clearAll remove timers and their notifications', () {
    final a = start(step: 0);
    start(step: 1);
    timers.cancel(a.id);
    expect(timers.state.length, 1);
    timers.clearAll();
    expect(timers.state, isEmpty);
    expect(notifications.scheduled, isEmpty);
  });

  test('a finished timer fires onFinished once and can be revived', () async {
    final fired = <CookTimer>[];
    final sub = timers.onFinished.listen(fired.add);
    final t = start(seconds: 0);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fired.length, 1);
    expect(timers.state.single.finished, isTrue);
    expect(timers.state.single.remaining(now), Duration.zero);

    timers.addTime(t.id, 60);
    expect(timers.state.single.finished, isFalse);
    expect(timers.state.single.remaining(now), const Duration(minutes: 1));
    await sub.cancel();
  });

  test('formatTimer', () {
    expect(formatTimer(const Duration(seconds: 65)), '1:05');
    expect(formatTimer(const Duration(minutes: 12)), '12:00');
    expect(formatTimer(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });
}
