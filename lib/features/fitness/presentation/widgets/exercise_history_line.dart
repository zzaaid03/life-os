import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/personal_best.dart';
import 'package:life_os/features/fitness/domain/track_state.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

// Sets shown in the "Last time" line before "+N more".
const _maxShown = 5;

/// "Last time" and "Best" for one exercise, shown under its name in track mode.
class ExerciseHistoryLine extends StatelessWidget {
  /// Creates an [ExerciseHistoryLine].
  const ExerciseHistoryLine({
    super.key,
    required this.exercise,
    required this.units,
    this.historyFailed = false,
  });

  final TrackExercise exercise;
  final UnitSystem units;

  /// When true the last-time load failed, and the screen already says so.
  final bool historyFailed;

  String _lastTime() {
    final sets = [...exercise.lastSets]
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    final shown = sets.take(_maxShown).map((s) => describeSet(s, units));
    final more = sets.length - _maxShown;
    return 'Last time: ${shown.join(', ')}${more > 0 ? ' +$more more' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final best = exercise.best;
    final lines = <String>[];
    if (exercise.lastSets.isNotEmpty) {
      lines.add(_lastTime());
    } else if (!historyFailed) {
      lines.add('First time doing this one.');
    }
    if (exercise.bestFailed) {
      lines.add("Couldn't load your best.");
    } else if (best != null) {
      lines.add('Best: ${describeSet(best, units)}');
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final l in lines) Text(l, style: style)],
      ),
    );
  }
}
