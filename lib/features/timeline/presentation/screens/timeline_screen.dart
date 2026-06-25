/// Timeline screen — chronological view of life events.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline')),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: Text(
            'Your timeline will appear here.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
