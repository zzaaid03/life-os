/// Track mode: log the sets of one workout, one exercise at a time.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/track_notifier.dart';
import 'package:life_os/features/fitness/domain/track_state.dart';
import 'package:life_os/features/fitness/presentation/widgets/add_track_exercise_sheet.dart';
import 'package:life_os/features/fitness/presentation/widgets/set_row_tile.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

/// Full screen, outside the bottom nav. X (or back) leaves the workout.
class TrackScreen extends ConsumerStatefulWidget {
  /// Creates a [TrackScreen] for the session [sessionId].
  const TrackScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  bool _leaving = false;

  TrackNotifier get _notifier =>
      ref.read(trackProvider(widget.sessionId).notifier);

  void _say(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.fitness);
    }
  }

  // Finish button: no confirm. X and back: confirm only when sets exist.
  Future<void> _leave({required bool confirm}) async {
    if (_leaving) return;
    final state = ref.read(trackProvider(widget.sessionId));
    if (state.loading || state.error != null) {
      _exit();
      return;
    }
    if (confirm && state.loggedCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave workout?'),
          content: const Text('The sets you logged are kept.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _leaving = true);
    try {
      final result = await _notifier.leave();
      if (!mounted) return;
      if (result == WorkoutExit.savedCheckinFailed) {
        _say("Workout saved, but today's check-in didn't update.");
      }
      _exit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _leaving = false);
      _say("Couldn't close the workout. Check your connection and try again.");
    }
  }

  Future<void> _addExercise() async {
    final picked = await showAddTrackExercise(context);
    if (picked == null || !mounted) return;
    await _notifier.addExercise(picked.name, picked.kind);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackProvider(widget.sessionId));
    final units = ref.watch(calorieProfileProvider).profile.units;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(confirm: true);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(state.session?.dayTitle ?? 'Workout'),
          actions: [
            IconButton(
              tooltip: 'Leave workout',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _leaving ? null : () => _leave(confirm: true),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: _body(state, units),
      ),
    );
  }

  Widget _body(TrackState state, UnitSystem units) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _notifier.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final exercises = state.exercises;
    if (exercises.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No exercises on this day.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _addExercise,
                child: const Text('Add exercise for today'),
              ),
            ],
          ),
        ),
      );
    }
    final i = state.index;
    final last = i == exercises.length - 1;
    final current = exercises[i];
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXERCISE ${i + 1} OF ${exercises.length}'
                    '${current.skipped ? ' · SKIPPED' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                  Text(
                    current.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (state.historyFailed)
                    Text(
                      "Couldn't load last time's numbers.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            // Every exercise stays built so typed numbers survive Previous/Next.
            child: IndexedStack(
              index: i,
              children: [
                for (var e = 0; e < exercises.length; e++)
                  _ExercisePage(
                    key: ValueKey(exercises[e].key),
                    exercise: exercises[e],
                    units: units,
                    notifier: _notifier,
                    index: e,
                    isLast: e == exercises.length - 1,
                    onAddExercise: _addExercise,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: i == 0 ? null : () => _notifier.goTo(i - 1),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: last
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _leaving
                              ? null
                              : () => _leave(confirm: false),
                          child: const Text('Finish workout'),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _notifier.goTo(i + 1),
                          child: const Text('Next'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePage extends StatelessWidget {
  const _ExercisePage({
    super.key,
    required this.exercise,
    required this.units,
    required this.notifier,
    required this.index,
    required this.isLast,
    required this.onAddExercise,
  });

  final TrackExercise exercise;
  final UnitSystem units;
  final TrackNotifier notifier;
  final int index;
  final bool isLast;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      children: [
        for (var r = 0; r < exercise.rows.length; r++)
          SetRowTile(
            key: ValueKey(exercise.rows[r].key),
            row: exercise.rows[r],
            kind: exercise.kind,
            units: units,
            onLog: (v) => notifier.logRow(index, r, v),
            onUpdate: (v) => notifier.updateRow(index, r, v),
            onRemove: () => notifier.removeLog(index, r),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (exercise.rows.length < kMaxSetsPerExercise)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => notifier.addRow(index),
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
            if (!isLast && exercise.loggedCount == 0)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: notifier.skipCurrent,
                child: const Text('Skip exercise'),
              ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onAddExercise,
              child: const Text('Add exercise for today'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
