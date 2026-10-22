/// Home screen: the main dashboard.
///
/// Displays a personalized greeting, quick actions grid,
/// and dashboard cards for Tasks, the Inbox Assistant, and Goals.
/// The Tasks card shows live data from the task provider.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/fitness/presentation/widgets/home_fitness_card.dart';
import 'package:life_os/features/home/presentation/widgets/home_brief_cards.dart';
import 'package:life_os/features/home/presentation/widgets/home_feature_cards.dart';
import 'package:life_os/features/home/presentation/widgets/home_goals_card.dart';
import 'package:life_os/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:life_os/features/home/presentation/widgets/home_today_tasks_card.dart';
import 'package:life_os/features/onboarding/domain/announcements_provider.dart';
import 'package:life_os/features/onboarding/presentation/announcements_sheet.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';
import 'package:life_os/shared/widgets/animated_greeting.dart';
import 'package:life_os/shared/widgets/section_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _announcementsPrompted = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final displayName =
        profileState.profile?.displayName ?? authState.displayName ?? 'there';

    final announcementsState = ref.watch(announcementsProvider);
    if (!_announcementsPrompted &&
        announcementsState.loaded &&
        unseenReleases(announcementsState.ackedVersion).isNotEmpty) {
      _announcementsPrompted = true;
      final releases = unseenReleases(announcementsState.ackedVersion);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AnnouncementsSheet.show(context, releases).then((_) {
          ref.read(announcementsProvider.notifier).acknowledgeAll();
        });
      });
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          AnimatedGreeting(displayName: displayName),
          const SizedBox(height: AppSpacing.xl),
          const HomeDailyBriefCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 200.ms),
          const HomeWeeklyReviewPointerCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 250.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 250.ms),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Quick Actions'),
          const HomeQuickActionsGrid()
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 300.ms),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Focus for Today'),
          const HomeTodayTasksCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 400.ms),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Goals'),
          const HomeGoalsCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 450.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 450.ms),
          const SizedBox(height: AppSpacing.xxxl),
          const SectionHeader(title: 'Inbox Assistant'),
          const HomeInboxScanCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 450.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 450.ms),
          const SizedBox(height: AppSpacing.md),
          const HomeJobApplicationsCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 500.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 500.ms),
          const HomeSubscriptionsSection()
              .animate()
              .fadeIn(duration: 400.ms, delay: 550.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 550.ms),
          const SizedBox(height: AppSpacing.md),
          const HomeGroceriesSection()
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 600.ms),
          const SizedBox(height: AppSpacing.md),
          const HomeRecipesSection()
              .animate()
              .fadeIn(duration: 400.ms, delay: 650.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 650.ms),
          const SizedBox(height: AppSpacing.md),
          const HomeFitnessSection()
              .animate()
              .fadeIn(duration: 400.ms, delay: 700.ms)
              .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: 700.ms),
          const SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }
}
