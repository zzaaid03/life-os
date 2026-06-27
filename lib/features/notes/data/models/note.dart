/// Note data model.
///
/// A free-form note with optional pinning and color coding.
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// A note entity — free-form text with organizational metadata.
class Note extends Equatable implements Entity {
  /// Creates a [Note].
  const Note({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.isPinned = false,
    this.color,
    this.sortOrder = 0,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates a [Note] from a JSON response.
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      color: json['color'] as String?,
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

  /// The note title.
  final String title;

  /// The note content (supports rich text / Markdown in future).
  final String? content;

  /// Whether this note is pinned to the top.
  final bool isPinned;

  /// Optional hex color for visual grouping.
  final String? color;

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

  /// Converts this note to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'is_pinned': isPinned,
      'color': color,
      'sort_order': sortOrder,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    bool? isPinned,
    String? color,
    double? sortOrder,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      isPinned: isPinned ?? this.isPinned,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
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
    title,
    content,
    isPinned,
    color,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
