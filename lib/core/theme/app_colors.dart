/// Design system color tokens for Life OS.
///
/// The "Evergreen" palette: a balanced teal-green identity inspired
/// by Things 3, Linear, and Notion — warm off-whites, softer neutrals,
/// and a muted, natural accent color instead of a generic saturated blue.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // --- Primary Palette (Evergreen) ---

  /// Primary accent — a balanced teal-green.
  static const Color primary = Color(0xFF1E9E82);

  /// Darker variant for pressed states (light theme), and used as the
  /// `primaryContainer` shade in dark theme.
  static const Color primaryDark = Color(0xFF17806A);

  /// Soft tint for backgrounds and subtle accents.
  static const Color primaryLight = Color(0xFFE6F4EF);

  /// Brightened primary used specifically against dark surfaces, where
  /// [primary] alone would not have enough contrast to stay legible.
  static const Color primaryOnDark = Color(0xFF33B89B);

  // --- Neutrals (warm) ---

  /// Pure white.
  static const Color white = Color(0xFFFFFFFF);

  /// Warm off-white for screen backgrounds in light mode.
  static const Color backgroundLight = Color(0xFFF7F6F2);

  /// Deep, calm green-black for dark mode backgrounds.
  static const Color backgroundDark = Color(0xFF121916);

  /// Warm white surface for cards in light mode.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Elevated surface for dark mode.
  static const Color surfaceDark = Color(0xFF1B241F);

  // --- Text ---

  /// Primary text in light mode.
  static const Color textPrimaryLight = Color(0xFF16211D);

  /// Secondary text in light mode.
  static const Color textSecondaryLight = Color(0xFF6B7772);

  /// Primary text in dark mode.
  static const Color textPrimaryDark = Color(0xFFECF2EF);

  /// Secondary text in dark mode.
  static const Color textSecondaryDark = Color(0xFF93A099);

  // --- Semantic (muted) ---

  /// Success — soft green.
  static const Color success = Color(0xFF2FAF6A);

  /// Warning — warm amber.
  static const Color warning = Color(0xFFE8A13C);

  /// Error — muted coral-red.
  static const Color error = Color(0xFFE5544E);

  /// Info — soft blue.
  static const Color info = Color(0xFF3E9BD6);

  // --- Misc ---

  /// Subtle warm divider.
  static const Color divider = Color(0xFFE7E5DF);

  /// Soft shadow.
  static Color shadow = Colors.black.withValues(alpha: 0.03);

  /// Overlay for modals.
  static Color overlay = Colors.black.withValues(alpha: 0.35);
}
