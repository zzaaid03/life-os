/// Per-user "task reminders" on/off preference.
///
/// Persisted locally with SharedPreferences and keyed by user ID, mirroring
/// `onboarding_provider.dart`. This provider only reads and writes the
/// preference. It must never talk to the OS notification APIs directly.
library;

import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State of the current user's task-reminders preference.
class ReminderSettingsState {
  /// Creates a [ReminderSettingsState].
  const ReminderSettingsState({this.userId, this.enabled = true, this.loaded = false});

  /// The user ID this state was loaded for, or null if logged out.
  final String? userId;

  /// Whether task reminders are enabled for this user.
  final bool enabled;

  /// Whether the stored value has finished loading from disk.
  final bool loaded;

  /// Returns a copy with the given fields replaced.
  ReminderSettingsState copyWith({String? userId, bool? enabled, bool? loaded}) {
    return ReminderSettingsState(
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Loads and persists the current user's task-reminders preference.
class ReminderSettingsController extends StateNotifier<ReminderSettingsState> {
  /// Creates a [ReminderSettingsController] with no user loaded yet.
  ReminderSettingsController() : super(const ReminderSettingsState());

  String _keyFor(String userId) => 'reminders_enabled_$userId';

  /// Loads the reminders preference for [userId], or resets to logged-out
  /// state if [userId] is null.
  Future<void> loadFor(String? userId) async {
    if (userId == null) {
      state = const ReminderSettingsState();
      return;
    }

    state = ReminderSettingsState(userId: userId, enabled: true, loaded: false);

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyFor(userId)) ?? true;
      // Guard against the user switching mid-load.
      if (state.userId != userId) return;
      state = ReminderSettingsState(userId: userId, enabled: enabled, loaded: true);
    } catch (_) {
      if (state.userId != userId) return;
      // Default to enabled on any storage failure.
      state = ReminderSettingsState(userId: userId, enabled: true, loaded: true);
    }
  }

  /// Sets the reminders preference for [userId] and persists it.
  Future<void> setEnabled(String userId, bool value) async {
    state = ReminderSettingsState(userId: userId, enabled: value, loaded: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Guard against the user switching mid-write.
      if (state.userId != userId) return;
      await prefs.setBool(_keyFor(userId), value);
    } catch (_) {
      // If persistence fails the in-memory flag still lets the current
      // session proceed; the preference may reset next launch.
    }
  }
}

/// The current user's task-reminders preference (persisted, per-user).
final reminderSettingsProvider =
    StateNotifierProvider<ReminderSettingsController, ReminderSettingsState>((ref) {
      final controller = ReminderSettingsController();
      ref.listen(authProvider, (prev, next) {
        if (prev?.userId != next.userId) controller.loadFor(next.userId);
      }, fireImmediately: true);
      return controller;
    });
