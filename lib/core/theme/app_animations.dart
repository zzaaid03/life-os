/// Design system animation presets for Life OS.
///
/// Pre-configured animation effects for consistent,
/// smooth motion throughout the application.
library;

import 'package:flutter/material.dart';

abstract final class AppAnimations {
  AppAnimations._();

  /// Fast animation duration — for micro-interactions.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard animation duration — for most transitions.
  static const Duration standard = Duration(milliseconds: 250);

  /// Slow animation duration — for emphasis and reveals.
  static const Duration slow = Duration(milliseconds: 350);

  /// Page transition duration.
  static const Duration pageTransition = Duration(milliseconds: 300);

  /// Default animation curve — smooth and natural.
  static const Curve defaultCurve = Curves.easeInOut;

  /// Deceleration curve — for elements coming to rest.
  static const Curve decelerate = Curves.easeOut;

  /// Acceleration curve — for elements entering.
  static const Curve accelerate = Curves.easeIn;

  /// Spring curve — for bouncy, playful interactions.
  static const Curve spring = Curves.elasticOut;

  /// Standard page transition.
  static SlideTransition pageSlideTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: defaultCurve)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
