/// Alerts when a cook timer runs out. Placeholder seam; Lane C2 implements it.
library;

import 'package:flutter/material.dart';

/// Wraps the cook screen. While mounted, listens to
/// `cookTimersProvider.notifier.onFinished` and, for each timer of
/// [recipeTitle] that runs out: plays haptics and an alert sound, shows a
/// prominent alert with "+1 min" and "Done", and calls [onAnnounce] with a
/// short sentence (e.g. "Simmer sauce is done") so the screen can speak it.
class TimerAlertListener extends StatelessWidget {
  /// Creates a [TimerAlertListener].
  const TimerAlertListener({
    super.key,
    required this.recipeTitle,
    required this.child,
    this.onAnnounce,
  });

  /// Only this recipe's timers alert here.
  final String recipeTitle;

  /// The cook screen.
  final Widget child;

  /// Receives a sentence to read aloud, if read-aloud is on.
  final ValueChanged<String>? onAnnounce;

  @override
  Widget build(BuildContext context) => child;
}
