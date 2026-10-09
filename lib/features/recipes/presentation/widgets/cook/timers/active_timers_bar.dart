/// Floating bar of running timers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/recipes/domain/cook_timers.dart';
import 'package:life_os/features/recipes/presentation/widgets/cook/timers/timer_ring.dart';

/// A compact strip of every live timer for [recipeTitle] EXCEPT the one
/// belonging to [currentStepIndex] (that one is already big on screen).
/// Tapping a timer calls [onJumpToStep] with its step index. Renders nothing
/// when there is nothing to show.
class ActiveTimersBar extends ConsumerWidget {
  /// Creates an [ActiveTimersBar].
  const ActiveTimersBar({
    super.key,
    required this.recipeTitle,
    required this.onJumpToStep,
    this.currentStepIndex,
  });

  /// Only this recipe's timers are shown.
  final String recipeTitle;

  /// Called with a step index when a timer is tapped.
  final ValueChanged<int> onJumpToStep;

  /// The step on screen, or null on the mise en place / finish pages.
  final int? currentStepIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timers = ref
        .watch(cookTimersProvider)
        .where((t) => t.recipeTitle == recipeTitle && t.stepIndex != currentStepIndex)
        .toList();
    // Only tick while there is something to show.
    final now = timers.isEmpty
        ? DateTime.now()
        : (ref.watch(cookClockProvider).valueOrNull ?? DateTime.now());

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: timers.isEmpty
            ? const SizedBox(key: ValueKey('empty'), width: double.infinity)
            : SingleChildScrollView(
                key: const ValueKey('bar'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    for (final t in timers)
                      Padding(
                        key: ValueKey(t.id),
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _TimerPill(
                          timer: t,
                          now: now,
                          onTap: () => onJumpToStep(t.stepIndex),
                        ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.9, end: 1),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.timer, required this.now, required this.onTap});

  final CookTimer timer;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = timer.finished;

    final background = done ? scheme.error : scheme.surfaceContainerHighest;
    final foreground = done ? scheme.onError : scheme.onSurface;
    final ringColor = done ? scheme.onError : (timer.isRunning ? scheme.primary : scheme.outline);

    Widget pill = Material(
      color: background,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.circular)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.circular)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TimerRing(
                timer: timer,
                size: 24,
                strokeWidth: 4,
                color: ringColor,
                trackColor: ringColor.withValues(alpha: 0.2),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  timer.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                done ? 'Done' : formatTimer(displayRemaining(timer, now)),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (done) {
      pill = pill
          .animate(key: ValueKey('pulse-${timer.id}'), onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.08, duration: 500.ms, curve: Curves.easeInOut);
    }
    return pill;
  }
}
