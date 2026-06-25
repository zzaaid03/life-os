/// Design system spacing and sizing tokens for Life OS.
///
/// All spacing values follow an 8-point grid system
/// for consistent visual rhythm throughout the application.
library;

import 'package:flutter/material.dart';

abstract final class AppSpacing {
  AppSpacing._();

  /// 2.0 logical pixels.
  static const double xxs = 2.0;

  /// 4.0 logical pixels.
  static const double xs = 4.0;

  /// 8.0 logical pixels — base unit.
  static const double sm = 8.0;

  /// 12.0 logical pixels.
  static const double md = 12.0;

  /// 16.0 logical pixels.
  static const double lg = 16.0;

  /// 20.0 logical pixels.
  static const double xl = 20.0;

  /// 24.0 logical pixels.
  static const double xxl = 24.0;

  /// 32.0 logical pixels.
  static const double xxxl = 32.0;

  /// 40.0 logical pixels.
  static const double huge = 40.0;

  /// 48.0 logical pixels.
  static const double massive = 48.0;

  /// Standard horizontal screen padding.
  static const double screenHorizontal = 20.0;

  /// Standard vertical screen padding.
  static const double screenVertical = 16.0;

  /// Standard card padding.
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Standard content padding within screens.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );

  /// Standard section spacing.
  static const double sectionSpacing = xxxl;

  /// Standard item spacing within lists.
  static const double itemSpacing = sm;
}
