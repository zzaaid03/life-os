/// Use case: List all notes for a user.
library;

import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/data/repositories/note_repository.dart';

/// Fetches all notes for a given user.
class ListNotes {
  /// Creates a [ListNotes].
  const ListNotes(this._repository);
  final NoteRepository _repository;

  /// Executes the use case.
  Future<List<Note>> call(String userId) {
    // TODO: Add filtering, sorting, and pagination.
    return _repository.getAll(userId);
  }
}
