/// Cook-mode timers.
///
/// Several can run at once (pasta and sauce). Each stores an END TIME, not a
/// countdown, so it stays correct across a backgrounded app or a dropped
/// frame; the UI just compares against the clock from [cookClockProvider].
///
/// Timers live app-wide, not inside the cook screen, so they keep running if
/// the user backs out to check the grocery list. Each running timer also
/// schedules a local notification (ids from [kCookTimerIdBase]) so it is
/// heard with the phone locked; pausing, cancelling or dismissing cancels it.
/// On web there is no notification, only the in-app alert.
library;

import 'dart:async';

import 'package:life_os/features/notifications/domain/notification_service.dart';
import 'package:life_os/features/notifications/domain/providers/notification_service_provider.dart';
import 'package:riverpod/riverpod.dart';

/// One timer.
class CookTimer {
  /// Creates a [CookTimer].
  const CookTimer({
    required this.id,
    required this.recipeTitle,
    required this.stepIndex,
    required this.label,
    required this.totalSeconds,
    this.endsAt,
    this.pausedRemaining,
    this.finished = false,
  });

  /// Unique id, also the notification id (>= [kCookTimerIdBase]).
  final int id;

  /// The recipe it belongs to, for the notification text.
  final String recipeTitle;

  /// The step that started it, so the floating bar can jump back to it.
  final int stepIndex;

  /// Short name, e.g. "Simmer sauce".
  final String label;

  /// Length when started (plus any time added).
  final int totalSeconds;

  /// When it ends, while running. Null when paused or finished.
  final DateTime? endsAt;

  /// Time left, while paused.
  final Duration? pausedRemaining;

  /// Whether it has run out and not been dismissed yet.
  final bool finished;

  /// Whether it is counting down.
  bool get isRunning => endsAt != null && !finished;

  /// Whether it is paused.
  bool get isPaused => pausedRemaining != null && !finished;

