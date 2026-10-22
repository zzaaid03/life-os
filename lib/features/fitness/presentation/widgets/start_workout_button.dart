import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_session_providers.dart';

/// "Resume workout" when a session is open today, "Start workout" when [day]
/// is the next-up day, otherwise nothing. A failed session load shows a retry
/// instead of guessing.
class StartWorkoutButton extends ConsumerStatefulWidget {
  /// Creates a [StartWorkoutButton].
  const StartWorkoutButton({super.key, required this.plan, required this.day});

  final WorkoutPlan plan;
  final PlanDay day;

  @override
  ConsumerState<StartWorkoutButton> createState() => _StartWorkoutButtonState();
}

class _StartWorkoutButtonState extends ConsumerState<StartWorkoutButton> {
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(workoutSessionsProvider.notifier)
          .startWorkout(widget.plan, widget.day);
      if (mounted) unawaited(context.push('/fitness/track/$id'));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Couldn't start the workout. Try again."),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(workoutSessionsProvider);
    if (!sessions.loaded) return const SizedBox.shrink();
    if (sessions.loadFailed) {
      return Row(
        children: [
          const Expanded(child: Text("Couldn't load your workouts.")),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => ref.read(workoutSessionsProvider.notifier).load(),
            child: const Text('Retry'),
          ),
        ],
      );
    }
    final open = sessions.openToday;
    final next = nextUpDay(widget.plan, sessions.lastSession);
    final isNext =
        next < widget.plan.days.length &&
        widget.plan.days[next].id == widget.day.id;
    if (open == null && !isNext) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _busy
              ? null
              : open != null
              ? () => unawaited(context.push('/fitness/track/${open.id}'))
              : _start,
          child: Text(open != null ? 'Resume workout' : 'Start workout'),
        ),
      ),
    );
  }
}
