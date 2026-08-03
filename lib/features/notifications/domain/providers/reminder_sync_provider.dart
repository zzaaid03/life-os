import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_os/features/notifications/domain/notification_service.dart';
import 'package:life_os/features/notifications/domain/providers/notification_service_provider.dart';
import 'package:life_os/features/notifications/domain/providers/reminder_settings_provider.dart';
import 'package:life_os/features/notifications/domain/reminder_schedule.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:riverpod/riverpod.dart';

/// Keeps the device's scheduled reminders in sync with the task list and the
/// user's "Task reminders" preference.
///
/// This is the ONLY place that talks to [NotificationService]. The Settings
/// switch just writes a preference; this reacts to it. Keeping every OS call
/// behind one listener means there is exactly one answer to "why did a
/// notification appear", instead of several screens racing to schedule.
class ReminderSyncController {
  /// Creates the controller and starts listening.
  ReminderSyncController(this._ref) {
    // Web has no local notification support at all, and calling the plugin
    // there throws. Bail out before subscribing to anything so the web build
    // carries no notification behaviour whatsoever.
    if (kIsWeb) return;

    _ref.listen<TaskListState>(
      taskListProvider,
      (_, next) => _onChanged(),
      fireImmediately: true,
    );
    _ref.listen<ReminderSettingsState>(
      reminderSettingsProvider,
      (_, next) => _onChanged(),
      fireImmediately: true,
    );
  }

  final Ref _ref;

  Timer? _debounceTimer;
  bool _syncing = false;
  bool _resyncRequested = false;
  bool _permissionRequested = false;
  String? _lastSignature;

  /// Identity of everything that can change what should be scheduled.
  ///
  /// Rebuilding on every task-list emission would re-issue up to 64 platform
  /// calls for edits that cannot affect a reminder (a renamed description, a
  /// reordered list). The signature covers only what [buildReminderSchedule]
  /// actually reads.
  String _signatureFor(List<Task> tasks, bool enabled) {
    final parts =
        tasks
            .map(
              (t) =>
                  '${t.id}:${t.status}:${t.dueDate?.toIso8601String()}'
                  ':${t.deletedAt != null}',
            )
            .toList()
          ..sort();
    return '$enabled|${parts.join(',')}';
  }

  void _onChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _debounceTimer = null;
      unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    final settings = _ref.read(reminderSettingsProvider);

    // Do nothing until the stored preference has actually been read. Acting on
    // the default before load would cancel a signed-in user's reminders for a
    // moment on every launch, which is visible as reminders that sometimes
    // just do not arrive.
    if (!settings.loaded) return;

    final tasks = _ref.read(taskListProvider).tasks;
    final signature = _signatureFor(tasks, settings.enabled);
    if (signature == _lastSignature) return;

    // Serialise: a second change arriving mid-sync sets a flag instead of
    // interleaving platform calls, then runs once the current pass finishes.
    if (_syncing) {
      _resyncRequested = true;
      return;
    }
    _syncing = true;

    try {
      final service = _ref.read(notificationServiceProvider);
      await service.initialize();

      if (!settings.enabled) {
        await service.cancelAll();
        _lastSignature = signature;
        return;
      }

      // Ask once per session, and only when reminders are actually wanted, so
      // a user who never turns them on is never prompted. A denial is fine:
      // scheduling then simply has no visible effect, and the app is
      // otherwise unaffected.
      if (!_permissionRequested) {
        _permissionRequested = true;
        await service.requestPermission();
      }

      await service.syncSchedule(
        buildReminderSchedule(tasks, DateTime.now()),
      );
      _lastSignature = signature;
    } catch (error, stack) {
      // Never let a reminder failure break the app. Reminders are an
      // enhancement; tasks, goals and sync must all keep working. Clear the
      // cached signature so the next change retries rather than assuming the
      // device is in the state we wanted.
      _lastSignature = null;
      debugPrint('Reminder sync failed: $error\n$stack');
    } finally {
      _syncing = false;
      if (_resyncRequested) {
        _resyncRequested = false;
        unawaited(_sync());
      }
    }
  }

  /// Cancels the pending debounce. Called when the provider is disposed.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

/// Activates reminder syncing. Read this once at app start to create it.
final reminderSyncProvider = Provider<ReminderSyncController>((ref) {
  final controller = ReminderSyncController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
