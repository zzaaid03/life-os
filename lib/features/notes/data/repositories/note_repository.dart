/// Note repository interface.
library;

import 'package:life_os/features/notes/data/models/note.dart';

/// Abstract repository for Note operations.
abstract class NoteRepository {
  /// Fetches a single note by [id].
  Future<Note?> getById(String id);

  /// Fetches all notes for the given [userId].
  Future<List<Note>> getAll(String userId);

  /// Creates a new note.
  Future<Note> create(Note note);

  /// Updates an existing note.
  Future<Note> update(Note note);

  /// Soft-deletes a note by [id].
  Future<void> delete(String id);

  /// Hard-deletes a note by [id] (permanent removal).
  Future<void> purge(String id);
}
