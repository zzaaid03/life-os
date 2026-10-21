/// Small tappable row that shows the daily target and opens the screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/utils/number_format.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';

/// "Daily target: 2,259 kcal", or "Set your daily calories" when unset.
class CalorieTargetChip extends ConsumerWidget {
  /// Creates a [CalorieTargetChip].
  const CalorieTargetChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(dailyTargetProvider);
    return ActionChip(
      avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
      label: Text(
        target == null
            ? 'Set your daily calories'
            : 'Daily target: ${formatThousands(target)} kcal',
      ),
      onPressed: () => context.push(AppRoutes.calorieTarget),
    );
  }
}
