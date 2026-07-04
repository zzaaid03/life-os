/// Task empty state widget.
///
/// Shows warm, encouraging empty states specific to task sections.
library;

import 'package:flutter/material.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';

/// The type of task section for empty state messaging.
enum TaskEmptyType { today, upcoming, completed }

/// A task-specific empty state.
class TaskEmptyState extends StatelessWidget {
  /// Creates a [TaskEmptyState].
  const TaskEmptyState({super.key, required this.type});

  /// Which section this empty state is for.
  final TaskEmptyType type;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = _copy(type);

    return EmptyStateWidget(
      icon: icon,
      title: title,
      subtitle: subtitle,
      compact: true,
    );
  }

  (IconData, String, String) _copy(TaskEmptyType t) {
    return switch (t) {
      TaskEmptyType.today => (
        Icons.task_alt_rounded,
        'No tasks scheduled.',
        'Perfect day to plan something meaningful.',
      ),
      TaskEmptyType.upcoming => (
        Icons.calendar_month_rounded,
        'Nothing upcoming.',
        'Your future is wide open.',
      ),
      TaskEmptyType.completed => (
        Icons.check_circle_outline_rounded,
        'Nothing completed yet.',
        'Complete your first task.',
      ),
    };
  }
}
