/// Fitness hub: the next workout, plus the daily calorie target and BMI.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/presentation/widgets/body_row.dart';
import 'package:life_os/features/fitness/presentation/widgets/checkin_card.dart';
import 'package:life_os/features/fitness/presentation/widgets/coach_card.dart';
import 'package:life_os/features/fitness/presentation/widgets/plan_menu_button.dart';

/// The coach's card on top, the BODY row below. Nutrition owns the calorie
/// and BMI logic, this screen only displays it.
class FitnessHubScreen extends StatelessWidget {
  /// Creates a [FitnessHubScreen].
  const FitnessHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness'),
        actions: const [PlanMenuButton()],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: const [
          CheckinCard(),
          SizedBox(height: AppSpacing.sectionSpacing),
          CoachCard(),
          SizedBox(height: AppSpacing.sectionSpacing),
          BodyRow(),
        ],
      ),
    );
  }
}
