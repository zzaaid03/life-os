/// Home screen — the main dashboard.
///
/// Displays a personalized greeting, quick actions grid,
/// and dashboard cards for Tasks, Habits, Goals, and Journal.
/// All cards show beautiful empty states until data exists.
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

          // Today at a glance
          const SectionHeader(title: 'Today at a Glance'),

          // Tasks card
          DashboardCard(
                icon: Icons.check_circle_outline_rounded,
                title: "Today's Tasks",
                onTap: () => _showComingSoon(context, 'Tasks'),
                child: const EmptyStateWidget(
                  icon: Icons.task_alt_rounded,
                  title: 'No tasks for today',
                  subtitle: 'Enjoy the calm.',
                  compact: true,
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 400.ms),

          const SizedBox(height: AppSpacing.md),

          // Habits card
          DashboardCard(
                icon: Icons.repeat_rounded,
                title: 'Habits',
                onTap: () => _showComingSoon(context, 'Habits'),
                child: const EmptyStateWidget(
                  icon: Icons.favorite_outline_rounded,
                  title: 'No habits yet',
                  subtitle: 'Build your first habit.',
                  compact: true,
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 500.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 500.ms),

          const SizedBox(height: AppSpacing.md),

          // Goals card
          DashboardCard(
                icon: Icons.flag_outlined,
                title: 'Goals',
                onTap: () => _showComingSoon(context, 'Goals'),
                child: const EmptyStateWidget(
                  icon: Icons.track_changes_rounded,
                  title: 'Nothing in progress',
                  subtitle: 'Create your first goal.',
                  compact: true,
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 600.ms),

          const SizedBox(height: AppSpacing.md),

          // Journal card
          DashboardCard(
                icon: Icons.book_outlined,
                title: 'Journal',
                onTap: () => _showComingSoon(context, 'Journal'),
                child: const EmptyStateWidget(
                  icon: Icons.edit_note_rounded,
                  title: 'No journal entry today',
                  subtitle: 'Capture today\'s thoughts.',
                  compact: true,
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
