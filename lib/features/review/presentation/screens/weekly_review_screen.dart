/// The weekly review screen.
///
/// Placeholder written by the planner so the route and the home pointer can
/// compile before the real screen lands. Replaced wholesale by lane 2.
library;

import 'package:flutter/material.dart';

/// Shows the most recently ended week's review.
class WeeklyReviewScreen extends StatelessWidget {
  /// Creates a [WeeklyReviewScreen].
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your week')),
      body: const SizedBox.shrink(),
    );
  }
}
