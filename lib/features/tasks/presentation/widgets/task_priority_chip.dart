/// Task priority chip.
///
/// A small colored chip showing the priority level of a task.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// A compact chip displaying a task's priority.
class TaskPriorityChip extends StatelessWidget {
  /// Creates a [TaskPriorityChip].
  const TaskPriorityChip({super.key, required this.priority});

  /// The priority to display.
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority == TaskPriority.none) return const SizedBox.shrink();

    final (label, color) = _style(priority);

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

  (String, Color) _style(TaskPriority p) {
    return switch (p) {
      TaskPriority.high => ('High', AppColors.error),
      TaskPriority.medium => ('Medium', AppColors.warning),
      TaskPriority.low => ('Low', AppColors.info),
      TaskPriority.none => ('', AppColors.info),
    };
  }
}
