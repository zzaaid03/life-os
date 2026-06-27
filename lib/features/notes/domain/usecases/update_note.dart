/// Use case: Update a note.
library;

import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/data/repositories/note_repository.dart';

/// Updates an existing note.
class UpdateNote {
  /// Creates an [UpdateNote].
  const UpdateNote(this._repository);
  final NoteRepository _repository;

  /// Executes the use case.
  Future<Note> call(Note note) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.update(note);
  }
}
