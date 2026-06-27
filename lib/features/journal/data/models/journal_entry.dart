/// Journal Entry data model.
///
/// A timestamped personal journal entry with mood tracking.
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// A journal entry entity — a personal reflection in Life OS.
class JournalEntry extends Equatable implements Entity {
  /// Creates a [JournalEntry].
  const JournalEntry({
    required this.id,
    required this.userId,
    this.title,
    required this.content,
    this.mood,
    required this.entryDate,
    this.isFavorite = false,
    this.location,
    this.weather,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates a [JournalEntry] from a JSON response.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      content: json['content'] as String,
      mood: json['mood'] as String?,
      entryDate: DateTime.parse(json['entry_date'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      location: json['location'] as String?,
      weather: json['weather'] as String?,
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

  /// Optional title for the entry.
  final String? title;

  /// The entry content.
  final String content;

  /// The mood at the time of writing.
  final String? mood;

  /// The date this entry is associated with.
  final DateTime entryDate;

  /// Whether this entry is marked as a favorite.
  final bool isFavorite;

  /// Optional location where the entry was written.
  final String? location;

  /// Optional weather at the time of writing.
  final String? weather;

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

  /// Converts this journal entry to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'mood': mood,
      'entry_date': entryDate.toIso8601String().split('T').first,
      'is_favorite': isFavorite,
      'location': location,
      'weather': weather,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  JournalEntry copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? mood,
    DateTime? entryDate,
    bool? isFavorite,
    String? location,
    String? weather,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      entryDate: entryDate ?? this.entryDate,
      isFavorite: isFavorite ?? this.isFavorite,
      location: location ?? this.location,
      weather: weather ?? this.weather,
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
    mood,
    entryDate,
    isFavorite,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
