/// Riverpod providers for the files feature.
///
/// Mirrors the load / auth-listen / cold-start pattern used by the jobs and
/// tasks features so cold-start behaves consistently. Files are network-only,
/// so an empty list with no connection is expected, not an error state to
/// design around.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/files/data/models/picked_file.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the files list.
enum FileListStatus { loading, loaded, error }

/// State managed by [FileListNotifier].
class FileListState {
  /// Creates a [FileListState].
  const FileListState({
    this.status = FileListStatus.loading,
    this.files = const <StoredFile>[],
    this.error,
  });

  /// The current loading status.
  final FileListStatus status;

  /// The loaded files, newest first.
  final List<StoredFile> files;

  /// An error message, if loading failed.
  final String? error;

  /// Returns a copy with the given overrides.
  FileListState copyWith({
    FileListStatus? status,
    List<StoredFile>? files,
    String? error,
  }) {
    return FileListState(
      status: status ?? this.status,
      files: files ?? this.files,
      error: error,
    );
  }
}

/// Loads, uploads and deletes the user's files.
class FileListNotifier extends StateNotifier<FileListState> {
  /// Creates a [FileListNotifier].
  FileListNotifier(this._repository) : super(const FileListState());

  final FileRepository _repository;

  String? _userId;

  /// Loads files for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.files.isEmpty) {
      state = const FileListState(status: FileListStatus.loading);
    }
    try {
      final files = await _repository.getAll(userId);
      state = FileListState(status: FileListStatus.loaded, files: files);
    } catch (e) {
      if (state.files.isNotEmpty) {
        state = state.copyWith(status: FileListStatus.loaded);
      } else {
        state = const FileListState(
          status: FileListStatus.error,
          error: 'Failed to load files.',
        );
      }
    }
  }

  /// Reloads files for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  /// Uploads [file] and prepends it to the list on success.
  Future<StoredFile> upload(
    PickedFile file, {
    required bool isPrivate,
    FileAttachmentType? attachedEntityType,
    String? attachedEntityId,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Cannot upload before a user is loaded.');
    }
    final stored = await _repository.upload(
      userId: userId,
      file: file,
      isPrivate: isPrivate,
      attachedEntityType: attachedEntityType,
      attachedEntityId: attachedEntityId,
    );
    state = state.copyWith(files: [stored, ...state.files]);
    return stored;
  }

  /// Flips the "private, never send to AI" toggle and updates the list.
  Future<void> setPrivate(StoredFile file, bool isPrivate) async {
    await _repository.setPrivate(file.id, isPrivate);
    state = state.copyWith(
      files: [
        for (final f in state.files)
          if (f.id == file.id) f.copyWith(isPrivate: isPrivate) else f,
      ],
    );
  }

  /// Deletes [file] and removes it from the list.
  Future<void> delete(StoredFile file) async {
    await _repository.delete(file);
    state = state.copyWith(
      files: [
        for (final f in state.files)
          if (f.id != file.id) f,
      ],
    );
  }
}

/// Provides the [FileListNotifier] and its [FileListState].
final fileListProvider = StateNotifierProvider<FileListNotifier, FileListState>(
  (ref) {
    final repository = ref.watch(fileRepositoryProvider);
    final notifier = FileListNotifier(repository);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          next.userId != null &&
          (previous == null ||
              !previous.isAuthenticated ||
              previous.userId != next.userId)) {
        notifier.load(next.userId!);
      }
    });

    // Cold-start: if the session was already restored before this provider
    // was created, `ref.listen` won't fire, so load eagerly.
    final currentAuth = ref.read(authProvider);
    if (currentAuth.isAuthenticated && currentAuth.userId != null) {
      Future.microtask(() => notifier.load(currentAuth.userId!));
    }

    return notifier;
  },
);

/// The number of stored files (for dashboard badges and empty states).
final fileCountProvider = Provider<int>((ref) {
  return ref.watch(fileListProvider).files.length;
});
