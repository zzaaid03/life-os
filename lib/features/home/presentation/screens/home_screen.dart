/// Home screen — the main dashboard and first experience.
///
/// Displays a personalized greeting and setup progress.
/// This is NOT the full dashboard. It's the calm first screen
/// users see after completing onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_colors.dart';

import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/home/presentation/widgets/setup_progress_card.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final displayName =
        profileState.profile?.displayName ?? authState.displayName ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              // Greeting
              Text(
                _greeting(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.xs),
              Text(
                displayName,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: AppSpacing.xxl),
              // Welcome message
              Text(
                'Welcome to Life OS.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: AppSpacing.xxxl),
              // Setup progress
              const SetupProgressCard()
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms)
                  .slideY(
                    begin: 0.06,
                    end: 0,
                    duration: 500.ms,
                    delay: 400.ms,
                    curve: Curves.easeOut,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}
