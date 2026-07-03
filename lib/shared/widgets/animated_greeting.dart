/// Animated greeting widget.
///
/// Displays a time-based greeting that fades in on first build.
/// The greeting automatically changes based on the current hour:
/// - Good morning (before 12:00)
/// - Good afternoon (12:00–17:00)
/// - Good evening (after 17:00)
///
/// Includes an inspirational subtitle that makes the dashboard
/// feel alive rather than empty.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// A greeting that adapts to the time of day with a fade-in animation.
class AnimatedGreeting extends StatelessWidget {
  /// Creates an [AnimatedGreeting].
  const AnimatedGreeting({super.key, required this.displayName});

  /// The user's display name.
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _greeting();
    final subtitle = _subtitle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
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
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _subtitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Today is yours.';
    if (hour < 17) return 'Keep the momentum going.';
    return 'Reflect on today.';
  }
}
