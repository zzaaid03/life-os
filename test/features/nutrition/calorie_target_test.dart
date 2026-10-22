import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';

void main() {
  final now = DateTime(2026, 10, 21);

  const male = CalorieProfile(
    weightKg: 80,
    heightCm: 180,
    birthYear: 1996,
    sex: Sex.male,
    activity: ActivityLevel.moderate,
    goal: CalorieGoal.maintain,
  );
  const female = CalorieProfile(
    weightKg: 60,
    heightCm: 165,
    birthYear: 2001,
    sex: Sex.female,
    activity: ActivityLevel.sedentary,
    goal: CalorieGoal.maintain,
  );

  group('calorie math', () {
    test('male worked example', () {
      expect(ageFromBirthYear(1996, now), 30);
      expect(
        bmrKcal(weightKg: 80, heightCm: 180, age: 30, sex: Sex.male),
        1780,
      );
      expect(maintenanceKcal(male, now: now), 2759);
      expect(dailyTargetKcal(male, now: now), 2759);
      int? t(CalorieGoal g) =>
          dailyTargetKcal(male.copyWith(goal: g), now: now);
      expect(t(CalorieGoal.loseSlow), 2484);
      expect(t(CalorieGoal.lose), 2209);
      expect(t(CalorieGoal.loseFast), 2069); // capped at 25% of maintenance
      expect(t(CalorieGoal.maintain), 2759);
      expect(t(CalorieGoal.gain), 3059);
    });

    test('female worked example and the deficit cap', () {
      expect(
        bmrKcal(weightKg: 60, heightCm: 165, age: 25, sex: Sex.female),
        closeTo(1345.25, 0.0001),
      );
      expect(maintenanceKcal(female, now: now), 1614);
      int? t(CalorieGoal g) =>
          dailyTargetKcal(female.copyWith(goal: g), now: now);
      expect(t(CalorieGoal.maintain), 1614);
      expect(t(CalorieGoal.loseSlow), 1339);
      expect(t(CalorieGoal.lose), 1211);
      expect(t(CalorieGoal.loseFast), 1211); // capped
    });

    test('men have a 1500 floor', () {
      const p = CalorieProfile(
        weightKg: 60,
        heightCm: 170,
        birthYear: 1986,
        sex: Sex.male,
        activity: ActivityLevel.sedentary,
        goal: CalorieGoal.loseFast,
      );
      expect(dailyTargetKcal(p, now: now), kMinDailyKcalMale);
      expect(kMinDailyKcalMale, 1500);
    });

    test('a target is never above maintenance', () {
      const p = CalorieProfile(
        weightKg: 45,
        heightCm: 150,
        birthYear: 1976,
        sex: Sex.female,
        activity: ActivityLevel.sedentary,
        goal: CalorieGoal.lose,
      );
      final target = dailyTargetKcal(p, now: now);
      expect(target, 1172);
      final maintenance = maintenanceKcal(p, now: now) as int;
      expect(target as int, lessThanOrEqualTo(maintenance));
    });

    test('null for incomplete or out-of-range profiles', () {
      expect(maintenanceKcal(const CalorieProfile(), now: now), isNull);
      expect(
        dailyTargetKcal(const CalorieProfile(weightKg: 80), now: now),
        isNull,
      );
      expect(dailyTargetKcal(male.copyWith(birthYear: 2014), now: now), isNull);
      expect(maintenanceKcal(male.copyWith(birthYear: 2014), now: now), isNull);
      expect(dailyTargetKcal(male.copyWith(weightKg: 19), now: now), isNull);
      expect(dailyTargetKcal(male.copyWith(heightCm: 99), now: now), isNull);
    });
  });

  group('rows', () {
    test('fromRow accepts numeric strings and nums', () {
      final p = CalorieProfile.fromRow({
        'weight_kg': '80.0',
        'height_cm': 180,
        'birth_year': '1996',
        'sex': 'male',
        'activity_level': 'very_active',
        'calorie_goal': 'gain',
        'unit_system': 'imperial',
      });
      expect(p.weightKg, 80.0);
      expect(p.heightCm, 180.0);
      expect(p.birthYear, 1996);
      expect(p.sex, Sex.male);
      expect(p.activity, ActivityLevel.veryActive);
      expect(p.goal, CalorieGoal.gain);
      expect(p.units, UnitSystem.imperial);
      expect(p.isComplete, isTrue);
    });

    test('fromRow turns bad values into null and defaults to metric', () {
      final p = CalorieProfile.fromRow({
        'weight_kg': 'abc',
        'height_cm': null,
        'birth_year': <String, dynamic>{},
        'sex': 'robot',
        'activity_level': 'robot',
        'calorie_goal': 'robot',
      });
      expect(p.weightKg, isNull);
      expect(p.heightCm, isNull);
      expect(p.birthYear, isNull);
      expect(p.sex, isNull);
      expect(p.activity, isNull);
      expect(p.goal, isNull);
      expect(p.units, UnitSystem.metric);
      expect(p.isComplete, isFalse);
    });

    test('toRow then fromRow round trips', () {
      final row = male.copyWith(units: UnitSystem.imperial).toRow();
      expect(row.keys, hasLength(7));
      final back = CalorieProfile.fromRow(row);
      expect(back.weightKg, 80);
      expect(back.heightCm, 180);
      expect(back.birthYear, 1996);
      expect(back.sex, Sex.male);
      expect(back.activity, ActivityLevel.moderate);
      expect(back.goal, CalorieGoal.maintain);
      expect(back.units, UnitSystem.imperial);
    });

    test('fromRow reads the new and the old loss values', () {
      expect(
        CalorieProfile.fromRow({'calorie_goal': 'lose_slow'}).goal,
        CalorieGoal.loseSlow,
      );
      expect(
        CalorieProfile.fromRow({'calorie_goal': 'lose'}).goal,
        CalorieGoal.lose,
      );
    });

    test('paceLabel', () {
      expect(CalorieGoal.lose.paceLabel(UnitSystem.imperial), '1 lb');
      expect(CalorieGoal.lose.paceLabel(UnitSystem.metric), '0.5 kg');
      expect(CalorieGoal.maintain.paceLabel(UnitSystem.metric), '');
    });

    test('fromDb never throws', () {
      expect(Sex.fromDb(null), isNull);
      expect(ActivityLevel.fromDb(42), isNull);
      expect(CalorieGoal.fromDb('x'), isNull);
      expect(UnitSystem.fromDb('x'), isNull);
    });
  });

  group('bmi', () {
    test('values and categories', () {
      expect(bmi(80, 180), 24.7);
      expect(BmiCategory.of(bmi(80, 180)), BmiCategory.healthy);
      expect(bmi(81, 180), 25.0);
      expect(BmiCategory.of(bmi(81, 180)), BmiCategory.overweight);
      expect(bmi(100, 180), 30.9);
      expect(BmiCategory.of(bmi(100, 180)), BmiCategory.obese);
      expect(bmi(55, 180), 17.0);
      expect(BmiCategory.of(bmi(55, 180)), BmiCategory.underweight);
    });

    test('healthy weight range', () {
      final r = healthyWeightRangeKg(180);
      expect(r.minKg, closeTo(59.94, 0.01));
      expect(r.maxKg, closeTo(80.68, 0.01));
    });
  });

  group('conversions', () {
    test('lb and kg', () {
      expect(lbToKg(180), closeTo(81.65, 0.01));
      expect(kgToLb(lbToKg(180)), closeTo(180, 0.0001));
    });

    test('feet and inches to cm', () {
      expect(feetInchesToCm(5, 11), closeTo(180.34, 0.01));
    });

    test('cm to feet and inches', () {
      expect(cmToFeetInches(180), (feet: 5, inches: 10.9));
      expect(cmToFeetInches(182.88), (feet: 6, inches: 0.0));
    });
  });

  group('percentOfDailyTarget', () {
    test('rounds down below .5', () {
      expect(percentOfDailyTarget(620, 2259), 27);
    });

    test('rounds up from .5', () {
      expect(percentOfDailyTarget(620, 2200), 28);
    });

    test('is at least 1 for a small positive amount', () {
      expect(percentOfDailyTarget(5, 2259), 1);
    });

    test('is 0 for no kcal', () {
      expect(percentOfDailyTarget(0, 2259), 0);
    });

    test('is 0 for no target', () {
      expect(percentOfDailyTarget(620, 0), 0);
    });

    test('is 100 when it is the whole target', () {
      expect(percentOfDailyTarget(2259, 2259), 100);
    });
  });
}
