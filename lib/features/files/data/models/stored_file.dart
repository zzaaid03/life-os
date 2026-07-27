/// Stored file data model.
///
/// One row per uploaded file, persisted in the `public.user_files` table.
/// The file bytes themselves live in the `user-files` Supabase Storage
/// bucket at [storagePath]; this row is only the metadata.
///
/// Timestamps follow the store-UTC / display-local rule used everywhere
/// else in the app: parsed values are converted with `.toLocal()` on read
/// and written back as `.toUtc().toIso8601String()`.
library;

import 'package:equatable/equatable.dart';

/// What a file is attached to, if anything.
enum FileAttachmentType {
  /// Attached to a task.
  task,

  /// Attached to a job application.
  jobApplication,
}

/// Parses the `attached_entity_type` column, which is null for a loose file.
FileAttachmentType? fileAttachmentTypeFromDb(String? value) {
  switch (value) {
    case 'task':
      return FileAttachmentType.task;
    case 'job_application':
      return FileAttachmentType.jobApplication;
    default:
      return null;
  }
}

/// Encodes a [FileAttachmentType] for the `attached_entity_type` column.
String? fileAttachmentTypeToDb(FileAttachmentType? value) {
  switch (value) {
    case FileAttachmentType.task:
      return 'task';
    case FileAttachmentType.jobApplication:
      return 'job_application';
    case null:
      return null;
  }
}

/// A single stored file's metadata.
class StoredFile extends Equatable {
  /// Creates a [StoredFile].
  const StoredFile({
    required this.id,
    required this.userId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.isPrivate,
    this.aiLabel,
    this.attachedEntityType,
    this.attachedEntityId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Parses a [StoredFile] from a `user_files` row (snake_case).
  factory StoredFile.fromJson(Map<String, dynamic> json) {
    return StoredFile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
      aiLabel: json['ai_label'] as String?,
      attachedEntityType: fileAttachmentTypeFromDb(
        json['attached_entity_type'] as String?,
      ),
      attachedEntityId: json['attached_entity_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toLocal()
          : null,
    );
  }

  /// Row id.
  final String id;

  /// Owning user. Every query filters on this, and RLS enforces it.
  final String userId;

  /// Path of the object inside the `user-files` bucket.
  ///
  /// Always `<userId>/<uuid><extension>`. The leading user-id folder is what
  /// the Storage bucket policies match on, so it is not cosmetic.
  final String storagePath;

  /// The original file name, shown to the user.
  final String fileName;

  /// MIME type as detected at upload time.
  final String mimeType;

  /// Size of the stored object in bytes, after any client-side re-encode.
  final int sizeBytes;

  /// When true the file is never sent to the AI for labelling or search.
  final bool isPrivate;

  /// AI-generated label. Always null until slice 2b; never set for a file
  /// where [isPrivate] is true.
  final String? aiLabel;

  /// What this file is attached to, or null if it stands alone.
  final FileAttachmentType? attachedEntityType;

  /// Id of the attached task or job application, or null.
  final String? attachedEntityId;

  /// When the row was created.
  final DateTime createdAt;

  /// When the row was last updated.
  final DateTime updatedAt;

  /// Soft-delete marker. Non-null means deleted and hidden from all lists.
  final DateTime? deletedAt;

  /// True when this file is an image, which is what list views show a
  /// thumbnail for rather than a generic icon.
  bool get isImage => mimeType.startsWith('image/');

  /// Serializes to a `user_files` row (snake_case).
  ///
  /// `created_at` / `updated_at` are omitted so the database defaults and
  /// triggers own them.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'is_private': isPrivate,
      'ai_label': aiLabel,
      'attached_entity_type': fileAttachmentTypeToDb(attachedEntityType),
      'attached_entity_id': attachedEntityId,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  /// Returns a copy with the given fields replaced.
  StoredFile copyWith({
    String? id,
    String? userId,
    String? storagePath,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    bool? isPrivate,
    String? aiLabel,
    FileAttachmentType? attachedEntityType,
    String? attachedEntityId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return StoredFile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isPrivate: isPrivate ?? this.isPrivate,
      aiLabel: aiLabel ?? this.aiLabel,
      attachedEntityType: attachedEntityType ?? this.attachedEntityType,
      attachedEntityId: attachedEntityId ?? this.attachedEntityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    storagePath,
    fileName,
    mimeType,
    sizeBytes,
    isPrivate,
    aiLabel,
    attachedEntityType,
    attachedEntityId,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}
