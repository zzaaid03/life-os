/// Theme mode setting (System / Light / Dark).
///
/// Persisted via SharedPreferences and consumed by `MaterialApp.themeMode`
/// so the choice survives restarts on every platform.
library;

import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the persisted theme mode.
const String _kThemeModeKey = 'theme_mode';

/// Loads and persists the app-wide [ThemeMode].
class ThemeModeController extends StateNotifier<ThemeMode> {
  /// Creates a [ThemeModeController] and eagerly loads the stored value.
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kThemeModeKey);
      state = switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Fall back to following the system on any storage failure.
      state = ThemeMode.system;
    }
  }

  /// Sets and persists the theme mode.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, mode.name);
    } catch (_) {
      // In-memory value still applies for this session.
    }
  }

  /// A human-readable label for the current mode.
  static String label(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }
}

/// The app-wide theme mode.
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    return ThemeModeController();
  },
);
