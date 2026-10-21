/// Screen for setting the personal daily calorie target.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/number_format.dart';
import 'package:life_os/features/nutrition/domain/calorie_providers.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

/// Full screen titled "Daily calories". Shows a live result as the user types.
class CalorieTargetScreen extends ConsumerWidget {
  /// Creates a [CalorieTargetScreen].
  const CalorieTargetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calorieProfileProvider);
    final Widget body;
    if (!state.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.loadFailed) {
      // Never show an empty form here: saving it would overwrite real data.
      body = Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Couldn't load your details, so they can't be edited right now.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () =>
                    ref.read(calorieProfileProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = _CalorieForm(initial: state.profile);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily calories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: body,
    );
  }
}

class _CalorieForm extends ConsumerStatefulWidget {
  const _CalorieForm({required this.initial});

  final CalorieProfile initial;

  @override
  ConsumerState<_CalorieForm> createState() => _CalorieFormState();
}

class _CalorieFormState extends ConsumerState<_CalorieForm> {
  final _weight = TextEditingController();
  final _heightCm = TextEditingController();
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _birthYear = TextEditingController();
  late UnitSystem _units;
  Sex? _sex;
  ActivityLevel? _activity;
  CalorieGoal? _goal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _units = p.units;
    _sex = p.sex;
    _activity = p.activity;
    _goal = p.goal;
    _birthYear.text = p.birthYear?.toString() ?? '';
    _fillMeasurements(p.weightKg, p.heightCm);
  }

  @override
  void dispose() {
    _weight.dispose();
    _heightCm.dispose();
    _feet.dispose();
    _inches.dispose();
    _birthYear.dispose();
    super.dispose();
  }

  /// Puts metric values into the fields of the current unit system.
  void _fillMeasurements(double? kg, double? cm) {
    if (_units == UnitSystem.metric) {
      _weight.text = kg == null ? '' : _trim(kg);
      _heightCm.text = cm == null ? '' : _trim(cm);
      _feet.text = '';
      _inches.text = '';
    } else {
      _weight.text = kg == null ? '' : _trim(kgToLb(kg));
      _heightCm.text = '';
      if (cm == null) {
        _feet.text = '';
        _inches.text = '';
      } else {
        final fi = cmToFeetInches(cm);
        _feet.text = fi.feet.toString();
        _inches.text = _trim(fi.inches);
      }
    }
  }

  /// One decimal at most, no trailing ".0".
  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static double? _num(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  double? get _weightKg {
    final v = _num(_weight.text);
    if (v == null) return null;
    return _units == UnitSystem.metric ? v : lbToKg(v);
  }

  double? get _heightInCm {
    if (_units == UnitSystem.metric) return _num(_heightCm.text);
    final feet = int.tryParse(_feet.text.trim());
    if (feet == null) return null;
    final inches = _inches.text.trim().isEmpty ? 0.0 : _num(_inches.text);
    if (inches == null) return null;
    return feetInchesToCm(feet, inches);
  }

  int? get _year => int.tryParse(_birthYear.text.trim());

  /// Built with the constructor (not copyWith) so a cleared field stays null.
  CalorieProfile _profile() => CalorieProfile(
    weightKg: _weightKg,
    heightCm: _heightInCm,
    birthYear: _year,
    sex: _sex,
    activity: _activity,
    goal: _goal,
    units: _units,
  );

  void _setUnits(UnitSystem next) {
    if (next == _units) return;
    // Convert what is typed so far; keep unreadable text as it is.
    final kg = _weightKg;
    final cm = _heightInCm;
    setState(() {
      _units = next;
      if (kg != null || cm != null) {
        _fillMeasurements(kg, cm);
      }
    });
  }

  String? _weightError() {
    if (_weight.text.trim().isEmpty) return null;
    final kg = _weightKg;
    if (kg != null && isValidWeightKg(kg)) return null;
    return _units == UnitSystem.metric
        ? 'Enter ${kMinWeightKg.round()} to ${kMaxWeightKg.round()} kg'
        : 'Enter ${kgToLb(kMinWeightKg).round()} to '
              '${kgToLb(kMaxWeightKg).round()} lb';
  }

  String? _heightError() {
    final empty = _units == UnitSystem.metric
        ? _heightCm.text.trim().isEmpty
        : _feet.text.trim().isEmpty && _inches.text.trim().isEmpty;
    if (empty) return null;
    final cm = _heightInCm;
    if (cm != null && isValidHeightCm(cm)) return null;
    if (_units == UnitSystem.metric) {
      return 'Enter ${kMinHeightCm.round()} to ${kMaxHeightCm.round()} cm';
    }
    final lo = cmToFeetInches(kMinHeightCm);
    final hi = cmToFeetInches(kMaxHeightCm);
    return 'Enter ${lo.feet} ft ${_trim(lo.inches)} in to '
        '${hi.feet} ft ${_trim(hi.inches)} in';
  }

  String? _yearError() {
    if (_birthYear.text.trim().isEmpty) return null;
    final year = _year;
    final now = DateTime.now();
    if (year != null && isValidAge(ageFromBirthYear(year, now))) return null;
    return 'Age must be $kMinAge to $kMaxAge '
        '(born ${now.year - kMaxAge} to ${now.year - kMinAge})';
  }

  bool get _hasError =>
      _weightError() != null || _heightError() != null || _yearError() != null;

  Future<void> _save() async {
    if (_saving || _hasError) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(calorieProfileProvider.notifier).save(_profile());
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text("Couldn't save your daily calories. ($e)"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metric = _units == UnitSystem.metric;
    final digits = FilteringTextInputFormatter.allow(RegExp('[0-9.,]'));
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        SegmentedButton<UnitSystem>(
          segments: [
            for (final u in UnitSystem.values)
              ButtonSegment(value: u, label: Text(u.label)),
          ],
          selected: {_units},
          onSelectionChanged: (s) => _setUnits(s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [digits],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: metric ? 'Weight (kg)' : 'Weight (lb)',
            errorText: _weightError(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (metric)
          TextField(
            controller: _heightCm,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [digits],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Height (cm)',
              errorText: _heightError(),
              border: const OutlineInputBorder(),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _feet,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Height (ft)',
                    errorText: _heightError(),
                    errorMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _inches,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [digits],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Height (in)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _birthYear,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Birth year',
            errorText: _yearError(),
            errorMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<Sex>(
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: Sex.male, label: Text('Male')),
            ButtonSegment(value: Sex.female, label: Text('Female')),
          ],
          selected: {?_sex},
          onSelectionChanged: (s) =>
              setState(() => _sex = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<ActivityLevel>(
          initialValue: _activity,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Activity level',
            border: OutlineInputBorder(),
          ),
          selectedItemBuilder: (_) => [
            for (final a in ActivityLevel.values) Text(a.label),
          ],
          items: [
            for (final a in ActivityLevel.values)
              DropdownMenuItem(
                value: a,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.label),
                    Text(
                      a.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (a) => setState(() => _activity = a),
        ),
        const SizedBox(height: AppSpacing.lg),
        SegmentedButton<CalorieGoal>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final g in CalorieGoal.values)
              ButtonSegment(value: g, label: Text(g.label)),
          ],
          selected: {?_goal},
          onSelectionChanged: (s) =>
              setState(() => _goal = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ResultCard(profile: _profile(), hasError: _hasError),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: (_saving || _hasError) ? null : _save,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.profile, required this.hasError});

  final CalorieProfile profile;
  final bool hasError;

  /// What is still missing, as a short sentence.
  String _hint() {
    if (hasError) return 'Fix the highlighted fields to see your target.';
    final missing = <String>[
      if (profile.weightKg == null) 'weight',
      if (profile.heightCm == null) 'height',
      if (profile.birthYear == null) 'birth year',
      if (profile.sex == null) 'sex',
      if (profile.activity == null) 'activity level',
      if (profile.goal == null) 'goal',
    ];
    if (missing.isEmpty) return 'Check the values above.';
    return 'Still needed: ${missing.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final now = DateTime.now();
    final target = dailyTargetKcal(profile, now: now);
    final maintenance = maintenanceKcal(profile, now: now);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: target == null || maintenance == null
          ? Text(_hint(), style: theme.textTheme.bodyMedium)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatThousands(target)} kcal a day',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Maintenance ${formatThousands(maintenance)} kcal',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Estimate from the Mifflin-St Jeor formula. Not medical advice.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
    );
  }
}
