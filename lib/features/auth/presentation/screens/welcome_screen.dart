/// Welcome screen — the first screen new users see.
///
/// Minimal, elegant, Apple-inspired. No illustrations.
/// Just a warm welcome and a single call to action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/demo/demo_mode.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              // Title
              Text(
                    'Welcome.',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms)
                  .slideY(begin: 0.08, end: 0, duration: 500.ms, delay: 200.ms),
              const SizedBox(height: AppSpacing.md),
              // Subtitle
              Text(
                    'Your life, in one place.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms)
                  .slideY(begin: 0.08, end: 0, duration: 500.ms, delay: 400.ms),
              const Spacer(flex: 2),
              // Primary CTA
              SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () => context.go(AppRoutes.login),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.button,
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Get Started'),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 700.ms)
                  .slideY(begin: 0.12, end: 0, duration: 500.ms, delay: 700.ms),
              const SizedBox(height: AppSpacing.md),
              // Sandbox demo CTA
              SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: enterDemoMode,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.button,
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Try it — no sign-up'),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 850.ms)
                  .slideY(begin: 0.12, end: 0, duration: 500.ms, delay: 850.ms),
              const SizedBox(height: AppSpacing.massive),
            ],
          ),
        ),
      ),
    );
  }
}
