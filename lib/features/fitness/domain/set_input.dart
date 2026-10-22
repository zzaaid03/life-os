/// Parsing, formatting and prefilling of the numbers in one logged set.
library;

import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

/// Most sets one exercise can log (the table allows set numbers 1-20).
const int kMaxSetsPerExercise = 20;

const int _maxReps = 200;
const int _maxHold = 3600;
const double _maxWeightKg = 1000;

/// The values of one set. Weight is kilograms.
class SetValues {
  /// Creates [SetValues].
  const SetValues({this.reps, this.weightKg, this.holdSeconds});

  final int? reps;
  final double? weightKg;
  final int? holdSeconds;
}

/// Either parsed [values] or an [error] to show the user.
class SetParseResult {
  const SetParseResult._(this.values, this.error);

  /// A good parse.
  const SetParseResult.ok(SetValues values) : this._(values, null);

  /// A rejected input with a message for the user.
  const SetParseResult.error(String error) : this._(null, error);

  final SetValues? values;
  final String? error;
}

/// Checks the typed text of a set against the table rules. A `reps` set needs
/// reps (1-200), a `time` set needs seconds (1-3600). Weight is optional, typed
/// in [units], stored as kilograms rounded to 2 decimals (0-1000).
SetParseResult parseSetInput({
  required String kind,
  required String reps,
  required String weight,
  required String hold,
  required UnitSystem units,
}) {
  final isTime = kind == 'time';
  int? repsValue;
  int? holdValue;
  if (isTime) {
    holdValue = int.tryParse(hold.trim());
    if (holdValue == null || holdValue < 1 || holdValue > _maxHold) {
      return const SetParseResult.error('Enter seconds from 1 to $_maxHold.');
    }
  } else {
    repsValue = int.tryParse(reps.trim());
    if (repsValue == null || repsValue < 1 || repsValue > _maxReps) {
      return const SetParseResult.error('Enter reps from 1 to $_maxReps.');
    }
  }
  double? kg;
  final weightText = weight.trim().replaceAll(',', '.');
  if (weightText.isNotEmpty) {
    final typed = double.tryParse(weightText);
    if (typed == null || !typed.isFinite || typed < 0) {
      return const SetParseResult.error('Enter a weight of 0 or more.');
    }
    final converted = units == UnitSystem.imperial ? lbToKg(typed) : typed;
    kg = double.parse(converted.toStringAsFixed(2));
    if (kg > _maxWeightKg) {
      return const SetParseResult.error('That weight is too high.');
    }
  }
  return SetParseResult.ok(
    SetValues(reps: repsValue, weightKg: kg, holdSeconds: holdValue),
  );
}

/// The unit label shown next to a weight.
String weightUnitLabel(UnitSystem units) =>
    units == UnitSystem.imperial ? 'lb' : 'kg';

/// A stored weight as text in [units]: kg up to 2 decimals, lb up to 1 (the
/// stored 0.01 kg step is finer than 0.1 lb, so a second lb decimal would only
/// show rounding noise). Trailing zeros are dropped. Null gives an empty string.
String weightText(double? kg, UnitSystem units) {
  if (kg == null) return '';
  final imperial = units == UnitSystem.imperial;
  final shown = imperial ? kgToLb(kg) : kg;
  var text = shown.toStringAsFixed(imperial ? 1 : 2);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

/// The starting values of the set at [index] (0-based) of an exercise.
///
/// Last time's sets win when there are any of the same [kind]: the set at the
/// same index, or the last one logged when this time has more sets. Without
/// history the plan fills in reps or hold; weight stays empty. [history] is
/// the previous session's sets for this exercise name, by set number.
SetValues prefillSet({
  required String kind,
  required int index,
  required List<LoggedSet> history,
  int? planReps,
  int? planHold,
}) {
  final usable = [
    for (final s in history)
      if (s.kind == kind) s,
  ];
  if (usable.isNotEmpty) {
    final s = usable[index < usable.length ? index : usable.length - 1];
    return SetValues(
      reps: s.reps,
      weightKg: s.weightKg,
      holdSeconds: s.holdSeconds,
    );
  }
  return kind == 'time'
      ? SetValues(holdSeconds: planHold)
      : SetValues(reps: planReps);
}
