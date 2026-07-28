/// The learning system's data model.
///
/// One row per durable fact the AI has inferred about the user from their
/// own data. Facts are generated server-side by the `infer-facts` Edge
/// Function and are read here only to be shown in Settings and fed back into
/// personalization.
///
/// Timestamps follow the store-UTC / display-local rule used everywhere else
/// in the app: parsed with `.toLocal()`, written as `.toUtc()`.
library;

import 'package:equatable/equatable.dart';

/// The four buckets a fact can fall into.
///
/// Deliberately a closed set. An open-ended "write whatever you noticed"
/// prompt drifts into filler ("is a productive person"); four named buckets
/// force the model to say something with a shape, and let the Settings
/// mirror group facts so a wrong one is easy to spot.
enum FactCategory {
  /// When the user actually does things. "Finishes most tasks in the evening."
  routine,

  /// How the user likes to work. "Breaks big goals into small steps."
  preference,

  /// What is currently true of their life. "Actively job hunting."
  situation,

  /// What they avoid or cannot do. "Rarely schedules anything on Fridays."
  constraint,
}

/// Parses the `category` column. Returns null for an unknown value rather
/// than throwing, so a future category added server-side cannot crash an old
/// client; such rows are simply skipped.
FactCategory? factCategoryFromDb(String? value) {
  switch (value) {
    case 'routine':
      return FactCategory.routine;
    case 'preference':
      return FactCategory.preference;
    case 'situation':
      return FactCategory.situation;
    case 'constraint':
      return FactCategory.constraint;
    default:
      return null;
  }
}

/// Encodes a [FactCategory] for the `category` column.
String factCategoryToDb(FactCategory value) {
  switch (value) {
    case FactCategory.routine:
      return 'routine';
    case FactCategory.preference:
      return 'preference';
    case FactCategory.situation:
      return 'situation';
    case FactCategory.constraint:
      return 'constraint';
  }
}

/// The heading each category gets in the Settings mirror.
String factCategoryLabel(FactCategory value) {
  switch (value) {
    case FactCategory.routine:
      return 'Your routine';
    case FactCategory.preference:
      return 'How you work';
    case FactCategory.situation:
      return "What's going on";
    case FactCategory.constraint:
      return 'What you avoid';
  }
}

/// A single inferred fact about the user.
class UserFact extends Equatable {
  /// Creates a [UserFact].
  const UserFact({
    required this.id,
    required this.userId,
    required this.category,
    required this.fact,
    required this.evidence,
    required this.factKey,
    required this.firstSeenAt,
    required this.lastConfirmedAt,
    this.suppressedAt,
  });

  /// Parses a [UserFact] from a `user_facts` row (snake_case).
  ///
  /// Throws [FormatException] on an unrecognised category so callers can skip
  /// the row; see [tryFromJson] for the non-throwing form used by the
  /// repository.
  factory UserFact.fromJson(Map<String, dynamic> json) {
    final category = factCategoryFromDb(json['category'] as String?);
    if (category == null) {
      throw FormatException('Unknown fact category: ${json['category']}');
    }
    return UserFact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: category,
      fact: json['fact'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      factKey: json['fact_key'] as String? ?? '',
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String).toLocal(),
      lastConfirmedAt: DateTime.parse(
        json['last_confirmed_at'] as String,
      ).toLocal(),
      suppressedAt: json['suppressed_at'] != null
          ? DateTime.parse(json['suppressed_at'] as String).toLocal()
          : null,
    );
  }

  /// Parses a row, returning null instead of throwing on a malformed one.
  static UserFact? tryFromJson(Map<String, dynamic> json) {
    try {
      return UserFact.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Row id.
  final String id;

  /// Owning user. Every query filters on this, and RLS enforces it.
  final String userId;

  /// Which bucket this fact belongs to.
  final FactCategory category;

  /// The fact itself, one short sentence, written to be read by the user.
  final String fact;

  /// What in the user's own data produced this fact.
  ///
  /// Never empty: the database rejects a blank one. This is the whole reason
  /// a wrong inference is diagnosable rather than just wrong, so the UI must
  /// always show it alongside [fact], not behind a tap.
  final String evidence;

  /// Normalised form of [fact], used server-side for deduplication only.
  final String factKey;

  /// When this fact was first inferred.
  final DateTime firstSeenAt;

  /// When the inference run last still found this to be true.
  final DateTime lastConfirmedAt;

  /// Set when the user rejected this fact.
  ///
  /// A suppressed fact is hidden from the mirror AND excluded from anything
  /// fed back to the AI, and the inference function never clears it, so a
  /// rejection is permanent.
  final DateTime? suppressedAt;

  /// Whether the user has rejected this fact.
  bool get isSuppressed => suppressedAt != null;

  /// Returns a copy with the given fields replaced.
  UserFact copyWith({
    String? id,
    String? userId,
    FactCategory? category,
    String? fact,
    String? evidence,
    String? factKey,
    DateTime? firstSeenAt,
    DateTime? lastConfirmedAt,
    DateTime? suppressedAt,
  }) {
    return UserFact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      fact: fact ?? this.fact,
      evidence: evidence ?? this.evidence,
      factKey: factKey ?? this.factKey,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      suppressedAt: suppressedAt ?? this.suppressedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    category,
    fact,
    evidence,
    factKey,
    firstSeenAt,
    lastConfirmedAt,
    suppressedAt,
  ];
}
