/// Use case: Delete a note.
library;

import 'package:life_os/features/notes/data/repositories/note_repository.dart';

/// Soft-deletes a note.
class DeleteNote {
  /// Creates a [DeleteNote].
  const DeleteNote(this._repository);
  final NoteRepository _repository;

  /// Executes the use case.
  Future<void> call(String id) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.delete(id);
  }
}
