/// Notification permission screen.
///
/// Explains why Life OS needs notification access
/// before asking. Supports graceful decline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.massive),
              // Progress
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const Spacer(),
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: theme.colorScheme.primary,
                  size: 36,
                ),
              ).animate().scale(duration: 500.ms).fadeIn(duration: 500.ms),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Stay in the loop',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Life OS sends gentle reminders for tasks and goals. No spam. Just what matters.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.permissionCalendar),
                  child: const Text('Allow Notifications'),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go(AppRoutes.permissionCalendar),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 550.ms),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
