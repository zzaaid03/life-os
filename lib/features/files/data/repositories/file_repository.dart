/// Repository interface for stored files.
///
/// Files are NETWORK-ONLY by deliberate decision: there is no Drift table
/// and no offline sync, exactly as with goals. With no connection the file
/// list is empty and uploading fails. That is a choice, not an oversight.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/supabase_file_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for [StoredFile] records and their bytes.
///
/// Implementations own BOTH sides of a file: the object in the `user-files`
/// Storage bucket and the metadata row in `public.user_files`. They must
/// never leave one without the other.
abstract class FileRepository {
  /// Fetches every non-deleted file for [userId], newest first.
  Future<List<StoredFile>> getAll(String userId);

  /// Uploads [file] and inserts its metadata row, returning the stored row.
  ///
  /// Uploads the bytes FIRST and inserts the row only after the upload
  /// succeeds, so a failed upload can never leave a metadata row pointing at
  /// an object that does not exist.
  Future<StoredFile> upload({
    required String userId,
    required PickedFile file,
    required bool isPrivate,
    FileAttachmentType? attachedEntityType,
    String? attachedEntityId,
  });

  /// Flips the "private, never send to AI" toggle on a file.
  Future<void> setPrivate(String id, bool isPrivate);

  /// Deletes a file: soft-deletes the row AND removes the storage object.
  ///
  /// The object is removed for real because storage quota is shared across
  /// every tester, so a soft delete alone would leak space permanently.
  Future<void> delete(StoredFile file);

  /// Returns a signed URL for [file], valid for [ttl].
  ///
  /// EGRESS DISCIPLINE: implementations MUST cache the returned URL in
  /// memory until shortly before it expires and hand back the cached value
  /// on repeat calls. A widget rebuild must never mint a fresh URL, and a
  /// list must never fetch file bytes it is not displaying.
  Future<String> signedUrl(
    StoredFile file, {
    Duration ttl = const Duration(minutes: 30),
  });
}

/// Provides the [FileRepository].
final fileRepositoryProvider = Provider<FileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseFileRepository(client);
});
