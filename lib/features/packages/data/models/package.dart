/// Package data model.
///
/// A tracked delivery, filled in from inbox scans and stored in the
/// `public.packages` table.
library;

import 'package:equatable/equatable.dart';

/// Where a package is on its way. The order of the values IS the forward
/// order: a package never moves to a lower [rank].
enum PackageStatus {
  ordered('ordered'),
  shipped('shipped'),
  outForDelivery('out_for_delivery'),
  delivered('delivered');

  const PackageStatus(this.dbValue);

  /// The string stored in the `status` column.
  final String dbValue;

  /// Position in the forward order, higher is further along.
  int get rank => index;

  /// Strictly parses a DB or model string, or null when unrecognised.
  static PackageStatus? tryParse(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim().toLowerCase();
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}

/// Formats a date-only value for a Postgres `date` column.
String _dateOnly(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// A single tracked package.
class Package extends Equatable {
  /// Creates a [Package].
  const Package({
    required this.id,
    this.merchant,
    this.item,
    this.carrier,
    this.trackingNumber,
    this.orderNumber,
    required this.status,
    this.expectedDate,
    this.deliveredAt,
    this.lastUpdate,
    this.sourceEmailId,
    this.lastEmailAt,
    this.deletedAt,
  });

  /// Parses a [Package] from a `packages` row (snake_case).
  factory Package.fromJson(Map<String, dynamic> json) {
    DateTime? ts(String key) {
      final raw = json[key];
      return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
    }

    DateTime? day(String key) {
      final raw = json[key];
      if (raw is! String) return null;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return Package(
      id: json['id'] as String,
      merchant: json['merchant'] as String?,
      item: json['item'] as String?,
      carrier: json['carrier'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      orderNumber: json['order_number'] as String?,
      // A stored status we do not know is shown as the earliest step rather
      // than throwing, so one odd row cannot break a whole list.
      status: PackageStatus.tryParse(json['status']) ?? PackageStatus.ordered,
      expectedDate: day('expected_date'),
      deliveredAt: ts('delivered_at'),
      lastUpdate: json['last_update'] as String?,
      sourceEmailId: json['source_email_id'] as String?,
      lastEmailAt: ts('last_email_at'),
      deletedAt: ts('deleted_at'),
    );
  }

  /// Row id. Empty for a package that has not been inserted yet.
  final String id;

  /// The shop or sender, e.g. "Amazon".
  final String? merchant;

  /// What was ordered, short.
  final String? item;

  /// The carrier, e.g. "DHL".
  final String? carrier;

  /// Normalized tracking number (uppercase, no spaces).
  final String? trackingNumber;

  /// Normalized order number (uppercase, no spaces).
  final String? orderNumber;

  /// Current status.
  final PackageStatus status;

  /// Expected delivery day at local midnight, or null.
  final DateTime? expectedDate;

  /// When the package first became delivered (UTC).
  final DateTime? deliveredAt;

  /// One-sentence summary of the latest email.
  final String? lastUpdate;

  /// The Gmail message id of the latest email.
  final String? sourceEmailId;

  /// When the latest email was applied (UTC).
  final DateTime? lastEmailAt;

  /// Soft-delete stamp. A deleted package still matches updates but is not
  /// revived.
  final DateTime? deletedAt;

  /// Whether the user deleted this package.
  bool get isDeleted => deletedAt != null;

  /// Returns a copy with the given overrides (nulls do not clear a field).
  Package copyWith({
    String? merchant,
    String? item,
    String? carrier,
    String? trackingNumber,
    String? orderNumber,
    PackageStatus? status,
    DateTime? expectedDate,
    DateTime? deliveredAt,
    String? lastUpdate,
    String? sourceEmailId,
    DateTime? lastEmailAt,
  }) {
    return Package(
      id: id,
      merchant: merchant ?? this.merchant,
      item: item ?? this.item,
      carrier: carrier ?? this.carrier,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      expectedDate: expectedDate ?? this.expectedDate,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      sourceEmailId: sourceEmailId ?? this.sourceEmailId,
      lastEmailAt: lastEmailAt ?? this.lastEmailAt,
      deletedAt: deletedAt,
    );
  }

  /// The columns a scan writes, shared by insert and update.
  Map<String, dynamic> toScanJson() {
    return {
      'merchant': merchant,
      'item': item,
      'carrier': carrier,
      'tracking_number': trackingNumber,
      'order_number': orderNumber,
      'status': status.dbValue,
      'expected_date': expectedDate == null ? null : _dateOnly(expectedDate!),
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'last_update': lastUpdate,
      'source_email_id': sourceEmailId,
      'last_email_at': lastEmailAt?.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    merchant,
    item,
    carrier,
    trackingNumber,
    orderNumber,
    status,
    expectedDate,
    deliveredAt,
    lastUpdate,
    sourceEmailId,
    lastEmailAt,
    deletedAt,
  ];
}
