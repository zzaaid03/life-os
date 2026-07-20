/// Attachment data model.
///
/// A file linked to any entity type (polymorphic relationship).
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/core/data/entity.dart';

/// An attachment entity — a file associated with any Life OS entity.
class Attachment extends Equatable implements Entity {
  /// Creates an [Attachment].
  const Attachment({
    required this.id,
    required this.userId,
    required this.entityType,
    required this.entityId,
    required this.fileName,
    this.fileSize = 0,
    this.mimeType = 'application/octet-stream',
    required this.storagePath,
    this.thumbnailPath,
    this.isUploaded = false,
    this.localPath,
    this.syncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
  });

  /// Creates an [Attachment] from a JSON response.
  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int? ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      storagePath: json['storage_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      isUploaded: json['is_uploaded'] as bool? ?? false,
      localPath: json['local_path'] as String?,
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

  /// The type of the parent entity ('task', 'note', 'goal').
  final String entityType;

  /// The ID of the parent entity.
  final String entityId;

  /// The original file name.
  final String fileName;

  /// File size in bytes.
  final int fileSize;

  /// The MIME type of the file.
  final String mimeType;

  /// The path in Supabase Storage.
  final String storagePath;

  /// Optional thumbnail path.
  final String? thumbnailPath;

  /// Whether the file has been uploaded to cloud storage.
  final bool isUploaded;

  /// Local file path for offline access.
  final String? localPath;

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

  /// Converts this attachment to a JSON map for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'entity_type': entityType,
      'entity_id': entityId,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'storage_path': storagePath,
      'thumbnail_path': thumbnailPath,
      'is_uploaded': isUploaded,
      'local_path': localPath,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'version': version,
    };
  }

  Attachment copyWith({
    String? id,
    String? userId,
    String? entityType,
    String? entityId,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? storagePath,
    String? thumbnailPath,
    bool? isUploaded,
    String? localPath,
    DateTime? syncedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    SyncStatus? syncStatus,
    int? version,
  }) {
    return Attachment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      storagePath: storagePath ?? this.storagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isUploaded: isUploaded ?? this.isUploaded,
      localPath: localPath ?? this.localPath,
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
    entityType,
    entityId,
    fileName,
    fileSize,
    mimeType,
    storagePath,
    isUploaded,
    createdAt,
    updatedAt,
    deletedAt,
    syncStatus,
    version,
  ];
}
