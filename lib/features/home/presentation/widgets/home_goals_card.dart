import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';

/// Dashboard card summarizing goal progress.
class HomeGoalsCard extends ConsumerWidget {
  const HomeGoalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalListProvider);
    final active = state.goals
        .where((g) => g.status == GoalStatus.active)
        .toList();

    return DashboardCard(
      icon: Icons.flag_outlined,
      title: 'Goals',
      trailing: active.isNotEmpty
          ? Text(
              '${active.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      onTap: () => context.push(AppRoutes.goals),
      child: active.isEmpty
          ? EmptyStateWidget(
              icon: Icons.track_changes_rounded,
              title: 'No goal set.',
              subtitle: 'Start by creating one. Small steps, big change.',
              compact: true,
              actionLabel: 'Set a goal',
              onAction: () => context.push(AppRoutes.goals),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final goal in active.take(2)) ...[
                  Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _goalProgress(ref, goal),
                      minHeight: 4,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (active.length > 2)
                  Text(
                    '+${active.length - 2} more',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Derived progress if the goal has linked tasks, else manual progress.
  double _goalProgress(WidgetRef ref, Goal goal) {
    final linkedCount = ref.watch(goalTaskCountProvider(goal.id));
    return linkedCount > 0
        ? ref.watch(goalProgressProvider(goal.id))
        : goal.progress;
  }
}
