/// Home screen — the main dashboard.
///
/// Displays a personalized greeting, quick actions grid,
/// and dashboard cards for Tasks, Habits, Goals, and Journal.
/// All cards show beautiful empty states with warm, encouraging
/// copy that makes the dashboard feel alive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';
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

          // Greeting
          AnimatedGreeting(displayName: displayName),

          const SizedBox(height: AppSpacing.xxxl),

          // Quick Actions
          const SectionHeader(title: 'Quick Actions'),
          _QuickActionsGrid()
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 300.ms),

          const SizedBox(height: AppSpacing.xxxl),

          // Focus for today
          const SectionHeader(title: 'Focus for Today'),

          DashboardCard(
                icon: Icons.auto_awesome_outlined,
                title: "Today's Tasks",
                onTap: () => _showComingSoon(context, 'Tasks'),
                child: EmptyStateWidget(
                  icon: Icons.task_alt_rounded,
                  title: 'No tasks scheduled.',
                  subtitle: 'Perfect day to plan something meaningful.',
                  compact: true,
                  actionLabel: 'Create first task',
                  onAction: () => _showComingSoon(context, 'Tasks'),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 400.ms),

          const SizedBox(height: AppSpacing.md),

          // Habits
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

          // Goal of the week
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

          // Journal
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

          // Bottom spacing for FAB clearance
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

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionButton(
            icon: AppIcons.add,
            label: 'New Task',
            onPressed: () => ComingSoonDialog.show(
              context,
              title: 'New Task',
              message: 'Task creation is coming soon.',
            ),
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
