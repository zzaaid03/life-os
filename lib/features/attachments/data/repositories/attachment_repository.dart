/// Attachment repository interface.
library;

import 'package:life_os/features/attachments/data/models/attachment.dart';

/// Abstract repository for Attachment operations.
abstract class AttachmentRepository {
  /// Fetches a single attachment by [id].
  Future<Attachment?> getById(String id);

  /// Fetches all attachments for the given [userId].
  Future<List<Attachment>> getAll(String userId);

  /// Fetches attachments linked to a specific entity.
  Future<List<Attachment>> getByEntity(String entityType, String entityId);

  /// Creates a new attachment.
  Future<Attachment> create(Attachment attachment);

  /// Updates an existing attachment.
  Future<Attachment> update(Attachment attachment);

  /// Soft-deletes an attachment by [id].
  Future<void> delete(String id);

  /// Hard-deletes an attachment by [id] (permanent removal).
  Future<void> purge(String id);
}
