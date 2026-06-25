/// Splash screen — the initial entry point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (mounted) {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.white,
                    size: 40,
                  ),
                )
                .animate()
                .scale(
                  duration: 600.ms,
                  curve: Curves.easeOut,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                )
                .fadeIn(duration: 600.ms),
            const SizedBox(height: AppSpacing.xl),
            Text(
                  'Life OS',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms)
                .slideY(
                  duration: 400.ms,
                  delay: 300.ms,
                  begin: 0.2,
                  end: 0,
                  curve: Curves.easeOut,
                ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your life, beautifully organized.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
