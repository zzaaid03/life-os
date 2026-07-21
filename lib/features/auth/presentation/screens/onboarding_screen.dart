/// Onboarding screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              const Spacer(),
              Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: theme.colorScheme.primary,
                      size: 56,
                    ),
                  )
                  .animate()
                  .scale(
                    duration: 600.ms,
                    curve: Curves.easeOut,
                    begin: const Offset(0.8, 0.8),
                  )
                  .fadeIn(duration: 600.ms),
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                    'Welcome to Life OS',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(
                    duration: 400.ms,
                    delay: 200.ms,
                    begin: 0.2,
                    end: 0,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your life, beautifully organized.\n'
                'Track tasks and achieve your goals.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
              const Spacer(),
              SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go(AppRoutes.login),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.button,
                        ),
                      ),
                      child: const Text('Get Started'),
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 600.ms)
                  .slideY(
                    duration: 400.ms,
                    delay: 600.ms,
                    begin: 0.3,
                    end: 0,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