  /// Time left at [now], never negative.
  Duration remaining(DateTime now) {
    if (finished) return Duration.zero;
    if (pausedRemaining != null) return pausedRemaining!;
    final left = endsAt!.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Fraction elapsed at [now], 0.0 to 1.0, for a progress ring.
  double progress(DateTime now) {
    if (totalSeconds <= 0) return 1;
    final left = remaining(now).inMilliseconds / 1000;
    return (1 - left / totalSeconds).clamp(0.0, 1.0);
  }

  CookTimer _copy({
    int? totalSeconds,
    DateTime? endsAt,
    Duration? pausedRemaining,
    bool clearEndsAt = false,
    bool clearPaused = false,
    bool? finished,
  }) => CookTimer(
    id: id,
    recipeTitle: recipeTitle,
    stepIndex: stepIndex,
    label: label,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
    pausedRemaining: clearPaused ? null : (pausedRemaining ?? this.pausedRemaining),
    finished: finished ?? this.finished,
  );
}

/// "1:05", "12:00", "1:02:03".
String formatTimer(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Owns every cook timer.
class CookTimersNotifier extends StateNotifier<List<CookTimer>> {
  /// Creates a [CookTimersNotifier].
  CookTimersNotifier(this._notifications, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const []);

  final NotificationService _notifications;
  final DateTime Function() _clock;
  final Map<int, Timer> _alarms = {};
  final StreamController<CookTimer> _finished = StreamController.broadcast();
  int _seq = 0;

  /// Emits a timer the moment it runs out while the app is open. The cook
  /// screen listens to play haptics and show the alert. Fires once per
  /// timer run.
  Stream<CookTimer> get onFinished => _finished.stream;

  /// The live timer for [stepIndex] of [recipeTitle], if any.
  CookTimer? forStep(String recipeTitle, int stepIndex) {
    for (final t in state) {
      if (t.recipeTitle == recipeTitle && t.stepIndex == stepIndex) return t;
    }
    return null;
  }

  /// Starts a timer. Starting one for a step that already has a timer
  /// restarts that timer instead of adding a second.
  CookTimer start({
    required String recipeTitle,
    required int stepIndex,
    required String label,
    required int seconds,
  }) {
    final existing = forStep(recipeTitle, stepIndex);
    if (existing != null) _remove(existing.id);
    final timer = CookTimer(
      id: kCookTimerIdBase + (_seq++ % 100000),
      recipeTitle: recipeTitle,
      stepIndex: stepIndex,
      label: label,
      totalSeconds: seconds,
      endsAt: _clock().add(Duration(seconds: seconds)),
    );
    state = [...state, timer];
    _arm(timer);
    return timer;
  }

  /// Pauses a running timer.
  void pause(int id) {
    final t = _find(id);
    if (t == null || !t.isRunning) return;
    _disarm(id);
    _put(t._copy(pausedRemaining: t.remaining(_clock()), clearEndsAt: true));
  }

  /// Resumes a paused timer.
  void resume(int id) {
    final t = _find(id);
    if (t == null || !t.isPaused) return;
    final resumed = t._copy(endsAt: _clock().add(t.pausedRemaining!), clearPaused: true);
    _put(resumed);
    _arm(resumed);
  }

  /// Adds [seconds] (e.g. "+1 min"). Revives a finished timer.
  void addTime(int id, int seconds) {
    final t = _find(id);
    if (t == null) return;
    final now = _clock();
    _disarm(id);
    final CookTimer next;
    if (t.isPaused) {
      next = t._copy(
        totalSeconds: t.totalSeconds + seconds,
        pausedRemaining: t.pausedRemaining! + Duration(seconds: seconds),
      );
      _put(next);
      return;
    }
    next = t._copy(
      totalSeconds: t.finished ? seconds : t.totalSeconds + seconds,
      endsAt: (t.finished ? now : t.endsAt!).add(Duration(seconds: seconds)),
      finished: false,
    );
    _put(next);
    _arm(next);
  }

  /// Removes a timer, running or not.
  void cancel(int id) => _remove(id);

  /// Removes a finished timer once the user acknowledged it.
  void dismiss(int id) => _remove(id);

  /// Removes every timer (cook mode finished or abandoned).
  void clearAll() {
    for (final t in [...state]) {
      _remove(t.id);
    }
  }

  void _arm(CookTimer t) {
    _alarms[t.id]?.cancel();
    final left = t.endsAt!.difference(_clock());
    _alarms[t.id] = Timer(left.isNegative ? Duration.zero : left, () => _fire(t.id));
    unawaited(
      _notifications.scheduleCookTimer(
        id: t.id,
        fireAt: t.endsAt!,
        title: '${t.label} is done',
        body: t.recipeTitle,
      ),
    );
  }

  void _disarm(int id) {
    _alarms.remove(id)?.cancel();
    unawaited(_notifications.cancelCookTimer(id));
  }

  void _fire(int id) {
    _alarms.remove(id);
    final t = _find(id);
    if (t == null || !t.isRunning) return;
    final done = t._copy(finished: true, clearEndsAt: true);
    _put(done);
    _finished.add(done);
  }

  void _remove(int id) {
    _disarm(id);
    state = state.where((t) => t.id != id).toList();
  }

  CookTimer? _find(int id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _put(CookTimer t) {
    state = [for (final x in state) x.id == t.id ? t : x];
  }

  @override
  void dispose() {
    for (final a in _alarms.values) {
      a.cancel();
    }
    _finished.close();
    super.dispose();
  }
}

/// Every cook timer, app-wide.
final cookTimersProvider = StateNotifierProvider<CookTimersNotifier, List<CookTimer>>((ref) {
  return CookTimersNotifier(ref.watch(notificationServiceProvider));
});

/// Ticks once a second while something watches it. Timer UIs watch this and
/// call [CookTimer.remaining] with the value.
final cookClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
