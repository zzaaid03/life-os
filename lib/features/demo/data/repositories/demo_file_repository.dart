/// In-memory demo repository for [StoredFile]s.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';

/// Stateful in-memory [FileRepository] backing the sandbox demo mode.
///
/// Makes zero network calls: uploads are held only in memory and
/// [signedUrl] returns a stable placeholder string instead of contacting
/// Supabase Storage.
class DemoFileRepository implements FileRepository {
  /// Creates a [DemoFileRepository] seeded with demo data.
  DemoFileRepository() : _files = buildDemoFiles();

  final List<StoredFile> _files;

  @override
  Future<List<StoredFile>> getAll(String userId) async {
    return List.unmodifiable(
      _files.where((f) => f.deletedAt == null).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<StoredFile> upload({
    required String userId,
    required PickedFile file,
    required bool isPrivate,
    FileAttachmentType? attachedEntityType,
    String? attachedEntityId,
  }) async {
    final now = DateTime.now();
    final stored = StoredFile(
      id: 'demo-file-${_files.length}-${now.microsecondsSinceEpoch}',
      userId: userId,
      storagePath: '$userId/${file.fileName}',
      fileName: file.fileName,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      isPrivate: isPrivate,
      thumbnailBase64: file.thumbnailBase64,
      attachedEntityType: attachedEntityType,
      attachedEntityId: attachedEntityId,
      createdAt: now,
      updatedAt: now,
    );
    _files.add(stored);
    return stored;
  }

  @override
  Future<void> setPrivate(String id, bool isPrivate) async {
    final index = _files.indexWhere((f) => f.id == id);
    if (index != -1) {
      _files[index] = _files[index].copyWith(
        isPrivate: isPrivate,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> delete(StoredFile file) async {
    final index = _files.indexWhere((f) => f.id == file.id);
    if (index != -1) {
      _files[index] = _files[index].copyWith(deletedAt: DateTime.now());
    }
  }

  @override
  Future<String> signedUrl(
    StoredFile file, {
    Duration ttl = const Duration(minutes: 30),
  }) async {
    return 'https://demo.local/placeholder/${file.fileName}';
  }
}
