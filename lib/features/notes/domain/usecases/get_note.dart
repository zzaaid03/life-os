/// Use case: Get a note by ID.
library;

import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/data/repositories/note_repository.dart';

/// Fetches a single note by its ID.
class GetNote {
  /// Creates a [GetNote].
  const GetNote(this._repository);
  final NoteRepository _repository;

  /// Executes the use case.
  Future<Note?> call(String id) {
    // TODO: Add caching, permission checks, and side effects.
    return _repository.getById(id);
  }
}
