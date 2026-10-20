import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';

/// Today's tasks card: watches [todayTasksProvider].
///
/// Shows tasks due today (or overdue, or with no due date) that are
/// still outstanding. This mirrors exactly what the Tasks list shows
/// under its "Today" section, so the dashboard and task list never
/// disagree about what counts as "today".
class HomeTodayTasksCard extends ConsumerWidget {
  const HomeTodayTasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = ref.watch(todayTasksProvider);

    if (todayTasks.isEmpty) {
      return DashboardCard(
        icon: Icons.auto_awesome_outlined,
        title: "Today's Tasks",
        onTap: () => context.go(AppRoutes.tasks),
        child: _buildTodayEmptyState(context, ref),
      );
    }

    // Completion ratio must include today's tasks that are already
    // completed, so it uses a separate all-inclusive provider rather
    // than `todayTasks` (which excludes completed tasks by design).
    final todayIncludingCompleted = ref.watch(
      todayTasksIncludingCompletedProvider,
    );
    final completed = todayIncludingCompleted
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final completionPct = todayIncludingCompleted.isEmpty
        ? 0.0
        : completed / todayIncludingCompleted.length;

    return DashboardCard(
      icon: Icons.auto_awesome_outlined,
      title: "Today's Tasks",
      trailing: Text(
        '${todayTasks.length}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go(AppRoutes.tasks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...todayTasks.take(3).map((task) => HomeTaskSummaryItem(task: task)),
          if (todayTasks.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '+${todayTasks.length - 3} more',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: completionPct,
              minHeight: 4,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the empty-state content for when there are no outstanding
  /// tasks due today.
  ///
  /// There are three distinct situations that all land here, and each
  /// deserves different copy so the dashboard never tells an existing
  /// user "no tasks scheduled" when they actually have tasks:
  ///
  /// 1. A brand-new user with no tasks at all: invite them to create one.
  /// 2. A user who has completed everything due today: celebrate it.
  /// 3. A user with tasks, but none due today: reassure them they're
  ///    caught up (and mention what's coming up, if anything).
  Widget _buildTodayEmptyState(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(taskListProvider).tasks;
    // Because this is only reached when `todayTasksProvider` is empty,
    // every task in `todayInclCompleted` is necessarily completed.
    final todayInclCompleted = ref.watch(todayTasksIncludingCompletedProvider);
    final upcoming = ref.watch(upcomingTasksProvider);

    if (allTasks.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.task_alt_rounded,
        title: 'No tasks scheduled.',
        subtitle: 'Perfect day to plan something meaningful.',
        compact: true,
        actionLabel: 'Create first task',
        onAction: () => _showTaskEditor(context, ref),
      );
    }

    if (todayInclCompleted.isNotEmpty) {
      final subtitle = upcoming.isEmpty
          ? "You've completed everything due today."
          : "You've completed everything due today. "
                '${upcoming.length} coming up.';
      return EmptyStateWidget(
        icon: Icons.celebration_rounded,
        title: 'All done for today \u{1F389}',
        subtitle: subtitle,
        compact: true,
        actionLabel: 'View tasks',
        onAction: () => context.go(AppRoutes.tasks),
      );
    }

    final subtitle = upcoming.isEmpty
        ? "You're all caught up."
        : 'You have ${upcoming.length} upcoming '
              '${upcoming.length == 1 ? 'task' : 'tasks'}.';
    return EmptyStateWidget(
      icon: Icons.event_available_rounded,
      title: 'Nothing due today',
      subtitle: subtitle,
      compact: true,
      actionLabel: 'View all tasks',
      onAction: () => context.go(AppRoutes.tasks),
    );
  }

  Future<void> _showTaskEditor(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authProvider);
    final userId = authState.userId;
    if (userId == null) return;

    final result = await TaskEditorSheet.show(context);
    if (result == null) return;

    await ref
        .read(taskListProvider.notifier)
        .createTask(result.copyWith(userId: userId));
  }
}

class HomeTaskSummaryItem extends StatelessWidget {
  const HomeTaskSummaryItem({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: isCompleted
                ? AppColors.success
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              task.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: isCompleted
                    ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
