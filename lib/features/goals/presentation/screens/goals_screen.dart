/// Goals screen.
///
/// Lists the user's goals with progress bars. Supports create, tap-to-edit
/// (including a progress slider), and swipe-to-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/widgets/error_snackbar.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/goals/presentation/widgets/goal_editor_dialog.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';

/// Screen listing the user's goals.
class GoalsScreen extends ConsumerWidget {
  /// Creates a [GoalsScreen].
  const GoalsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Goal goal) async {
    final hasLinkedTasks = ref.read(goalTaskCountProvider(goal.id)) > 0;
    final result = await GoalEditorDialog.show(
      context,
      existing: goal,
      progressDisabled: hasLinkedTasks,
    );
    if (result == null) return;
    if (result.delete) {
      if (!context.mounted) return;
      await _deleteWithConfirm(context, ref, goal);
      return;
    }
    await ref
        .read(goalListProvider.notifier)
        .updateGoal(
          goal.copyWith(
            title: result.title,
            description: result.description,
            progress: hasLinkedTasks ? goal.progress : result.progress,
            targetDate: result.targetDate,
            status: hasLinkedTasks
                ? goal.status
                : (result.progress >= 1.0
                      ? GoalStatus.completed
                      : GoalStatus.active),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalListProvider);
    listenForRefreshError(ref, context, goalListProvider.select((s) => s.status == GoalListStatus.loaded ? s.error : null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New goal',
            onPressed: () => context.push(AppRoutes.goalBreakdown),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(goalListProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GoalListState state) {
    final theme = Theme.of(context);

    if (state.status == GoalListStatus.loading && state.goals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.goals.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl * 2),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No goals yet.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Small steps, big change. Set one with +.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      itemCount: state.goals.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final goal = state.goals[index];
        return Dismissible(
          key: ValueKey(goal.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
          ),
          confirmDismiss: (_) => _confirmDelete(context, ref, goal),
          onDismissed: (_) async {
            try {
              await ref.read(goalListProvider.notifier).deleteGoal(goal.id);
              await ref.read(taskListProvider.notifier).refresh();
            } catch (_) {
              await ref.read(goalListProvider.notifier).refresh();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Couldn't delete goal. Please try again."),
                ),
              );
            }
          },
          child: _GoalCard(goal: goal, onTap: () => _edit(context, ref, goal)),
        );
      },
    );
  }

  /// Confirms, then deletes [goal] using the same path as swipe-to-delete.
  Future<void> _deleteWithConfirm(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final confirmed = await _confirmDelete(context, ref, goal);
    if (confirmed != true) return;
    try {
      await ref.read(goalListProvider.notifier).deleteGoal(goal.id);
      await ref.read(taskListProvider.notifier).refresh();
    } catch (_) {
      await ref.read(goalListProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't delete goal. Please try again."),
        ),
      );
    }
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) {
    final linkedTaskCount = ref.read(goalTaskCountProvider(goal.id));
    final body = linkedTaskCount > 0
        ? '"${goal.title}" and its $linkedTaskCount linked '
              '${linkedTaskCount == 1 ? 'task' : 'tasks'} will be deleted. '
              "This can't be undone."
        : '"${goal.title}" will be deleted. '
              "This can't be undone.";

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linkedTaskCount = ref.watch(goalTaskCountProvider(goal.id));
    final hasLinkedTasks = linkedTaskCount > 0;
    final progress = hasLinkedTasks
        ? ref.watch(goalProgressProvider(goal.id))
        : goal.progress;
    final isCompleted = hasLinkedTasks
        ? progress >= 1.0
        : goal.status == GoalStatus.completed;
    final pct = (progress * 100).round();

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '$pct%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isCompleted
                          ? AppColors.success
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (goal.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  goal.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    isCompleted ? AppColors.success : theme.colorScheme.primary,
                  ),
                ),
              ),
              if (goal.targetDate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Target: ${formatDay(goal.targetDate!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
