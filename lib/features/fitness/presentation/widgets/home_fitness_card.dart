import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/number_format.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';
import 'package:life_os/shared/widgets/section_header.dart';

/// The home dashboard's fitness block. Always shown so there is a way in.
class HomeFitnessSection extends StatelessWidget {
  const HomeFitnessSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Fitness'),
        SizedBox(height: AppSpacing.md),
        HomeFitnessCard(),
      ],
    );
  }
}

/// A compact dashboard card showing the daily calorie target, tapping
/// through to the fitness hub.
class HomeFitnessCard extends ConsumerWidget {
  const HomeFitnessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calorieProfileProvider);
    final target = ref.watch(dailyTargetProvider);
    final String subtitle;
    if (!state.loaded) {
      subtitle = 'Loading…';
    } else if (state.loadFailed) {
      subtitle = 'Tap to open';
    } else if (target == null) {
      subtitle = 'Set your calorie target';
    } else {
      subtitle = '${formatThousands(target)} kcal a day target';
    }

    return DashboardCard(
      icon: Icons.fitness_center_outlined,
      title: 'Fitness',
      onTap: () => context.push(AppRoutes.fitness),
      child: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
