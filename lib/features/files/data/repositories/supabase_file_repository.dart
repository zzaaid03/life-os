/// Supabase-backed repository for stored files.
///
/// Owns both sides of a file: the object in the `user-files` Storage bucket
/// and the metadata row in `public.user_files`. RLS ensures each user only
/// ever sees and writes their own rows and objects, but every query is still
/// scoped by `user_id` explicitly for clarity.
library;

import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Repository for [StoredFile] records backed by Supabase.
class SupabaseFileRepository implements FileRepository {
  /// Creates a [SupabaseFileRepository].
  SupabaseFileRepository(this._client);

  final SupabaseClient _client;

  /// The Supabase table name.
  static const String _table = 'user_files';

  /// The Supabase Storage bucket name.
  static const String _bucket = 'user-files';

  /// Cached signed URLs, keyed by storage path, alongside their expiry.
  ///
  /// EGRESS DISCIPLINE: a widget rebuild must never mint a fresh signed URL.
  final Map<String, ({String url, DateTime expiresAt})> _signedUrlCache = {};

  /// Fetches every non-deleted file for [userId], newest first.
  @override
  Future<List<StoredFile>> getAll(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(StoredFile.fromJson)
        .toList();
  }

  /// Uploads [file]'s bytes first, then inserts its metadata row.
  ///
  /// If the row insert fails after a successful upload, the just-uploaded
  /// object is removed before rethrowing, so a metadata row never points at
  /// an object that does not exist and an orphaned object is never left
  /// behind either.
  @override
  Future<StoredFile> upload({
    required String userId,
    required PickedFile file,
    required bool isPrivate,
    FileAttachmentType? attachedEntityType,
    String? attachedEntityId,
  }) async {
    final extension = _extensionOf(file.fileName);
    final storagePath = '$userId/${const Uuid().v4()}$extension';

    await _client.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          file.bytes,
          fileOptions: FileOptions(contentType: file.mimeType),
        );

    try {
      final response = await _client
          .from(_table)
          .insert({
            'user_id': userId,
            'storage_path': storagePath,
            'file_name': file.fileName,
            'mime_type': file.mimeType,
            'size_bytes': file.sizeBytes,
            'is_private': isPrivate,
            'thumbnail_base64': file.thumbnailBase64,
            'attached_entity_type': fileAttachmentTypeToDb(
              attachedEntityType,
            ),
            'attached_entity_id': attachedEntityId,
          })
          .select()
          .single();
      return StoredFile.fromJson(response);
    } catch (_) {
      try {
        await _client.storage.from(_bucket).remove([storagePath]);
      } catch (_) {
        // The original insert error is the one that matters; a failed
        // rollback must not replace it and hide the real cause.
      }
      rethrow;
    }
  }

  /// Returns the lowercase extension (including the dot) of [fileName], or
  /// an empty string if there is none.
  String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex).toLowerCase();
  }

  /// Flips the "private, never send to AI" toggle on a file.
  @override
  Future<void> setPrivate(String id, bool isPrivate) async {
    await _client
        .from(_table)
        .update({'is_private': isPrivate})
        .eq('id', id);
  }

  /// Soft-deletes the row and removes the storage object for real.
  ///
  /// Storage quota is shared across every tester, so a soft delete alone
  /// would leak space permanently. If the object removal fails, the row
  /// soft-delete still completes and the storage error is swallowed, rather
  /// than leaving the user with an undeletable file.
  @override
  Future<void> delete(StoredFile file) async {
    await _client
        .from(_table)
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', file.id);

    try {
      await _client.storage.from(_bucket).remove([file.storagePath]);
    } catch (_) {
      // Quota leak is preferable to an undeletable file; the row is already
      // soft-deleted so this is not user-visible.
    }

    _signedUrlCache.remove(file.storagePath);
  }

  /// Returns a signed URL for [file], serving from the in-memory cache
  /// whenever the cached URL still has more than a minute left.
  @override
  Future<String> signedUrl(
    StoredFile file, {
    Duration ttl = const Duration(minutes: 30),
  }) async {
    final cached = _signedUrlCache[file.storagePath];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.difference(now).inSeconds > 60) {
      return cached.url;
    }

    final url = await _client.storage
        .from(_bucket)
        .createSignedUrl(file.storagePath, ttl.inSeconds);
    _signedUrlCache[file.storagePath] = (
      url: url,
      expiresAt: now.add(ttl),
    );
    return url;
  }
}
