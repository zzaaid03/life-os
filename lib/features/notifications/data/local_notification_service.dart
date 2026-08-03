import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:life_os/features/notifications/domain/notification_service.dart';
import 'package:life_os/features/notifications/domain/reminder_schedule.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Real [NotificationService] backed by `flutter_local_notifications`.
class LocalNotificationService implements NotificationService {
  static const String _androidChannelId = 'task_reminders';
  static const String _androidChannelName = 'Task reminders';
  static const String _androidChannelDescription =
      'Reminders for tasks with a due date.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
      // Deliberately NOT calling requestExactAlarmsPermission() here. It
      // launches a system settings screen, throwing the user out of the app
      // mid-flow, and we do not need exact alarms: a 09:00 reminder is just as
      // useful at 09:12. syncSchedule() checks whether the grant happens to
      // exist and picks its schedule mode accordingly.
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  @override
  Future<void> syncSchedule(List<PendingReminder> reminders) async {
    await cancelAll();

    // On Android 14+ the exact-alarm grant is not automatic, and the plugin's
    // documented behaviour without it is to log an error and NOT schedule the
    // notification at all. That would mean reminders silently never fire, with
    // nothing in the app to explain it. So ask first and fall back to inexact,
    // which still delivers, just not to the minute. Precision is worth far
    // less here than the reminder existing.
    final scheduleMode = await _androidScheduleMode();

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    for (final reminder in reminders) {
      final fireAt = tz.TZDateTime.from(reminder.fireAt, tz.local);
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: fireAt,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: reminder.taskId,
      );
    }
  }

  /// Picks the strongest Android schedule mode this device will actually
  /// honour. Non-Android platforms ignore the value entirely.
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final canBeExact = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();
    return (canBeExact ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
