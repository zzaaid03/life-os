/// Life screen — holistic life management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/shared/widgets/floating_nav_bar.dart';

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Life')),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_outline_rounded,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'I\'m here whenever you need me.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FloatingNavBar(currentLocation: '/life'),
    );
  }
}
