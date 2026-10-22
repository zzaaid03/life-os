import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';
import 'package:life_os/features/fitness/presentation/widgets/rotation_strip.dart';
import 'package:life_os/shared/widgets/dashboard_card.dart';

const int _maxRows = 5;

/// The top card of the fitness hub: the next-up day of the saved plan, or
/// the way to build one.
class CoachCard extends ConsumerStatefulWidget {
  /// Creates a [CoachCard].
  const CoachCard({super.key});

  @override
  ConsumerState<CoachCard> createState() => _CoachCardState();
}

class _CoachCardState extends ConsumerState<CoachCard> {
  /// The day the user tapped in the strip, or null for the next-up day.
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutPlanProvider);
    final plan = state.plan;
    final Widget child;
    if (!state.loaded) {
      child = const _CardMessage(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    } else if (plan == null && state.loadFailed) {
      child = _CardMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load your plan.", textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => ref.read(workoutPlanProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (plan == null || plan.days.isEmpty) {
      child = const _EmptyPlan();
    } else {
      final next = nextUpDay(plan).clamp(0, plan.days.length - 1);
      final shown = (_picked ?? next).clamp(0, plan.days.length - 1);
      child = _PlanBody(
        plan: plan,
        shown: shown,
        next: next,
        onPick: (i) => setState(() => _picked = i),
      );
    }
    return DashboardCard(child: child);
  }
}

class _CardMessage extends StatelessWidget {
  const _CardMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 160,
      child: Center(child: child),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Build your plan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '6 quick questions',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => context.push(AppRoutes.fitnessPlanNew),
          child: const Text('Build my plan'),
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({
    required this.plan,
    required this.shown,
    required this.next,
    required this.onPick,
  });

  final WorkoutPlan plan;
  final int shown;
  final int next;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = plan.days[shown];
    final letter = dayLetter(shown);
    final eyebrow = shown == next
        ? 'NEXT UP · DAY $letter OF ${plan.days.length}'
        : 'DAY $letter OF ${plan.days.length}';
    final rows = day.exercises.take(_maxRows).toList();
    final more = day.exercises.length - rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          day.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final e in rows) ExerciseRow(exercise: e),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '+ $more more',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        RotationStrip(
          days: plan.days,
          selected: shown,
          nextUp: next,
          onPick: onPick,
        ),
      ],
    );
  }
}

/// One exercise: name left, prescription right. At large text scales the
/// prescription wraps below the name.
class ExerciseRow extends StatelessWidget {
  /// Creates an [ExerciseRow].
  const ExerciseRow({super.key, required this.exercise});

  final PlanExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prescription = formatPrescription(exercise);
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final nameText = Text(exercise.name, style: theme.textTheme.bodyLarge);
    final rxText = Text(
      prescription,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    );
    return Semantics(
      label: '${exercise.name}, $prescription',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [nameText, rxText],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: nameText),
                  const SizedBox(width: AppSpacing.md),
                  rxText,
                ],
              ),
      ),
    );
  }
}
