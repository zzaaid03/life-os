/// Home screen — the main dashboard.
///
/// Displays a personalized greeting, quick actions grid,
/// and dashboard cards for Tasks, the Inbox Assistant, Habits, and Goals.
/// The Tasks card shows live data from the task provider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/jobs/domain/providers/job_provider.dart';
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
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Inbox Assistant'),
          const _InboxScanCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 450.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 450.ms),
          const SizedBox(height: AppSpacing.md),
          const _JobApplicationsCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 500.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 500.ms),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'More'),
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

/// Today's tasks card — watches [todayTasksProvider].
///
/// Shows tasks due today (or overdue, or with no due date) that are
/// still outstanding. This mirrors exactly what the Tasks list shows
/// under its "Today" section, so the dashboard and task list never
/// disagree about what counts as "today".
class _TodayTasksCard extends ConsumerWidget {
  const _TodayTasksCard();

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
          ...todayTasks.take(3).map((task) => _TaskSummaryItem(task: task)),
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
  /// 1. A brand-new user with no tasks at all — invite them to create one.
  /// 2. A user who has completed everything due today — celebrate it.
  /// 3. A user with tasks, but none due today — reassure them they're
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

/// A prominent, primary-colored card that opens the AI inbox scan flow.
class _InboxScanCard extends StatelessWidget {
  const _InboxScanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final onPrimary = theme.colorScheme.onPrimary;

    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: () => context.push(AppRoutes.inboxScan),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: onPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan my inbox',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Turn emails into tasks & job updates',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashboard card showing the tracked job-application count.
class _JobApplicationsCard extends ConsumerWidget {
  const _JobApplicationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(jobApplicationCountProvider);

    return DashboardCard(
      icon: Icons.work_outline_rounded,
      title: 'Job Applications',
      trailing: count > 0
          ? Text(
              '$count',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      onTap: () => context.push(AppRoutes.jobApplications),
      child: EmptyStateWidget(
        icon: Icons.badge_outlined,
        title: count == 0
            ? 'No applications tracked yet.'
            : '$count application${count == 1 ? '' : 's'} tracked.',
        subtitle: count == 0
            ? 'Scan your inbox to start tracking.'
            : 'Tap to view interviews, acceptances, and more.',
        compact: true,
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
