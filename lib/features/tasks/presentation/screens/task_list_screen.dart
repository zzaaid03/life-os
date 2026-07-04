/// Task list screen.
///
/// Displays tasks grouped into Today, Upcoming, and Completed sections.
/// Supports pull-to-refresh, swipe actions, and task creation via FAB.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_card.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_empty_state.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_section.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskListProvider);
    final todayTasks = ref.watch(todayTasksProvider);
    final upcomingTasks = ref.watch(upcomingTasksProvider);
    final completedTasks = ref.watch(completedTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync',
            onPressed: () => ref.read(taskListProvider.notifier).sync(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTask(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
        child: _buildBody(
          context,
          ref,
          taskState,
          todayTasks,
          upcomingTasks,
          completedTasks,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TaskListState taskState,
    List<Task> today,
    List<Task> upcoming,
    List<Task> completed,
  ) {
    if (taskState.status == TaskListStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (taskState.status == TaskListStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(taskState.error ?? 'Something went wrong'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => ref.read(taskListProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (today.isEmpty && upcoming.isEmpty && completed.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl * 2),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No tasks yet.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tap + to create your first task.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      children: [
        // Today
        TaskSection(title: 'Today', count: today.length),
        if (today.isEmpty)
          const TaskEmptyState(type: TaskEmptyType.today)
        else
          ...today.map((t) => _taskItem(context, ref, t)),

        // Upcoming
        TaskSection(title: 'Upcoming', count: upcoming.length),
        if (upcoming.isEmpty)
          const TaskEmptyState(type: TaskEmptyType.upcoming)
        else
          ...upcoming.map((t) => _taskItem(context, ref, t)),

        // Completed
        TaskSection(title: 'Completed', count: completed.length),
        if (completed.isEmpty)
          const TaskEmptyState(type: TaskEmptyType.completed)
        else
          ...completed.map((t) => _taskItem(context, ref, t)),

        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }

  Widget _taskItem(BuildContext context, WidgetRef ref, Task task) {
    return TaskCard(
      task: task,
      onTap: () => context.go('/tasks/${task.id}'),
      onComplete: () =>
          ref.read(taskListProvider.notifier).completeTask(task.id),
      onDelete: () => _confirmDelete(context, ref, task),
    );
  }

  Future<void> _createTask(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authProvider);
    final userId = authState.userId;
    if (userId == null) return;

    final result = await TaskEditorSheet.show(context);
    if (result == null) return;

    await ref
        .read(taskListProvider.notifier)
        .createTask(result.copyWith(userId: userId));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Task task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('"${task.title}" will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(taskListProvider.notifier).deleteTask(task.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
