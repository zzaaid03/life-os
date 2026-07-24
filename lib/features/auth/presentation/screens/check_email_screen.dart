/// Check email screen.
///
/// Shown after sign-up when Supabase requires email confirmation before a
/// session is issued.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_icons.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                AppIcons.email,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Check your email',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: AppSpacing.sm),
              Text(
                email != null
                    ? 'We sent a confirmation link to $email. Click it to finish creating your account.'
                    : 'We sent a confirmation link to your email. Click it to finish creating your account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Back to sign in'),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
