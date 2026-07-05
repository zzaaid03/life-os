/// Home screen — the main dashboard.
///
/// Displays a personalized greeting, quick actions grid,
/// and dashboard cards for Tasks, Habits, Goals, and Journal.
/// The Tasks card shows live data from the task provider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:life_os/features/tasks/presentation/widgets/task_editor_sheet.dart';
import 'package:life_os/shared/widgets/animated_greeting.dart';
import 'package:life_os/shared/widgets/coming_soon_dialog.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';
import 'package:life_os/shared/widgets/empty_state_widget.dart';
import 'package:life_os/shared/widgets/quick_action_button.dart';
import 'package:life_os/shared/widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final displayName =
        profileState.profile?.displayName ?? authState.displayName ?? 'there';

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          AnimatedGreeting(displayName: displayName),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Quick Actions'),
          const _QuickActionsGrid()
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 300.ms),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Focus for Today'),
          const _TodayTasksCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 400.ms),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
                icon: Icons.repeat_rounded,
                title: 'Habits',
                onTap: () => _showComingSoon(context, 'Habits'),
                child: EmptyStateWidget(
                  icon: Icons.favorite_outline_rounded,
                  title: 'No habits yet.',
                  subtitle: "You're one habit away from changing your life.",
                  compact: true,
                  actionLabel: 'Build a habit',
                  onAction: () => _showComingSoon(context, 'Habits'),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 500.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 500.ms),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
                icon: Icons.flag_outlined,
                title: 'Goal of the Week',
                onTap: () => _showComingSoon(context, 'Goals'),
                child: EmptyStateWidget(
                  icon: Icons.track_changes_rounded,
                  title: 'No goal set.',
                  subtitle: 'Start by creating one. Small steps, big change.',
                  compact: true,
                  actionLabel: 'Set a goal',
                  onAction: () => _showComingSoon(context, 'Goals'),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 600.ms),
          const SizedBox(height: AppSpacing.md),
          DashboardCard(
                icon: Icons.book_outlined,
                title: 'Journal',
                onTap: () => _showComingSoon(context, 'Journal'),
                child: EmptyStateWidget(
                  icon: Icons.edit_note_rounded,
                  title: 'No journal entry today.',
                  subtitle: "Capture today's thoughts.",
                  compact: true,
                  actionLabel: 'Write',
                  onAction: () => _showComingSoon(context, 'Journal'),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 700.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 700.ms),
          const SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ComingSoonDialog.show(
      context,
      title: feature,
      message:
          '$feature are coming soon. This is where you\'ll manage '
          'your $feature.',
    );
  }
}

/// Today's tasks card — watches [activeTasksProvider] directly.
///
/// Shows all active (non-completed, non-archived) tasks regardless
/// of due date, so newly created tasks always appear on the dashboard.
class _TodayTasksCard extends ConsumerWidget {
  const _TodayTasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTasks = ref.watch(activeTasksProvider);

    if (activeTasks.isEmpty) {
      return DashboardCard(
        icon: Icons.auto_awesome_outlined,
        title: "Today's Tasks",
        onTap: () => context.go(AppRoutes.tasks),
        child: EmptyStateWidget(
          icon: Icons.task_alt_rounded,
          title: 'No tasks scheduled.',
          subtitle: 'Perfect day to plan something meaningful.',
          compact: true,
          actionLabel: 'Create first task',
          onAction: () => _showTaskEditor(context, ref),
        ),
      );
    }

    final completed = activeTasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final completionPct = completed / activeTasks.length;

    return DashboardCard(
      icon: Icons.auto_awesome_outlined,
      title: "Today's Tasks",
      trailing: Text(
        '${activeTasks.length}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => context.go(AppRoutes.tasks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...activeTasks.take(3).map((task) => _TaskSummaryItem(task: task)),
          if (activeTasks.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '+${activeTasks.length - 3} more',
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
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
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

class _TaskSummaryItem extends StatelessWidget {
  const _TaskSummaryItem({required this.task});
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

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionButton(
            icon: AppIcons.add,
            label: 'New Task',
            onPressed: () => context.go(AppRoutes.tasks),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.edit_note_rounded,
            label: 'New Note',
            onPressed: () => ComingSoonDialog.show(
              context,
              title: 'New Note',
              message: 'Note creation is coming soon.',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.repeat_rounded,
            label: 'New Habit',
            onPressed: () => ComingSoonDialog.show(
              context,
              title: 'New Habit',
              message: 'Habit creation is coming soon.',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: QuickActionButton(
            icon: Icons.flag_outlined,
            label: 'New Goal',
            onPressed: () => ComingSoonDialog.show(
              context,
              title: 'New Goal',
              message: 'Goal creation is coming soon.',
            ),
          ),
        ),
      ],
    );
  }
}
