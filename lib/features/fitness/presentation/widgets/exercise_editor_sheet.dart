import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/exercise_draft.dart';

/// Opens the add / edit sheet. Resolves to the saved draft, or null when the
/// user closes it.
Future<ExerciseDraft?> showExerciseEditor(
  BuildContext context, {
  ExerciseDraft? initial,
}) {
  return showModalBottomSheet<ExerciseDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ExerciseEditorSheet(initial: initial),
  );
}

class _ExerciseEditorSheet extends StatefulWidget {
  const _ExerciseEditorSheet({this.initial});

  final ExerciseDraft? initial;

  @override
  State<_ExerciseEditorSheet> createState() => _ExerciseEditorSheetState();
}

class _ExerciseEditorSheetState extends State<_ExerciseEditorSheet> {
  late ExerciseDraft _draft = widget.initial ?? const ExerciseDraft();
  late final TextEditingController _name = TextEditingController(
    text: _draft.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(ExerciseDraft next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adding = widget.initial == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              adding ? 'Add exercise' : 'Edit exercise',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              maxLength: kMaxExerciseName,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => _set(_draft.withName(v)),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'reps', label: Text('Reps')),
                ButtonSegment(value: 'time', label: Text('Time')),
              ],
              selected: {_draft.kind},
              onSelectionChanged: (s) => _set(_draft.withKind(s.first)),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(0, 48)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _StepperRow(
              label: 'Sets',
              value: '${_draft.sets}',
              onMinus: _draft.sets > 1
                  ? () => _set(_draft.withSets(_draft.sets - 1))
                  : null,
              onPlus: _draft.sets < 10
                  ? () => _set(_draft.withSets(_draft.sets + 1))
                  : null,
            ),
            if (_draft.isTime)
              _StepperRow(
                label: 'Hold',
                value: '${_draft.holdSeconds}s',
                onMinus: (_draft.holdSeconds ?? 5) > 5
                    ? () => _set(_draft.withHold(_draft.holdSeconds! - 5))
                    : null,
                onPlus: (_draft.holdSeconds ?? 300) < 300
                    ? () => _set(_draft.withHold(_draft.holdSeconds! + 5))
                    : null,
              )
            else ...[
              _StepperRow(
                label: 'Reps min',
                value: '${_draft.repsMin}',
                onMinus: (_draft.repsMin ?? 1) > 1
                    ? () => _set(_draft.withRepsMin(_draft.repsMin! - 1))
                    : null,
                onPlus: (_draft.repsMin ?? 50) < (_draft.repsMax ?? 50)
                    ? () => _set(_draft.withRepsMin(_draft.repsMin! + 1))
                    : null,
              ),
              _StepperRow(
                label: 'Reps max',
                value: '${_draft.repsMax}',
                onMinus: (_draft.repsMax ?? 1) > (_draft.repsMin ?? 1)
                    ? () => _set(_draft.withRepsMax(_draft.repsMax! - 1))
                    : null,
                onPlus: (_draft.repsMax ?? 50) < 50
                    ? () => _set(_draft.withRepsMax(_draft.repsMax! + 1))
                    : null,
              ),
            ],
            _StepperRow(
              label: 'Rest',
              value: '${_draft.restSeconds}s',
              onMinus: _draft.restSeconds > 0
                  ? () => _set(_draft.withRest(_draft.restSeconds - 15))
                  : null,
              onPlus: _draft.restSeconds < 600
                  ? () => _set(_draft.withRest(_draft.restSeconds + 15))
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _draft.isValid
                  ? () => Navigator.of(context).pop(_draft)
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled value with 48pt minus and plus buttons. A null callback
/// disables that button at the limit.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: '$label $value',
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            tooltip: 'Less $label',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onMinus,
            icon: const Icon(Icons.remove),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: dark ? AppColors.primary : AppColors.primaryDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'More $label',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onPlus,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
