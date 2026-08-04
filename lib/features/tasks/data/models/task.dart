/// Task data model.
///
/// An actionable item with a due date, priority, and completion status.
/// Supports subtasks via [parentTaskId].
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// The priority level of a task.
enum TaskPriority { none, low, medium, high }

/// The workflow status of a task.
enum TaskStatus { pending, inProgress, completed, archived }

/// How often a task repeats.
///
/// Deliberately three fixed rules rather than an RRULE string. A full
/// recurrence grammar is a lot of surface to get wrong for a need nobody has
/// expressed. See `features/tasks/domain/recurrence.dart` for the date maths
/// and for what happens when a recurring task is completed.
enum Recurrence {
  /// Repeats one day after the previous due date.
  daily,

  /// Repeats seven days after the previous due date.
  weekly,

  /// Repeats one calendar month after the previous due date.
  monthly,
}

/// A task entity — an actionable item in Life OS.
class Task extends Equatable implements Entity {
  /// Creates a [Task].
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dueDate,
    this.completedAt,
    this.priority = TaskPriority.none,
    this.status = TaskStatus.pending,
    this.parentTaskId,
    this.goalId,
    this.recurrence,
    this.sortOrder = 0,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates a [Task] from a Supabase / Drift JSON response.
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String).toLocal()
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String).toLocal()
          : null,
      priority: _parsePriority(json['priority'] as int?),
      status: _parseStatus(json['status'] as String?),
      parentTaskId: json['parent_task_id'] as String?,
      goalId: json['goal_id'] as String?,
      recurrence: _parseRecurrence(json['recurrence'] as String?),
      sortOrder: (json['sort_order'] as num?)?.toDouble() ?? 0,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toLocal()
          : null,
      syncStatus: _parseSyncStatus(json['sync_status'] as String?),
      version: json['version'] as int? ?? 1,
    );
  }

  @override
  final String id;

  @override
  final String userId;

  /// The task title.
  final String title;

  /// Optional detailed description.
  final String? description;

  /// When the task is due, if applicable.
  final DateTime? dueDate;

  /// When the task was completed, if applicable.
  final DateTime? completedAt;

  /// The priority level.
  final TaskPriority priority;

  /// The current workflow status.
  final TaskStatus status;

  /// The ID of the parent task (for subtasks).
  final String? parentTaskId;

  /// The ID of the goal this task was generated for, if any.
  final String? goalId;

  /// How often this task repeats, or null if it does not.
  ///
  /// A completed task gives up its rule to the occurrence it spawns, so a row
  /// that is both completed and recurring should not exist.
  final Recurrence? recurrence;

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

  /// Converts this task to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'priority': priority.index,
      'status': _encodeStatus(status),
      'parent_task_id': parentTaskId,
      'goal_id': goalId,
      'recurrence': recurrence?.name,
      'sort_order': sortOrder,
      'synced_at': syncedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? completedAt,
    TaskPriority? priority,
    TaskStatus? status,
    String? parentTaskId,
    String? goalId,
    Recurrence? recurrence,
    double? sortOrder,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
    bool clearRecurrence = false,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      goalId: goalId ?? this.goalId,
      // Every other nullable field here uses the `?? this.x` idiom, which
      // cannot express "set this back to null". Recurrence has to: completing
      // a repeating task strips its rule, and that is the only thing stopping
      // an un-complete/re-complete from spawning a second occurrence.
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      sortOrder: sortOrder ?? this.sortOrder,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  static TaskStatus _parseStatus(String? value) {
    return switch (value) {
      'in_progress' => TaskStatus.inProgress,
      'completed' => TaskStatus.completed,
      'archived' => TaskStatus.archived,
      _ => TaskStatus.pending,
    };
  }

  static String _encodeStatus(TaskStatus status) {
    return switch (status) {
      TaskStatus.inProgress => 'in_progress',
      _ => status.name,
    };
  }

  /// Anything unrecognised (including null) means "does not repeat". This runs
  /// on every row read from Supabase and from Drift, so it must never throw.
  static Recurrence? _parseRecurrence(String? value) {
    return switch (value) {
      'daily' => Recurrence.daily,
      'weekly' => Recurrence.weekly,
      'monthly' => Recurrence.monthly,
      _ => null,
    };
  }

  static TaskPriority _parsePriority(int? index) {
    if (index == null || index < 0 || index >= TaskPriority.values.length) {
      return TaskPriority.none;
    }
    return TaskPriority.values[index];
  }

  static SyncStatus _parseSyncStatus(String? value) {
    return SyncStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SyncStatus.synced,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    description,
    dueDate,
    completedAt,
    priority,
    status,
    parentTaskId,
    goalId,
    recurrence,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
