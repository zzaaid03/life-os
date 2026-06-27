/// Use case: Create a note.
library;

import 'package:life_os/features/notes/data/models/note.dart';
import 'package:life_os/features/notes/data/repositories/note_repository.dart';

/// Creates a new note.
class CreateNote {
  /// Creates a [CreateNote].
  const CreateNote(this._repository);
  final NoteRepository _repository;

  /// Executes the use case.
  Future<Note> call(Note note) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.create(note);
  }
}
