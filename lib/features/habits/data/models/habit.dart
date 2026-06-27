/// Habit data model.
///
/// A recurring behavior with frequency configuration.
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// The frequency type of a habit.
enum HabitFrequency { daily, weekly, monthly, custom }

/// A habit entity — a recurring behavior in Life OS.
class Habit extends Equatable implements Entity {
  /// Creates a [Habit].
  const Habit({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.frequencyType = HabitFrequency.daily,
    this.frequencyConfig,
    this.color,
    this.icon,
    this.targetCount = 1,
    this.isArchived = false,
    this.sortOrder = 0,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates a [Habit] from a JSON response.
  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      frequencyType: _parseFrequency(json['frequency_type'] as String?),
      frequencyConfig: json['frequency_config'] as Map<String, dynamic>?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      targetCount: json['target_count'] as int? ?? 1,
      isArchived: json['is_archived'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toDouble() ?? 0,
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

  /// The habit name.
  final String name;

  /// Optional description.
  final String? description;

  /// The frequency type.
  final HabitFrequency frequencyType;

  /// JSON configuration for frequency (e.g., {"days": [1,3,5]} for weekly).
  final Map<String, dynamic>? frequencyConfig;

  /// Optional hex color for visual display.
  final String? color;

  /// Optional icon identifier.
  final String? icon;

  /// Target count per period.
  final int targetCount;

  /// Whether this habit is archived.
  final bool isArchived;

  /// Sort ordering within a list.
  final double sortOrder;

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

  /// Converts this habit to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'frequency_type': frequencyType.name,
      'frequency_config': frequencyConfig,
      'color': color,
      'icon': icon,
      'target_count': targetCount,
      'is_archived': isArchived,
      'sort_order': sortOrder,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  Habit copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    HabitFrequency? frequencyType,
    Map<String, dynamic>? frequencyConfig,
    String? color,
    String? icon,
    int? targetCount,
    bool? isArchived,
    double? sortOrder,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
  }) {
    return Habit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      targetCount: targetCount ?? this.targetCount,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  static HabitFrequency _parseFrequency(String? value) {
    return switch (value) {
      'weekly' => HabitFrequency.weekly,
      'monthly' => HabitFrequency.monthly,
      'custom' => HabitFrequency.custom,
      _ => HabitFrequency.daily,
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    description,
    frequencyType,
    targetCount,
    isArchived,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
