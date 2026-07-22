/// Goal data model.
///
/// A long-term objective with progress tracking.
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// The workflow status of a goal.
enum GoalStatus { active, completed, archived, paused }

/// A goal entity — a long-term objective in Life OS.
class Goal extends Equatable implements Entity {
  /// Creates a [Goal].
  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.targetDate,
    this.progress = 0,
    this.status = GoalStatus.active,
    this.category,
    this.sortOrder = 0,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates a [Goal] from a JSON response.
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String).toLocal()
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      status: _parseStatus(json['status'] as String?),
      category: json['category'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toDouble() ?? 0,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toLocal()
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

  /// The goal title.
  final String title;

  /// Optional detailed description.
  final String? description;

  /// The target date for completion, if applicable.
  final DateTime? targetDate;

  /// Progress from 0.0 to 1.0.
  final double progress;

  /// The current workflow status.
  final GoalStatus status;

  /// Optional category for grouping.
  final String? category;

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

  /// Converts this goal to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'target_date': targetDate?.toUtc().toIso8601String(),
      'progress': progress,
      'status': status.name,
      'category': category,
      'sort_order': sortOrder,
      'synced_at': syncedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  Goal copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? targetDate,
    double? progress,
    GoalStatus? status,
    String? category,
    double? sortOrder,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  static GoalStatus _parseStatus(String? value) {
    return switch (value) {
      'completed' => GoalStatus.completed,
      'archived' => GoalStatus.archived,
      'paused' => GoalStatus.paused,
      _ => GoalStatus.active,
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    description,
    targetDate,
    progress,
    status,
    category,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
