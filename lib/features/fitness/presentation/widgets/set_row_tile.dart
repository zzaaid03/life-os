import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/track_state.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

const _tabular = [FontFeature.tabularFigures()];

/// One set of an exercise. Unlogged: number fields and a check button.
/// Logged: a summary line with a check icon; tap it to change or remove it.
class SetRowTile extends StatefulWidget {
  /// Creates a [SetRowTile].
  const SetRowTile({
    super.key,
    required this.row,
    required this.kind,
    required this.units,
    required this.onLog,
    required this.onUpdate,
    required this.onRemove,
  });

  final TrackRow row;

  /// `reps` or `time`.
  final String kind;
  final UnitSystem units;
  final Future<void> Function(SetValues values) onLog;
  final Future<void> Function(SetValues values) onUpdate;
  final Future<void> Function() onRemove;

  @override
  State<SetRowTile> createState() => _SetRowTileState();
}

class _SetRowTileState extends State<SetRowTile> {
  late final TextEditingController _main;
  late final TextEditingController _weight;
  bool _editing = false;
  String? _error;

  bool get _isTime => widget.kind == 'time';
  bool get _logged => widget.row.logged != null;

  @override
  void initState() {
    super.initState();
    final v = widget.row.initial;
    _main = TextEditingController(
      text: (_isTime ? v.holdSeconds : v.reps)?.toString() ?? '',
    );
    _weight = TextEditingController(text: weightText(v.weightKg, widget.units));
  }

  @override
  void dispose() {
    _main.dispose();
    _weight.dispose();
    super.dispose();
  }

  SetValues? _parse() {
    final result = parseSetInput(
      kind: widget.kind,
      reps: _isTime ? '' : _main.text,
      hold: _isTime ? _main.text : '',
      weight: _weight.text,
      units: widget.units,
    );
    setState(() => _error = result.error);
    return result.values;
  }

  void _say(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    try {
      await action();
    } catch (_) {
      if (mounted) _say(failure);
    }
  }

  Future<void> _log() async {
    final values = _parse();
    if (values == null) return;
    await _run(() => widget.onLog(values), "Couldn't save the set. Try again.");
  }

  Future<void> _save() async {
    final values = _parse();
    if (values == null) return;
    await _run(() async {
      await widget.onUpdate(values);
      if (mounted) setState(() => _editing = false);
    }, "Couldn't save your changes. Try again.");
  }

  Future<void> _remove() async {
    await _run(() async {
      await widget.onRemove();
      if (mounted) setState(() => _editing = false);
    }, "Couldn't remove the set. Try again.");
  }

  String _summary() {
    final logged = widget.row.logged!;
    final main = _isTime
        ? '${logged.holdSeconds ?? 0}s'
        : '${logged.reps ?? 0} reps';
    final w = logged.weightKg;
    if (w == null) return main;
    return '$main × ${weightText(w, widget.units)} ${weightUnitLabel(widget.units)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColors.primary : AppColors.primaryDark;
    final n = widget.row.setNumber;
    if (_logged && !_editing) {
      return Semantics(
        button: true,
        label: 'Set $n logged, ${_summary()}. Tap to change.',
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            _main.text =
                (_isTime
                        ? widget.row.logged!.holdSeconds
                        : widget.row.logged!.reps)
                    ?.toString() ??
                '';
            _weight.text = weightText(
              widget.row.logged!.weightKg,
              widget.units,
            );
            setState(() => _editing = true);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: accent),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Set $n',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _summary(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final saving = widget.row.saving;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set $n',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NumberField(
                  controller: _main,
                  label: _isTime ? 'Seconds' : 'Reps',
                  decimal: false,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NumberField(
                  controller: _weight,
                  label: weightUnitLabel(widget.units),
                  decimal: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (!_logged)
                IconButton.filled(
                  tooltip: 'Log set $n',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: saving ? null : _log,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (_logged)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: saving ? null : _save,
                    child: const Text('Save'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: saving ? null : _remove,
                    child: const Text('Remove'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            _editing = false;
                            _error = null;
                          }),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.decimal,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp('[0-9.,]') : RegExp('[0-9]'),
        ),
      ],
      style: const TextStyle(fontFeatures: _tabular),
      decoration: InputDecoration(
        labelText: label,
        isDense: false,
        constraints: const BoxConstraints(minHeight: 48),
      ),
    );
  }
}
