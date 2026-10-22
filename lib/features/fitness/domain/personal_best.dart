/// Which logged set is the better one, the rule behind "new personal best".
///
/// Sets are only compared within one exercise name and one kind. Reps sets: the
/// heavier weight wins and more reps break a tie (no weight counts as 0, so a
/// bodyweight exercise falls back to most reps). Time sets: longest hold.
library;

import 'package:life_os/features/fitness/domain/set_input.dart';
import 'package:life_os/features/fitness/domain/workout_session.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

/// Key that groups sets of the same exercise: exact name plus kind.
String setGroupKey(String exerciseName, String kind) => '$kind|$exerciseName';

/// Whether [a] strictly beats [b]. Both must be the same exercise and kind.
bool isBetterSet(LoggedSet a, LoggedSet b) {
  if (a.kind == 'time') {
    return (a.holdSeconds ?? 0) > (b.holdSeconds ?? 0);
  }
  final weightA = a.weightKg ?? 0;
  final weightB = b.weightKg ?? 0;
  if (weightA != weightB) return weightA > weightB;
  return (a.reps ?? 0) > (b.reps ?? 0);
}

/// The best of [sets] (one exercise and kind), or null when empty. On an exact
/// tie the first one wins.
LoggedSet? bestSet(Iterable<LoggedSet> sets) {
  LoggedSet? best;
  for (final s in sets) {
    if (best == null || isBetterSet(s, best)) best = s;
  }
  return best;
}

/// A set as short text: "62.5 kg × 8", "12 reps" or "75s".
String describeSet(LoggedSet s, UnitSystem units) {
  if (s.kind == 'time') return '${s.holdSeconds ?? 0}s';
  final reps = s.reps ?? 0;
  final weight = s.weightKg ?? 0;
  if (weight <= 0) return '$reps reps';
  return '${weightText(weight, units)} ${weightUnitLabel(units)} × $reps';
}
