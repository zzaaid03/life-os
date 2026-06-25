/// Design system color tokens for Life OS.
///
/// Inspired by Apple's modern design language:
/// minimal, premium, with soft, calm aesthetics.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // --- Primary Palette ---

  /// Primary brand color — a calm, premium blue.
  static const Color primary = Color(0xFF007AFF);

  /// Lighter variant for backgrounds and subtle accents.
  static const Color primaryLight = Color(0xFFE8F2FF);

  /// Darker variant for pressed states and emphasis.
  static const Color primaryDark = Color(0xFF0056CC);

  // --- Neutrals ---

  /// Pure white.
  static const Color white = Color(0xFFFFFFFF);

  /// Near-white for card backgrounds in light mode.
  static const Color backgroundLight = Color(0xFFF5F5F7);

  /// Near-black for card backgrounds in dark mode.
  static const Color backgroundDark = Color(0xFF1C1C1E);

  /// Surface color for elevated elements in light mode.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Surface color for elevated elements in dark mode.
  static const Color surfaceDark = Color(0xFF2C2C2E);

  // --- Text ---

  /// Primary text in light mode.
  static const Color textPrimaryLight = Color(0xFF1C1C1E);

  /// Secondary text in light mode.
  static const Color textSecondaryLight = Color(0xFF8E8E93);

  /// Primary text in dark mode.
  static const Color textPrimaryDark = Color(0xFFF5F5F7);

  /// Secondary text in dark mode.
  static const Color textSecondaryDark = Color(0xFF98989D);

  // --- Semantic ---

  /// Success state color.
  static const Color success = Color(0xFF34C759);

  /// Warning state color.
  static const Color warning = Color(0xFFFF9500);

  /// Error / destructive action color.
  static const Color error = Color(0xFFFF3B30);

  /// Informational state color.
  static const Color info = Color(0xFF5AC8FA);

  // --- Misc ---

  /// Subtle divider and border color.
  static const Color divider = Color(0xFFE5E5EA);

  /// Shadow color with low opacity for soft elevation.
  static Color shadow = Colors.black.withValues(alpha: 0.04);

  /// Overlay color for modals and sheets.
  static Color overlay = Colors.black.withValues(alpha: 0.4);
}
