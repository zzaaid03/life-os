import 'package:life_os/features/notifications/data/local_notification_service.dart';
import 'package:life_os/features/notifications/domain/notification_service.dart';
import 'package:riverpod/riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});
