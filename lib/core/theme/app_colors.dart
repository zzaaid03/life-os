/// Design system color tokens for Life OS.
///
/// Inspired by Things 3, Linear, and Notion:
/// warm off-whites, softer neutrals, muted accents.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // --- Primary Palette ---

  /// Primary accent — a muted, warm indigo (less saturated than pure blue).
  static const Color primary = Color(0xFF5B5FC7);

  /// Soft tint for backgrounds and subtle accents.
  static const Color primaryLight = Color(0xFFEEF0FA);

  /// Darker variant for pressed states.
  static const Color primaryDark = Color(0xFF3D40A0);

  // --- Neutrals (warm) ---

  /// Pure white.
  static const Color white = Color(0xFFFFFFFF);

  /// Warm off-white for screen backgrounds in light mode.
  static const Color backgroundLight = Color(0xFFFAF9F7);

  /// Deep warm charcoal for dark mode backgrounds.
  static const Color backgroundDark = Color(0xFF1A1A1C);

  /// Warm white surface for cards in light mode.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Elevated surface for dark mode.
  static const Color surfaceDark = Color(0xFF28282B);

  // --- Text ---

  /// Primary text in light mode — warm near-black.
  static const Color textPrimaryLight = Color(0xFF1D1D1F);

  /// Secondary text in light mode — warm gray.
  static const Color textSecondaryLight = Color(0xFF86868B);

  /// Primary text in dark mode.
  static const Color textPrimaryDark = Color(0xFFF2F2F4);

  /// Secondary text in dark mode.
  static const Color textSecondaryDark = Color(0xFF9A9A9E);

  // --- Semantic (muted) ---

  /// Success — softer green.
  static const Color success = Color(0xFF30B565);

  /// Warning — warm amber.
  static const Color warning = Color(0xFFE89B3C);

  /// Error — muted coral.
  static const Color error = Color(0xFFE5484D);

  /// Info — soft blue.
  static const Color info = Color(0xFF5BA8E8);

  // --- Misc ---

  /// Subtle warm divider.
  static const Color divider = Color(0xFFE8E6E2);

  /// Soft shadow.
  static Color shadow = Colors.black.withValues(alpha: 0.03);

  /// Overlay for modals.
  static Color overlay = Colors.black.withValues(alpha: 0.35);
}
