/// The questionnaire answers sent to the `workout-plan` function.
library;

/// A choice with its wire value and label.
class PlanChoice<T> {
  /// Creates a [PlanChoice].
  const PlanChoice(this.value, this.label);

  final T value;
  final String label;
}

const goalChoices = <PlanChoice<String>>[
  PlanChoice('muscle', 'Build muscle'),
  PlanChoice('strength', 'Get stronger'),
  PlanChoice('fat_loss', 'Lose fat'),
  PlanChoice('general', 'General fitness'),
  PlanChoice('skill', 'Learn a skill'),
];

const styleChoices = <PlanChoice<String>>[
  PlanChoice('gym', 'Gym'),
  PlanChoice('calisthenics', 'Calisthenics'),
  PlanChoice('mix', 'A mix'),
];

const equipmentChoices = <PlanChoice<String>>[
  PlanChoice('full_gym', 'Full gym'),
  PlanChoice('dumbbells', 'Dumbbells'),
  PlanChoice('bar_bodyweight', 'Pull-up bar'),
  PlanChoice('none', 'Nothing'),
];

const daysChoices = <PlanChoice<int>>[
  PlanChoice(2, '2'),
  PlanChoice(3, '3'),
  PlanChoice(4, '4'),
  PlanChoice(5, '5'),
  PlanChoice(6, '6'),
];

const minutesChoices = <PlanChoice<int>>[
  PlanChoice(30, '30'),
  PlanChoice(45, '45'),
  PlanChoice(60, '60'),
  PlanChoice(90, '90'),
];

const experienceChoices = <PlanChoice<String>>[
  PlanChoice('beginner', 'Beginner'),
  PlanChoice('intermediate', 'Intermediate'),
  PlanChoice('advanced', 'Advanced'),
];

/// Max length of the free-text limits answer.
const int kPlanLimitsMaxLength = 200;

/// The answers. Required ones are null until chosen.
class PlanInputs {
  /// Creates [PlanInputs].
  const PlanInputs({
    this.goal,
    this.style,
    this.equipment,
    this.daysPerWeek,
    this.sessionMinutes,
    this.experience,
    this.limits = '',
  });

  final String? goal;
  final String? style;
  final String? equipment;
  final int? daysPerWeek;
  final int? sessionMinutes;
  final String? experience;
  final String limits;

  /// Whether every required answer is chosen.
  bool get isComplete =>
      goal != null &&
      style != null &&
      equipment != null &&
      daysPerWeek != null &&
      sessionMinutes != null &&
      experience != null;

  /// Returns a copy with the given answers replaced.
  PlanInputs copyWith({
    String? goal,
    String? style,
    String? equipment,
    int? daysPerWeek,
    int? sessionMinutes,
    String? experience,
    String? limits,
  }) {
    return PlanInputs(
      goal: goal ?? this.goal,
      style: style ?? this.style,
      equipment: equipment ?? this.equipment,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      experience: experience ?? this.experience,
      limits: limits ?? this.limits,
    );
  }

  /// The request body's `inputs` object. Only call when [isComplete].
  Map<String, dynamic> toJson() {
    final trimmed = limits.trim();
    return {
      'goal': goal,
      'style': style,
      'equipment': equipment,
      'days_per_week': daysPerWeek,
      'session_minutes': sessionMinutes,
      'experience': experience,
      if (trimmed.isNotEmpty) 'limits': trimmed,
    };
  }
}
