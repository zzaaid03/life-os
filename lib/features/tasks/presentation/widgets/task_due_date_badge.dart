/// Task due date badge.
///
/// Shows a task's due date with contextual formatting:
/// - Overdue: red
/// - Today: primary color
/// - Tomorrow: "Tomorrow"
/// - This week: day name
/// - Later: date format
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A compact badge showing when a task is due.
class TaskDueDateBadge extends StatelessWidget {
  /// Creates a [TaskDueDateBadge].
  const TaskDueDateBadge({
    super.key,
    required this.dueDate,
    this.isCompleted = false,
  });

  /// The due date to display.
  final DateTime? dueDate;

  /// Whether the parent task is completed (affects styling).
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (dueDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final diff = due.difference(today).inDays;

    final (label, color) = _format(context, diff, isCompleted);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  (String, Color) _format(BuildContext context, int diffDays, bool completed) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurface.withValues(alpha: 0.45);

    if (completed) {
      return (_dateLabel(diffDays), muted);
    }
    if (diffDays < 0) {
      return ('Overdue', AppColors.error);
    }
    if (diffDays == 0) {
      return ('Today', colorScheme.primary);
    }
    if (diffDays == 1) {
      return ('Tomorrow', colorScheme.primary);
    }
    if (diffDays < 7) {
      return (_dayName(dueDate!), colorScheme.primary);
    }
    return (_dateLabel(diffDays), muted);
  }

  String _dateLabel(int diffDays) {
    final d = dueDate!;
    return '${d.month}/${d.day}';
  }

  String _dayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
