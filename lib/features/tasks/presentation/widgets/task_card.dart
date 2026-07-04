/// Task card widget.
///
/// The main list item for tasks. Includes checkbox, title,
/// description preview, priority chip, due date badge,
/// and swipe-to-complete/delete actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_checkbox.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_due_date_badge.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';

/// A premium task list item with swipe actions.
class TaskCard extends StatelessWidget {
  /// Creates a [TaskCard].
  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.onDelete,
  });

  /// The task to display.
  final Task task;

  /// Called when the card is tapped (opens detail).
  final VoidCallback? onTap;

  /// Called when the task is marked complete/incomplete.
  final VoidCallback? onComplete;

  /// Called when the task is deleted.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        context,
        alignment: Alignment.centerLeft,
        color: AppColors.success,
        icon: Icons.check_rounded,
      ),
      secondaryBackground: _swipeBackground(
        context,
        alignment: Alignment.centerRight,
        color: AppColors.error,
        icon: Icons.delete_outline_rounded,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onComplete?.call();
          return false;
        } else {
          onDelete?.call();
          return false;
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TaskCheckbox(
                    value: isCompleted,
                    onChanged: (_) => onComplete?.call(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isCompleted
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.4,
                                )
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          TaskPriorityChip(priority: task.priority),
                          if (task.priority != TaskPriority.none)
                            const SizedBox(width: AppSpacing.sm),
                          TaskDueDateBadge(
                            dueDate: task.dueDate,
                            isCompleted: isCompleted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _swipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
