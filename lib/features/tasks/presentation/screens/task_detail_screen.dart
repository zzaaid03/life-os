/// Task detail screen.
///
/// Shows full details of a single task with edit, complete,
/// and delete actions. Includes placeholder sections for
/// future features (subtasks, attachments, comments, AI).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskListProvider);
    final task = taskState.tasks.where((t) => t.id == taskId).firstOrNull;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }

    final isCompleted = task.status == TaskStatus.completed;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: () => _editTask(context, ref, task),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, task),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              task.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Status + Priority
            Row(
              children: [
                _StatusBadge(status: task.status),
                const SizedBox(width: AppSpacing.sm),
                TaskPriorityChip(priority: task.priority),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Description
            if (task.description != null && task.description!.isNotEmpty) ...[
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                task.description!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Due date
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Due Date',
              value: task.dueDate != null
                  ? '${task.dueDate!.month}/${task.dueDate!.day}/${task.dueDate!.year}'
                  : 'No date',
            ),
            const SizedBox(height: AppSpacing.md),

            // Completed
            if (task.completedAt != null)
              _DetailRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed',
                value:
                    '${task.completedAt!.month}/${task.completedAt!.day}/${task.completedAt!.year}',
              ),

            // Timestamps
            const SizedBox(height: AppSpacing.xl),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Created',
              value: _formatDateTime(task.createdAt),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.update_rounded,
              label: 'Updated',
              value: _formatDateTime(task.updatedAt),
            ),

            // Future placeholders
            const SizedBox(height: AppSpacing.xxxl),
            const _PlaceholderSection(
              icon: Icons.list_rounded,
              title: 'Subtasks',
            ),
            const _PlaceholderSection(
              icon: Icons.attach_file_rounded,
              title: 'Attachments',
            ),
            const _PlaceholderSection(
              icon: Icons.comment_outlined,
              title: 'Comments',
            ),
            const _PlaceholderSection(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Assistant',
            ),

            const SizedBox(height: AppSpacing.massive),

            // Complete / Uncomplete button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(taskListProvider.notifier).completeTask(task.id),
                icon: Icon(
                  isCompleted ? Icons.undo_rounded : Icons.check_rounded,
                ),
                label: Text(
                  isCompleted ? 'Mark as Incomplete' : 'Mark as Complete',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, Task task) async {
    final result = await TaskEditorSheet.show(context, task: task);
    if (result == null) return;
    await ref.read(taskListProvider.notifier).updateTask(result);
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
              if (context.mounted) context.go('/tasks');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.pending => ('Pending', AppColors.warning),
      TaskStatus.inProgress => ('In Progress', AppColors.info),
      TaskStatus.completed => ('Completed', AppColors.success),
      TaskStatus.archived => ('Archived', AppColors.textSecondaryLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Coming Soon',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
