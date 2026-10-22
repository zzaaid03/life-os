import 'dart:math' show max;

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
  sedentary('sedentary', 1.2, 'Sedentary', 'Desk job, little exercise'),
  light('light', 1.375, 'Lightly active', 'Exercise 1 to 3 days a week'),
  moderate(
    'moderate',
    1.55,
    'Moderately active',
    'Exercise 3 to 5 days a week',
  ),
  active('active', 1.725, 'Very active', 'Exercise 6 to 7 days a week'),
  veryActive(
    'very_active',
    1.9,
    'Extra active',
    'Hard training or a physical job',
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
  lose('lose', -500, 'Lose weight'),
  maintain('maintain', 0, 'Maintain'),
  gain('gain', 300, 'Gain weight');

  const CalorieGoal(this.dbValue, this.offsetKcal, this.label);

  /// The string stored in the database.
  final String dbValue;

  /// Calories added to (or taken from) maintenance each day.
  final int offsetKcal;
  final String label;

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

/// A daily target is never lower than this, whatever the goal says.
const int kMinDailyKcal = 1200;

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
  // The floor is a safety minimum: never suggest eating below it.
  return max(kMinDailyKcal, (raw + p.goal!.offsetKcal).round());
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
