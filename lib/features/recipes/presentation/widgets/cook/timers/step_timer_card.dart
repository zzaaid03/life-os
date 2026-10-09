/// The timer for one cook-mode step.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/data/models/recipe.dart';
import 'package:life_os/features/recipes/domain/cook_timers.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/timers/timer_ring.dart';

/// Shows and controls the timer for step [stepIndex] of [recipe]. Renders
/// nothing when that step has no timer. Reads and drives
/// `cookTimersProvider` itself; the cook screen only places it.
class StepTimerCard extends ConsumerWidget {
  /// Creates a [StepTimerCard].
  const StepTimerCard({super.key, required this.recipe, required this.stepIndex});

  /// The recipe being cooked.
  final Recipe recipe;

  /// Index into `recipe.steps`.
  final int stepIndex;

  static const double _ringSize = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stepIndex < 0 || stepIndex >= recipe.steps.length) return const SizedBox.shrink();
    final step = recipe.steps[stepIndex];
    if (!step.hasTimer) return const SizedBox.shrink();

    final timers = ref.watch(cookTimersProvider);
    final timer = timers
        .where((t) => t.recipeTitle == recipe.title && t.stepIndex == stepIndex)
        .firstOrNull;
    // Only tick while there is something counting.
    final now = timer == null
        ? DateTime.now()
        : (ref.watch(cookClockProvider).valueOrNull ?? DateTime.now());

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(cookTimersProvider.notifier);

    final Color ringColor;
    if (timer == null || timer.isRunning) {
      ringColor = scheme.primary;
    } else if (timer.finished) {
      ringColor = scheme.error;
    } else {
      ringColor = scheme.outline;
    }

    final digitsStyle = theme.textTheme.displayLarge?.copyWith(
      fontSize: 64,
      fontWeight: FontWeight.w700,
      height: 1,
      color: timer != null && timer.finished ? scheme.error : scheme.onSurface,
      fontFeatures: tabularFigures,
    );

    final Widget centre = timer != null && timer.finished
        ? Text('Done!', style: digitsStyle)
        : Text(
            formatTimer(
              timer == null ? Duration(seconds: step.timerSeconds!) : displayRemaining(timer, now),
            ),
            style: digitsStyle,
          );

    Widget ring = TimerRing(
      timer: timer,
      size: _ringSize,
      strokeWidth: 16,
      color: ringColor,
      trackColor: ringColor.withValues(alpha: 0.15),
      child: Padding(padding: const EdgeInsets.all(AppSpacing.xxl), child: FittedBox(child: centre)),
    );
    if (timer != null && timer.finished) {
      ring = ring
          .animate(key: ValueKey('pulse-${timer.id}'), onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.06, duration: 600.ms, curve: Curves.easeInOut);
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xxl)),
        side: timer != null && timer.finished
            ? BorderSide(color: scheme.error, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              step.timerLabel ?? 'Timer',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.lg),
            ring,
            const SizedBox(height: AppSpacing.xxl),
            _Controls(
              timer: timer,
              startLabel: 'Start ${_durationWords(step.timerSeconds!)} timer',
              onStart: () => notifier.start(
                recipeTitle: recipe.title,
                stepIndex: stepIndex,
                label: step.timerLabel!,
                seconds: step.timerSeconds!,
              ),
              onPause: notifier.pause,
              onResume: notifier.resume,
              onAddMinute: (id) => notifier.addTime(id, 60),
              onReset: notifier.cancel,
              onDismiss: notifier.dismiss,
            ),
          ],
        ),
      ),
    );
  }

  /// "10 min", "45 sec", or "1:30" for anything in between.
  static String _durationWords(int seconds) {
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    if (seconds < 60) return '$seconds sec';
    return formatTimer(Duration(seconds: seconds));
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.timer,
    required this.startLabel,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onAddMinute,
    required this.onReset,
    required this.onDismiss,
  });

  final CookTimer? timer;
  final String startLabel;
  final VoidCallback onStart;
  final ValueChanged<int> onPause;
  final ValueChanged<int> onResume;
  final ValueChanged<int> onAddMinute;
  final ValueChanged<int> onReset;
  final ValueChanged<int> onDismiss;

  static const Size _big = Size.fromHeight(64);
  static const Size _normal = Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final t = timer;
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    if (t == null) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded, size: 32),
        label: Text(startLabel),
        style: FilledButton.styleFrom(minimumSize: _big, textStyle: textStyle),
      );
    }

    if (t.finished) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => onAddMinute(t.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('+1 min'),
              style: OutlinedButton.styleFrom(minimumSize: _normal, textStyle: textStyle),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => onDismiss(t.id),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Dismiss'),
              style: FilledButton.styleFrom(minimumSize: _normal, textStyle: textStyle),
            ),
          ),
        ],
      );
    }

    final running = t.isRunning;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: () => running ? onPause(t.id) : onResume(t.id),
            icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(running ? 'Pause' : 'Resume'),
            style: FilledButton.styleFrom(minimumSize: _normal, textStyle: textStyle),
          ),
        ),
        if (running) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: OutlinedButton(
              onPressed: () => onAddMinute(t.id),
              style: OutlinedButton.styleFrom(minimumSize: _normal, textStyle: textStyle),
              child: const Text('+1 min'),
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: TextButton(
            onPressed: () => onReset(t.id),
            style: TextButton.styleFrom(minimumSize: _normal, textStyle: textStyle),
            child: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
