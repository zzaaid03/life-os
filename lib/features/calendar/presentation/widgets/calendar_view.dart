/// Month calendar view for the Timeline screen.
///
/// Shows a swipeable month grid (Apple-Calendar-like) where each day cell
/// lists the titles of the tasks due that day and days with tasks are
/// tinted, plus a list of the selected day's full tasks below the grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_due_date_badge.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_priority_chip.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _focusedDay = today;
    _selectedDay = DateTime(today.year, today.month, today.day);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<Task>> _tasksByDay(List<Task> tasks) {
    final map = <DateTime, List<Task>>{};
    for (final t in tasks) {
      if (t.dueDate == null) continue;
      final d = t.dueDate!.toLocal();
      final key = DateTime(d.year, d.month, d.day);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  /// Shared day-cell renderer used by every [CalendarBuilders] slot.
  Widget _dayCell(
    ThemeData theme,
    DateTime day,
    List<Task> dayTasks, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final hasTasks = dayTasks.isNotEmpty;

    final Color? background = isOutside
        ? null
        : isSelected
        ? primary.withValues(alpha: 0.25)
        : hasTasks
        ? primary.withValues(alpha: 0.12)
        : null;

    Border? border;
    if (isSelected) {
      border = Border.all(color: primary, width: 1.5);
    } else if (isToday && !isOutside) {
      border = Border.all(color: primary.withValues(alpha: 0.5));
    }

    final numberColor = isOutside
        ? onSurface.withValues(alpha: 0.25)
        : isToday || isSelected
        ? primary
        : onSurface;
    final titleColor = onSurface.withValues(alpha: isOutside ? 0.3 : 0.75);

    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: isToday || isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: numberColor,
            ),
          ),
          if (hasTasks) ...[
            const SizedBox(height: 3),
            for (final task in dayTasks.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.15,
                    color: titleColor,
                  ),
                ),
              ),
            if (dayTasks.length > 2)
              Text(
                '+${dayTasks.length - 2}',
                style: TextStyle(
                  fontSize: 8,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: isOutside ? 0.3 : 0.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(taskListProvider).tasks;
    final tasksByDay = _tasksByDay(tasks);
    final selectedTasks = tasksByDay[_dateOnly(_selectedDay)] ?? const <Task>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TableCalendar<Task>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focusedDay,
          currentDay: DateTime.now(),
          calendarFormat: CalendarFormat.month,
          availableGestures: AvailableGestures.horizontalSwipe,
          rowHeight: 82,
          daysOfWeekHeight: 22,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontWeight: FontWeight.w600,
            ),
          ),
          // Day states (today / selected / tinted) are drawn entirely by
          // [calendarBuilders] below, so no decorations live here.
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders<Task>(
            defaultBuilder: (context, day, focusedDay) => _dayCell(
              theme,
              day,
              tasksByDay[_dateOnly(day)] ?? const <Task>[],
            ),
            todayBuilder: (context, day, focusedDay) => _dayCell(
              theme,
              day,
              tasksByDay[_dateOnly(day)] ?? const <Task>[],
              isToday: true,
            ),
            selectedBuilder: (context, day, focusedDay) => _dayCell(
              theme,
              day,
              tasksByDay[_dateOnly(day)] ?? const <Task>[],
              isSelected: true,
              isToday: isSameDay(day, DateTime.now()),
            ),
            outsideBuilder: (context, day, focusedDay) => _dayCell(
              theme,
              day,
              tasksByDay[_dateOnly(day)] ?? const <Task>[],
              isOutside: true,
            ),
          ),
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onPageChanged: (focused) {
            _focusedDay = focused;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (selectedTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'No tasks due',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          )
        else
          for (final task in selectedTasks) _SelectedDayTaskRow(task: task),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _SelectedDayTaskRow extends StatelessWidget {
  const _SelectedDayTaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: isCompleted
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
    );
  }
}
