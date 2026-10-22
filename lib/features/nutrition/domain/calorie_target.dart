import 'dart:math' show max, min;

/// Biological sex used by the Mifflin-St Jeor formula.
enum Sex {
  male('male'),
  female('female');

  const Sex(this.dbValue);

  /// The string stored in the database.
  final String dbValue;

  /// Returns null for null or unknown values. Never throws.
  static Sex? fromDb(Object? v) {
    for (final s in values) {
      if (s.dbValue == v) return s;
    }
    return null;
  }
}

/// How active the user is in a normal week.
enum ActivityLevel {
  sedentary('sedentary', 1.2, 'Sedentary', 'Under 5,000 steps a day'),
  light('light', 1.375, 'Lightly active', '5,000 to 7,500 steps a day'),
  moderate('moderate', 1.55, 'Moderately active', '7,500 to 10,000 steps a day'),
  active('active', 1.725, 'Very active', '10,000 to 12,500 steps a day'),
  veryActive(
    'very_active',
    1.9,
    'Extra active',
    'Over 12,500 steps a day, or a physical job',
  );

  const ActivityLevel(this.dbValue, this.factor, this.label, this.description);

  /// The string stored in the database.
  final String dbValue;

  /// Multiplier applied to BMR to get maintenance calories.
  final double factor;
  final String label;
  final String description;

  /// Returns null for null or unknown values. Never throws.
  static ActivityLevel? fromDb(Object? v) {
    for (final a in values) {
      if (a.dbValue == v) return a;
    }
    return null;
  }
}

/// What the user wants to do with their weight.
enum CalorieGoal {
  loseSlow('lose_slow', 'Lose 0.25 kg a week', 0.25),
  lose('lose', 'Lose 0.5 kg a week', 0.5),
  loseFast('lose_fast', 'Lose 0.75 kg a week', 0.75),
  maintain('maintain', 'Maintain', 0),
  gain('gain', 'Gain weight', 0);

  const CalorieGoal(this.dbValue, this.label, this.lossKgPerWeek);

  /// The string stored in the database.
  final String dbValue;
  final String label;

  /// Target weight loss per week in kg. 0 for maintain and gain.
  final double lossKgPerWeek;

  bool get isLoss => lossKgPerWeek > 0;

  /// Short pace text for the loss goals, empty for the others. The imperial
  /// numbers are rounded on purpose (0.25 kg is 0.55 lb, shown as 0.5 lb).
  String paceLabel(UnitSystem u) {
    if (!isLoss) return '';
    final metric = u == UnitSystem.metric;
    return switch (this) {
      CalorieGoal.loseSlow => metric ? '0.25 kg' : '0.5 lb',
      CalorieGoal.lose => metric ? '0.5 kg' : '1 lb',
      CalorieGoal.loseFast => metric ? '0.75 kg' : '1.5 lb',
      _ => '',
    };
  }

  /// Returns null for null or unknown values. Never throws.
  static CalorieGoal? fromDb(Object? v) {
    for (final g in values) {
      if (g.dbValue == v) return g;
    }
    return null;
  }
}

/// Which units the user sees. Values are always stored metric.
enum UnitSystem {
  metric('metric', 'Metric'),
  imperial('imperial', 'Imperial');

  const UnitSystem(this.dbValue, this.label);

  /// The string stored in the database.
  final String dbValue;
  final String label;

  /// Returns null for null or unknown values. Never throws.
  static UnitSystem? fromDb(Object? v) {
    for (final u in values) {
      if (u.dbValue == v) return u;
    }
    return null;
  }
}

/// Energy in one kg of body fat, the usual rule of thumb.
const int kKcalPerKgFat = 7700;

/// A deficit never exceeds this share of maintenance, so a heavy pace on a
/// small person does not turn into crash dieting.
const double kMaxDeficitShare = 0.25;

/// Safety floors: a loss target is never set below these (and never above
/// maintenance, for people whose maintenance is already under the floor).
const int kMinDailyKcalMale = 1500;
const int kMinDailyKcalFemale = 1200;

const int kGainSurplusKcal = 300;

const double kMinWeightKg = 20;
const double kMaxWeightKg = 400;
const double kMinHeightCm = 100;
const double kMaxHeightCm = 250;
const int kMinAge = 13;
const int kMaxAge = 100;

bool isValidWeightKg(double kg) => kg >= kMinWeightKg && kg <= kMaxWeightKg;
bool isValidHeightCm(double cm) => cm >= kMinHeightCm && cm <= kMaxHeightCm;
bool isValidAge(int age) => age >= kMinAge && age <= kMaxAge;

/// Age in years from the birth year only. Approximate by design: we only
/// store the year, so it can be off by one before the birthday.
int ageFromBirthYear(int birthYear, DateTime now) => now.year - birthYear;

/// Basal metabolic rate in kcal per day (Mifflin-St Jeor).
double bmrKcal({
  required double weightKg,
  required double heightCm,
  required int age,
  required Sex sex,
}) {
  return 10 * weightKg +
      6.25 * heightCm -
      5 * age +
      (sex == Sex.male ? 5 : -161);
}

/// The body details and preferences the calorie target is built from.
class CalorieProfile {
  const CalorieProfile({
    this.weightKg,
    this.heightCm,
    this.birthYear,
    this.sex,
    this.activity,
    this.goal,
    this.units = UnitSystem.metric,
  });

