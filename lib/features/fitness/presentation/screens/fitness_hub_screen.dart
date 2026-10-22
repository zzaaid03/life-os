/// Fitness hub: the next workout, plus the daily calorie target and BMI.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/presentation/widgets/body_row.dart';
import 'package:life_os/features/fitness/presentation/widgets/coach_card.dart';

/// The coach's card on top, the BODY row below. Nutrition owns the calorie
/// and BMI logic, this screen only displays it.
class FitnessHubScreen extends StatelessWidget {
  /// Creates a [FitnessHubScreen].
  const FitnessHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: const [
          CoachCard(),
          SizedBox(height: AppSpacing.sectionSpacing),
          BodyRow(),
        ],
      ),
    );
  }
}
