/// Design system border radius tokens for Life OS.
///
/// Consistent corner radii create a soft, premium feel
/// inspired by Apple's design language.
library;

import 'package:flutter/material.dart';

abstract final class AppRadius {
  AppRadius._();

  /// 4.0 logical pixels — subtle rounding for small elements.
  static const double xs = 4.0;

  /// 8.0 logical pixels — standard rounding for inputs and chips.
  static const double sm = 8.0;

  /// 12.0 logical pixels — default for cards and containers.
  static const double md = 12.0;

  /// 16.0 logical pixels — prominent rounding for large cards.
  static const double lg = 16.0;

  /// 20.0 logical pixels — extra prominent for modals and sheets.
  static const double xl = 20.0;

  /// 24.0 logical pixels — maximum rounding for hero elements.
  static const double xxl = 24.0;

  /// Fully circular (pill-shaped) radius.
  static const double circular = 999.0;

  /// Standard card border radius.
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));

  /// Standard button border radius.
  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));

  /// Standard input field border radius.
  static const BorderRadius input = BorderRadius.all(Radius.circular(sm));

  /// Modal / bottom sheet border radius (top corners only).
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
