/// Life screen — holistic life management.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';

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
          child: Text(
            'Your life dashboard will appear here.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
