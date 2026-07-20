/// Riverpod providers for the notes feature.
///
/// Mirrors the jobs/tasks provider pattern: a list notifier that loads on
/// auth, supports create/update/delete, and can be refreshed.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/data/repositories/note_repository.dart';
import 'package:life_os/features/notes/data/repositories/supabase_note_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

/// The loading status of the note list.
enum NoteListStatus { loading, loaded, error }

/// State managed by [NoteListNotifier].
class NoteListState {
  /// Creates a [NoteListState].
  const NoteListState({
    this.status = NoteListStatus.loading,
    this.notes = const <Note>[],
    this.error,
  });

  /// The current loading status.
  final NoteListStatus status;

  /// The loaded notes (pinned first, newest first).
  final List<Note> notes;

  /// An error message, if loading failed.
  final String? error;

  /// Returns a copy with the given overrides.
  NoteListState copyWith({
    NoteListStatus? status,
    List<Note>? notes,
    String? error,
  }) {
    return NoteListState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      error: error,
    );
  }
}

/// Loads and mutates the user's notes.
class NoteListNotifier extends StateNotifier<NoteListState> {
  /// Creates a [NoteListNotifier].
  NoteListNotifier(this._repository) : super(const NoteListState());

  final NoteRepository _repository;

  String? _userId;

  /// Loads notes for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.notes.isEmpty) {
      state = const NoteListState(status: NoteListStatus.loading);
    }
    try {
      final notes = await _repository.getAll(userId);
      state = NoteListState(status: NoteListStatus.loaded, notes: notes);
    } catch (e) {
      if (state.notes.isNotEmpty) {
        state = state.copyWith(status: NoteListStatus.loaded);
      } else {
        state = const NoteListState(
          status: NoteListStatus.error,
          error: 'Failed to load notes.',
        );
      }
    }
  }

  /// Reloads notes for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  /// Creates a note with [title] and optional [content].
  Future<void> createNote({required String title, String? content}) async {
    final userId = _userId;
    if (userId == null) return;
    final now = DateTime.now();
    await _repository.create(
      Note(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        content: content,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
  }

  /// Updates an existing [note].
  Future<void> updateNote(Note note) async {
    await _repository.update(note.copyWith(updatedAt: DateTime.now()));
    await refresh();
  }

  /// Soft-deletes the note with [id].
  Future<void> deleteNote(String id) async {
    await _repository.delete(id);
    await refresh();
  }
}

/// Provides the [NoteListNotifier] and its [NoteListState].
final noteListProvider =
    StateNotifierProvider<NoteListNotifier, NoteListState>((ref) {
      final repository = ref.watch(noteRepositoryProvider);
      final notifier = NoteListNotifier(repository);

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold-start: load eagerly if the session was already restored.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });
