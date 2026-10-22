/// Fitness hub: the daily calorie target and BMI at a glance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/number_format.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';
import 'package:life_os/features/nutrition/presentation/bmi_card.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';

/// Shows the daily calorie target and BMI. Nutrition owns the logic, this
/// screen only displays it.
class FitnessHubScreen extends ConsumerWidget {
  /// Creates a [FitnessHubScreen].
  const FitnessHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calorieProfileProvider);
    final Widget body;
    if (!state.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.loadFailed) {
      body = Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Couldn't load your details.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () =>
                    ref.read(calorieProfileProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = _HubBody(profile: state.profile);
    }
    return Scaffold(appBar: AppBar(title: const Text('Fitness')), body: body);
  }
}

class _HubBody extends ConsumerWidget {
  const _HubBody({required this.profile});

  final CalorieProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final target = ref.watch(dailyTargetProvider);
    final weight = profile.weightKg;
    final height = profile.heightCm;
    final birthYear = profile.birthYear;
    final showBmi = weight != null &&
        height != null &&
        isValidWeightKg(weight) &&
        isValidHeightCm(height);

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        DashboardCard(
          icon: Icons.local_fire_department_outlined,
          title: 'Daily calories',
          onTap: () => context.push(AppRoutes.calorieTarget),
          child: target == null
              ? Row(
                  children: [
                    Expanded(
                      child: Text('Not set', style: theme.textTheme.titleMedium),
                    ),
                    FilledButton(
                      onPressed: () => context.push(AppRoutes.calorieTarget),
                      child: const Text('Set your target'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatThousands(target)} kcal a day',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.calorieTarget),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
        ),
        if (showBmi) ...[
          const SizedBox(height: AppSpacing.md),
          BmiCard(
            weightKg: weight,
            heightCm: height,
            age: birthYear == null
                ? null
                : ageFromBirthYear(birthYear, DateTime.now()),
            units: profile.units,
          ),
        ],
      ],
    );
  }
}
