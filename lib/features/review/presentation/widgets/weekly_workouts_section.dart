/// The "Workouts" block of the weekly review.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/review/domain/providers/weekly_workouts_provider.dart';
import 'package:life_os/features/review/domain/weekly_workouts.dart';

/// Sessions, sets and new personal bests of the reviewed week. Hidden when the
/// week had no sessions.
class WeeklyWorkoutsSection extends ConsumerWidget {
  /// Creates a [WeeklyWorkoutsSection].
  const WeeklyWorkoutsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(weeklyWorkoutsProvider);
    final units = ref.watch(calorieProfileProvider).profile.units;
    final theme = Theme.of(context);

    final Widget body;
    if (workouts.hasError) {
      body = _Card(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not load your workouts.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(weeklyWorkoutsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (!workouts.hasValue) {
      body = const _Card(
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else {
      final data = workouts.requireValue;
      if (data.sessionCount == 0) return const SizedBox.shrink();
      final label = data.sessionCount == 1 ? 'workout' : 'workouts';
      final sets = data.setCount == 1 ? 'set' : 'sets';
      body = _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data.sessionCount} $label, ${data.setCount} $sets',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (data.personalBests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'New personal bests',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              for (final pb in data.personalBests)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    describePersonalBest(pb, units),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workouts',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        body,
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}
