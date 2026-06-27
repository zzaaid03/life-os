/// Habit Entry data model.
///
/// Records a single completion of a habit on a specific date.
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// A habit entry — records a habit completion on a given date.
class HabitEntry extends Equatable implements Entity {
  /// Creates a [HabitEntry].
  const HabitEntry({
    required this.id,
    required this.userId,
    required this.habitId,
    required this.completedDate,
    this.count = 1,
    this.notes,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates a [HabitEntry] from a JSON response.
  factory HabitEntry.fromJson(Map<String, dynamic> json) {
    return HabitEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      habitId: json['habit_id'] as String,
      completedDate: DateTime.parse(json['completed_date'] as String),
      count: json['count'] as int? ?? 1,
      notes: json['notes'] as String?,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      syncStatus: SyncStatus.values.firstWhere(
        (s) => s.name == json['sync_status'],
        orElse: () => SyncStatus.synced,
      ),
      version: json['version'] as int? ?? 1,
    );
  }

  @override
  final String id;

  @override
  final String userId;

  /// The ID of the parent habit.
  final String habitId;

  /// The date this habit was completed.
  final DateTime completedDate;

  /// How many times the habit was completed on this date.
  final int count;

  /// Optional notes about this completion.
  final String? notes;

  /// When this entity was last synced with the server.
  final DateTime? syncedAt;

  @override
  final DateTime createdAt;

  @override
  final DateTime updatedAt;

  @override
  final DateTime? deletedAt;

  @override
  final SyncStatus syncStatus;

  @override
  final int version;

  /// Converts this habit entry to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'habit_id': habitId,
      'completed_date': completedDate.toIso8601String().split('T').first,
      'count': count,
      'notes': notes,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  HabitEntry copyWith({
    String? id,
    String? userId,
    String? habitId,
    DateTime? completedDate,
    int? count,
    String? notes,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
  }) {
    return HabitEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      habitId: habitId ?? this.habitId,
      completedDate: completedDate ?? this.completedDate,
      count: count ?? this.count,
      notes: notes ?? this.notes,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    habitId,
    completedDate,
    count,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
