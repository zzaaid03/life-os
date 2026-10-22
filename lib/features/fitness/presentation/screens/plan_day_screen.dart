/// One day of the saved plan: its exercises, with editing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/exercise_draft.dart';
import 'package:life_os/features/fitness/domain/workout_plan.dart';
import 'package:life_os/features/fitness/domain/workout_plan_providers.dart';
import 'package:life_os/features/fitness/presentation/widgets/coach_card.dart';
import 'package:life_os/features/fitness/presentation/widgets/exercise_editor_sheet.dart';
import 'package:life_os/features/fitness/presentation/widgets/start_workout_button.dart';

/// Shows the day with id [dayId]. Swipe a row to delete it (with Undo), tap
/// Edit to reorder, tap a row to change it.
class PlanDayScreen extends ConsumerStatefulWidget {
  /// Creates a [PlanDayScreen].
  const PlanDayScreen({super.key, required this.dayId});

  final String dayId;

  @override
  ConsumerState<PlanDayScreen> createState() => _PlanDayScreenState();
}

class _PlanDayScreenState extends ConsumerState<PlanDayScreen> {
  bool _editing = false;

  void _say(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  // Runs a notifier write. The notifier has already reloaded the plan on a
  // failure, so the screen matches the database; this says so to the user.
  Future<void> _run(Future<void> Function() write, String failure) async {
    try {
      await write();
    } catch (_) {
      if (mounted) _say(failure);
    }
  }

  Future<void> _add(PlanDay day) async {
    if (day.exercises.length >= kMaxExercisesPerDay) {
      _say('A day holds up to $kMaxExercisesPerDay exercises.');
      return;
    }
    final draft = await showExerciseEditor(context);
    if (draft == null || !mounted) return;
    await _run(
      () => ref.read(workoutPlanProvider.notifier).addExercise(day.id, draft),
      "Couldn't add the exercise. Try again.",
    );
  }

  Future<void> _edit(PlanExercise e) async {
    final draft = await showExerciseEditor(
      context,
      initial: ExerciseDraft.fromExercise(e),
    );
    if (draft == null || !mounted) return;
    await _run(
      () => ref.read(workoutPlanProvider.notifier).updateExercise(e.id, draft),
      "Couldn't save your changes. Try again.",
    );
  }

  Future<void> _remove(PlanDay day, PlanExercise e, int index) async {
    final notifier = ref.read(workoutPlanProvider.notifier);
    try {
      await notifier.removeExercise(day.id, e.id);
    } catch (_) {
      if (mounted) _say("Couldn't delete the exercise. Try again.");
      return;
    }
    // Undo is offered after the delete finished, so a restore can never
    // run before it.
    if (!mounted) return;
    _say(
      '${e.name} deleted',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => _run(
          () => notifier.restoreExercise(day.id, e, index),
          "Couldn't bring it back. Try adding it again.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(workoutPlanProvider).plan;
    PlanDay? day;
    for (final d in plan?.days ?? <PlanDay>[]) {
      if (d.id == widget.dayId) day = d;
    }
    if (day == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout day')),
        body: const Center(child: Text('This day is no longer in your plan.')),
      );
    }
    final shown = day;
    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${dayLetter(shown.position)} · ${shown.title}'),
        actions: [
          if (shown.exercises.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _editing = !_editing),
              child: Text(_editing ? 'Done' : 'Edit'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(shown),
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
      body: Column(
        children: [
          if (plan != null && !_editing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                0,
              ),
              child: StartWorkoutButton(plan: plan, day: shown),
            ),
          Expanded(
            child: shown.exercises.isEmpty
                ? const _EmptyDay()
                : _editing
                ? _reorderList(shown)
                : _swipeList(shown),
          ),
        ],
      ),
    );
  }

  Widget _swipeList(PlanDay day) {
    return ListView.builder(
      padding: _listPadding,
      itemCount: day.exercises.length,
      itemBuilder: (context, i) {
        final e = day.exercises[i];
        return Dismissible(
          key: ValueKey('swipe-${e.id}'),
          direction: DismissDirection.endToStart,
          background: const _DeleteBackground(),
          onDismissed: (_) => _remove(day, e, i),
          child: InkWell(
            onTap: () => _edit(e),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ExerciseRow(exercise: e),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reorderList(PlanDay day) {
    return ReorderableListView.builder(
      padding: _listPadding,
      itemCount: day.exercises.length,
      onReorderItem: (oldIndex, newIndex) => _run(
        () => ref
            .read(workoutPlanProvider.notifier)
            .reorderExercises(day.id, oldIndex, newIndex),
        "Couldn't save the new order. Try again.",
      ),
      itemBuilder: (context, i) {
        final e = day.exercises[i];
        return ConstrainedBox(
          key: ValueKey('drag-${e.id}'),
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(child: ExerciseRow(exercise: e)),
              ReorderableDragStartListener(
                index: i,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Bottom padding keeps the last row clear of the add button.
const EdgeInsets _listPadding = EdgeInsets.fromLTRB(
  AppSpacing.screenHorizontal,
  AppSpacing.sm,
  AppSpacing.screenHorizontal,
  96,
);

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Text(
          'No exercises on this day yet. Tap Add exercise to start.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
