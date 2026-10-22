/// Six quick questions, then the AI builds and saves a workout plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/data/workout_plan_repository.dart';
import 'package:life_os/features/fitness/domain/plan_inputs.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';

/// The plan questionnaire. Answers are kept when a build fails.
class PlanQuestionnaireScreen extends ConsumerStatefulWidget {
  /// Creates a [PlanQuestionnaireScreen].
  const PlanQuestionnaireScreen({super.key});

  @override
  ConsumerState<PlanQuestionnaireScreen> createState() =>
      _PlanQuestionnaireScreenState();
}

class _PlanQuestionnaireScreenState
    extends ConsumerState<PlanQuestionnaireScreen> {
  PlanInputs _inputs = const PlanInputs();
  bool _building = false;
  String? _error;

  Future<void> _build() async {
    setState(() {
      _building = true;
      _error = null;
    });
    try {
      await ref.read(workoutPlanProvider.notifier).generate(_inputs);
      if (!mounted) return;
      context.pop();
    } on DailyLimitReached {
      if (!mounted) return;
      setState(() {
        _building = false;
        _error = "You've built 3 plans today. Try again tomorrow.";
      });
    } catch (e) {
      debugPrint('Workout plan build failed: $e');
      if (!mounted) return;
      setState(() {
        _building = false;
        _error =
            "Couldn't build your plan. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Build your plan')),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          _Question<String>(
            title: "What's your goal?",
            choices: goalChoices,
            value: _inputs.goal,
            enabled: !_building,
            onPick: (v) => setState(() => _inputs = _inputs.copyWith(goal: v)),
          ),
          _Question<String>(
            title: 'What style do you like?',
            choices: styleChoices,
            value: _inputs.style,
            enabled: !_building,
            onPick: (v) => setState(() => _inputs = _inputs.copyWith(style: v)),
          ),
          _Question<String>(
            title: 'What equipment do you have?',
            choices: equipmentChoices,
            value: _inputs.equipment,
            enabled: !_building,
            onPick: (v) =>
                setState(() => _inputs = _inputs.copyWith(equipment: v)),
          ),
          _Question<int>(
            title: 'Days a week',
            choices: daysChoices,
            value: _inputs.daysPerWeek,
            enabled: !_building,
            onPick: (v) =>
                setState(() => _inputs = _inputs.copyWith(daysPerWeek: v)),
          ),
          _Question<int>(
            title: 'Minutes per session',
            choices: minutesChoices,
            value: _inputs.sessionMinutes,
            enabled: !_building,
            onPick: (v) =>
                setState(() => _inputs = _inputs.copyWith(sessionMinutes: v)),
          ),
          _Question<String>(
            title: 'Your experience',
            choices: experienceChoices,
            value: _inputs.experience,
            enabled: !_building,
            onPick: (v) =>
                setState(() => _inputs = _inputs.copyWith(experience: v)),
          ),
          Text(
            'Injuries or limits (optional)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            enabled: !_building,
            maxLength: kPlanLimitsMaxLength,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'For example: sore left shoulder',
            ),
            onChanged: (v) => _inputs = _inputs.copyWith(limits: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...[
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_building)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: AppSpacing.md),
                Text('Building your plan…', style: theme.textTheme.bodyMedium),
              ],
            ),
          if (_building) const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _inputs.isComplete && !_building ? _build : null,
            child: const Text('Build my plan'),
          ),
        ],
      ),
    );
  }
}

class _Question<T> extends StatelessWidget {
  const _Question({
    required this.title,
    required this.choices,
    required this.value,
    required this.enabled,
    required this.onPick,
  });

  final String title;
  final List<PlanChoice<T>> choices;
  final T? value;
  final bool enabled;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in choices)
                ChoiceChip(
                  label: Text(c.label),
                  selected: value == c.value,
                  onSelected: enabled ? (_) => onPick(c.value) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
