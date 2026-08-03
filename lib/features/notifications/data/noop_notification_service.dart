import 'package:life_os/features/notifications/domain/notification_service.dart';
import 'package:life_os/features/notifications/domain/reminder_schedule.dart';

/// [NotificationService] that never touches the platform.
///
/// Used by demo mode, which must stay entirely free of platform side effects
/// (no OS permission prompts, no scheduled alarms) for an ephemeral,
/// no-sign-up sandbox.
class NoopNotificationService implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> syncSchedule(List<PendingReminder> reminders) async {}

  @override
  Future<void> cancelAll() async {}
}
