/// Timeline screen — unified chronological feed of life events.
///
/// Aggregates created/completed tasks, notes, habit check-offs, goal
/// updates, and job-application changes (via [timelineEventsProvider]),
/// grouped by day with a type-specific icon per event.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/timeline/domain/timeline_provider.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(timelineEventsProvider);
    final groups = _groupByDay(events);

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Timeline',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (events.isEmpty)
            const Center(
              child: EmptyStateWidget(
                icon: Icons.timeline_rounded,
                title: 'Your journey begins today.',
                subtitle:
                    'Tasks, notes, habits, goals, and job updates will '
                    'appear here.',
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms)
          else
            for (final group in groups) ...[
              _DayHeader(date: group.$1)
                  .animate()
                  .fadeIn(duration: 300.ms),
              ...group.$2.map(
                (event) => _TimelineTile(event: event)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.04, end: 0, duration: 300.ms),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          const SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }

  /// Groups events by calendar day, newest day first (events are already
  /// sorted newest-first).
  List<(DateTime, List<TimelineEvent>)> _groupByDay(
    List<TimelineEvent> events,
  ) {
    final groups = <(DateTime, List<TimelineEvent>)>[];
    for (final event in events) {
      final day = DateTime(
        event.timestamp.year,
        event.timestamp.month,
        event.timestamp.day,
      );
      if (groups.isNotEmpty && groups.last.$1 == day) {
        groups.last.$2.add(event);
      } else {
        groups.add((day, [event]));
      }
    }
    return groups;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        _label(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${months[date.month - 1]} ${date.day}';
    return date.year == now.year ? label : '$label, ${date.year}';
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final TimelineEvent event;

  Color _color(ThemeData theme) => switch (event.type) {
    TimelineEventType.taskCreated => theme.colorScheme.primary,
    TimelineEventType.taskCompleted => AppColors.success,
    TimelineEventType.noteCreated => AppColors.info,
    TimelineEventType.habitCheckedOff => AppColors.warning,
    TimelineEventType.goalUpdated => theme.colorScheme.primary,
    TimelineEventType.jobStatusChanged => AppColors.info,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(event.icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  event.subtitle == null
                      ? event.label
                      : '${event.label} · ${event.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
