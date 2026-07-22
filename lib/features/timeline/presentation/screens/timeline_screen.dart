/// Timeline screen — month calendar of upcoming and past task activity.
///
/// Renders the [CalendarView] month grid; tapping a day lists that day's
/// tasks beneath the grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/calendar/presentation/widgets/calendar_view.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Timeline',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const CalendarView(),
          const SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }
}
