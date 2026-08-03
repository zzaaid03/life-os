import 'package:life_os/features/notifications/domain/reminder_schedule.dart';

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
  /// Implementations cancel all pending notifications first. That is what
  /// makes [PendingReminder.id] safe as a plain index, and it is also how a
  /// completed or deleted task loses its reminder: the rebuilt schedule simply
  /// no longer contains it.
  Future<void> syncSchedule(List<PendingReminder> reminders);

  /// Cancels every pending reminder, e.g. when the user turns reminders off.
  Future<void> cancelAll();
}
