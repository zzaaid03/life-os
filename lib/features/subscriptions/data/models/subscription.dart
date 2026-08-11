/// Subscription data model.
///
/// A recurring charge: a subscription, membership or regular bill. Persisted
/// in the `public.subscriptions` table (migration 018). Network-only, the
/// same deliberate choice made for goals and files: there is no Drift table
/// and no offline sync.
library;

import 'package:equatable/equatable.dart';

/// How often a [Subscription] is charged.
///
/// Mirrors the `subscriptions_cycle_check` constraint in migration 018. The
/// stored value is the [name] of the enum, so adding a case here without
/// widening that constraint will make writes fail.
enum BillingCycle {
  /// Charged every week.
  weekly,

  /// Charged every month.
  monthly,

  /// Charged every three months.
  quarterly,

  /// Charged once a year.
  yearly;

  /// Parses a stored cycle string, falling back to [monthly] on anything
  /// unrecognised rather than throwing on a row we can still mostly show.
  static BillingCycle parse(String? value) {
    return BillingCycle.values.firstWhere(
      (c) => c.name == (value ?? '').trim().toLowerCase(),
      orElse: () => BillingCycle.monthly,
    );
  }
}

/// Whether a [Subscription] is still being paid.
enum SubscriptionStatus {
  /// Still active and counted in the totals.
  active,

  /// Kept for history, excluded from every total.
  cancelled;

  /// Parses a stored status string, defaulting to [active].
  static SubscriptionStatus parse(String? value) {
    return SubscriptionStatus.values.firstWhere(
      (s) => s.name == (value ?? '').trim().toLowerCase(),
      orElse: () => SubscriptionStatus.active,
    );
  }
}

/// A single recurring charge.
class Subscription extends Equatable {
  /// Creates a [Subscription].
  const Subscription({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountCents,
    required this.currency,
    required this.cycle,
    this.nextChargeDate,
    this.status = SubscriptionStatus.active,
    this.notes,
    this.sourceEmailId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Parses a [Subscription] from a `subscriptions` row (snake_case).
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String? ?? 'USD').toUpperCase(),
      cycle: BillingCycle.parse(json['cycle'] as String?),
      // A DATE column comes back as `yyyy-mm-dd` with no zone. Parsing it as
      // local midnight keeps it on the day the user actually sees, which is
      // the same store-UTC/display-local discipline the rest of the app uses.
      nextChargeDate: json['next_charge_date'] != null
          ? DateTime.parse(json['next_charge_date'] as String)
          : null,
      status: SubscriptionStatus.parse(json['status'] as String?),
      notes: json['notes'] as String?,
      sourceEmailId: json['source_email_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toLocal()
          : null,
    );
  }

  /// Row id.
  final String id;

  /// Owner.
  final String userId;

  /// What the charge is for, e.g. `Netflix`.
  final String name;

  /// The charge, in the smallest unit of [currency].
  ///
  /// Integer cents on purpose: floating-point money produces totals like
  /// 30.299999999999997.
  final int amountCents;

  /// Three-letter uppercase ISO code. Never converted to another currency.
  final String currency;

  /// How often [amountCents] is charged.
  final BillingCycle cycle;

  /// The next expected charge, when known.
  final DateTime? nextChargeDate;

  /// Whether this is still being paid.
  final SubscriptionStatus status;

  /// Free-text note.
  final String? notes;

  /// The Gmail message id this row was derived from, if any.
  final String? sourceEmailId;

  /// When the row was created.
  final DateTime createdAt;

  /// When the row was last updated.
  final DateTime updatedAt;

  /// Soft-delete marker.
  final DateTime? deletedAt;

  /// Whether this subscription counts toward spending totals.
  bool get countsTowardTotals =>
      status == SubscriptionStatus.active && deletedAt == null;

  /// Serialises to a `subscriptions` row (snake_case).
  ///
  /// `id`, `created_at` and `updated_at` are omitted: the database owns them
  /// (defaults plus the `on_subscriptions_updated` trigger).
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'amount_cents': amountCents,
      'currency': currency.toUpperCase(),
      'cycle': cycle.name,
      'next_charge_date': nextChargeDate == null
          ? null
          : '${nextChargeDate!.year.toString().padLeft(4, '0')}-'
                '${nextChargeDate!.month.toString().padLeft(2, '0')}-'
                '${nextChargeDate!.day.toString().padLeft(2, '0')}',
      'status': status.name,
      'notes': notes,
      'source_email_id': sourceEmailId,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// Note the two explicit clear-flags: the `?? this.x` idiom cannot express
  /// "set this back to null", the same gap that hid a real bug in `Task`.
  Subscription copyWith({
    String? name,
    int? amountCents,
    String? currency,
    BillingCycle? cycle,
    DateTime? nextChargeDate,
    bool clearNextChargeDate = false,
    SubscriptionStatus? status,
    String? notes,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Subscription(
      id: id,
      userId: userId,
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      cycle: cycle ?? this.cycle,
      nextChargeDate: clearNextChargeDate
          ? null
          : (nextChargeDate ?? this.nextChargeDate),
      status: status ?? this.status,
      notes: notes ?? this.notes,
      sourceEmailId: sourceEmailId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    amountCents,
    currency,
    cycle,
    nextChargeDate,
    status,
    notes,
    sourceEmailId,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
