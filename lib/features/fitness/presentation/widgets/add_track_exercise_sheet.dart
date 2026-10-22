import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/exercise_draft.dart';

/// Asks for a name and Reps/Time for an exercise that lives in today's
/// session only. Returns null when dismissed.
Future<({String name, String kind})?> showAddTrackExercise(
  BuildContext context,
) {
  return showModalBottomSheet<({String name, String kind})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _Sheet(),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet();

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final _name = TextEditingController();
  String _kind = 'reps';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final valid = _name.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.lg + inset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add exercise for today',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: kMaxExerciseName,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'reps', label: Text('Reps')),
              ButtonSegment(value: 'time', label: Text('Time')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: valid
                  ? () => Navigator.of(
                      context,
                    ).pop((name: _name.text.trim(), kind: _kind))
                  : null,
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
