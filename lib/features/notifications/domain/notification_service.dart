import 'package:life_os/features/notifications/domain/reminder_schedule.dart';

/// Notification ids at or above this belong to cook-mode timers; everything
/// below is a task reminder (reminders use their list index, capped at 64).
///
/// The split exists so rebuilding the reminder schedule, which happens every
/// time a task changes, never cancels a timer that is counting down while
/// someone cooks.
const int kCookTimerIdBase = 100000;

/// Schedules and clears local task reminders on the device.
///
/// Local notifications, NOT push. Consequences worth knowing before changing
/// anything here:
/// - A scheduled reminder DOES fire when the app is closed or force-quit. The
///   OS holds it; the app does not need to be running.
/// - But only an OPEN app can schedule one. A task created on the web while
///   the phone is shut will have no reminder until the phone app next opens
///   and re-syncs. Closing that gap needs real push (APNs), which needs a paid
///   Apple Developer account. That is a known, accepted limitation, not a bug
///   to be worked around with background fetch (iOS runs it whenever it likes,
///   which would make reminders randomly unreliable instead of predictably
///   limited).
abstract class NotificationService {
  /// Prepares the platform plugin and the local timezone database.
  ///
  /// Safe to call more than once; implementations must be idempotent because
  /// the app can rebuild its provider container (demo mode does exactly that).
  Future<void> initialize();

  /// Asks the OS for permission to show notifications.
  ///
  /// Returns whether permission is granted. Callers must treat `false` as a
  /// normal outcome and carry on, not as an error: the user is allowed to say
  /// no, and the rest of the app works fine without reminders.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder with exactly [reminders].
  ///
  /// Implementations cancel every pending REMINDER first (ids below
  /// [kCookTimerIdBase], never cook timers). That is what makes
  /// [PendingReminder.id] safe as a plain index, and it is also how a
  /// completed or deleted task loses its reminder: the rebuilt schedule simply
  /// no longer contains it.
  Future<void> syncSchedule(List<PendingReminder> reminders);

  /// Cancels every pending task reminder, e.g. when the user turns reminders
  /// off. Cook timers are left alone.
  Future<void> cancelReminders();

  /// Schedules a one-off "timer finished" notification for cook mode, so a
  /// timer still announces itself with the phone locked. [id] must be at or
  /// above [kCookTimerIdBase]. Never throws: a timer works in-app without it.
  Future<void> scheduleCookTimer({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
  });

  /// Cancels a cook timer notification (paused, cancelled, or finished
  /// in-app). Never throws.
  Future<void> cancelCookTimer(int id);
}