  /// Reads a profiles row. Tolerant: bad values become null, never throws.
  factory CalorieProfile.fromRow(Map<String, dynamic> row) {
    return CalorieProfile(
      weightKg: _toDouble(row['weight_kg']),
      heightCm: _toDouble(row['height_cm']),
      birthYear: _toInt(row['birth_year']),
      sex: Sex.fromDb(row['sex']),
      activity: ActivityLevel.fromDb(row['activity_level']),
      goal: CalorieGoal.fromDb(row['calorie_goal']),
      units: UnitSystem.fromDb(row['unit_system']) ?? UnitSystem.metric,
    );
  }

  final double? weightKg;
  final double? heightCm;
  final int? birthYear;
  final Sex? sex;
  final ActivityLevel? activity;
  final CalorieGoal? goal;
  final UnitSystem units;

  Map<String, dynamic> toRow() => {
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'birth_year': birthYear,
    'sex': sex?.dbValue,
    'activity_level': activity?.dbValue,
    'calorie_goal': goal?.dbValue,
    'unit_system': units.dbValue,
  };

  CalorieProfile copyWith({
    double? weightKg,
    double? heightCm,
    int? birthYear,
    Sex? sex,
    ActivityLevel? activity,
    CalorieGoal? goal,
    UnitSystem? units,
  }) {
    return CalorieProfile(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      birthYear: birthYear ?? this.birthYear,
      sex: sex ?? this.sex,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
      units: units ?? this.units,
    );
  }

  /// True when all six inputs are set.
  bool get isComplete =>
      weightKg != null &&
      heightCm != null &&
      birthYear != null &&
      sex != null &&
      activity != null &&
      goal != null;
}

/// Supabase returns NUMERIC as a num or a String, so accept both.
double? _toDouble(Object? v) {
  final d = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
  return (d != null && d.isFinite) ? d : null;
}

int? _toInt(Object? v) => _toDouble(v)?.toInt();

/// Calories needed to stay at the same weight, or null if the profile is
/// incomplete or any value is out of range.
int? maintenanceKcal(CalorieProfile p, {required DateTime now}) {
  final raw = _rawMaintenance(p, now);
  return raw?.round();
}

/// Daily calorie target for the user's goal, or null if the profile is
/// incomplete or any value is out of range.
int? dailyTargetKcal(CalorieProfile p, {required DateTime now}) {
  final raw = _rawMaintenance(p, now);
  if (raw == null) return null;
  final goal = p.goal!;
  if (goal == CalorieGoal.gain) return (raw + kGainSurplusKcal).round();
  if (!goal.isLoss) return raw.round();
  // Cap the deficit and respect the sex-specific floor, but never end up
  // above maintenance.
  final deficit = min(
    goal.lossKgPerWeek * kKcalPerKgFat / 7,
    kMaxDeficitShare * raw,
  );
  final floor = p.sex! == Sex.male ? kMinDailyKcalMale : kMinDailyKcalFemale;
  return min(raw, max(floor.toDouble(), raw - deficit)).round();
}

/// BMR times the activity factor, before rounding. Null if not usable.
double? _rawMaintenance(CalorieProfile p, DateTime now) {
  if (!p.isComplete) return null;
  final age = ageFromBirthYear(p.birthYear!, now);
  if (!isValidWeightKg(p.weightKg!) ||
      !isValidHeightCm(p.heightCm!) ||
      !isValidAge(age)) {
    return null;
  }
  final bmr = bmrKcal(
    weightKg: p.weightKg!,
    heightCm: p.heightCm!,
    age: age,
    sex: p.sex!,
  );
  return bmr * p.activity!.factor;
}

/// Share of the daily target that [kcal] covers, rounded, at least 1 when [kcal] > 0.
int percentOfDailyTarget(int kcal, int targetKcal) {
  if (kcal <= 0 || targetKcal <= 0) return 0;
  return max(1, (kcal * 100 / targetKcal).round());
}

/// Body mass index, rounded to 1 decimal.
double bmi(double weightKg, double heightCm) {
  final m = heightCm / 100;
  return (weightKg / (m * m) * 10).round() / 10;
}

enum BmiCategory {
  underweight('Underweight'),
  healthy('Healthy'),
  overweight('Overweight'),
  obese('Obese');

  const BmiCategory(this.label);

  final String label;

  static BmiCategory of(double bmi) {
    if (bmi < 18.5) return underweight;
    if (bmi < 25) return healthy;
    if (bmi < 30) return overweight;
    return obese;
  }
}

/// Weights that give a BMI of 18.5 to 24.9 at this height.
({double minKg, double maxKg}) healthyWeightRangeKg(double heightCm) {
  final m = heightCm / 100;
  return (minKg: 18.5 * m * m, maxKg: 24.9 * m * m);
}

const double _kgPerLb = 0.45359237;
const double _cmPerInch = 2.54;

double lbToKg(double lb) => lb * _kgPerLb;
double kgToLb(double kg) => kg / _kgPerLb;

double feetInchesToCm(int feet, double inches) =>
    (feet * 12 + inches) * _cmPerInch;

/// Splits centimetres into feet and inches (inches rounded to 1 decimal).
({int feet, double inches}) cmToFeetInches(double cm) {
  final totalInches = cm / _cmPerInch;
  var feet = totalInches ~/ 12;
  var inches = ((totalInches - feet * 12) * 10).round() / 10;
  // 11.96 inches rounds to 12.0, which is one more foot.
  if (inches >= 12) {
    feet += 1;
    inches = 0;
  }
  return (feet: feet, inches: inches);
}
