/// Use case: Delete a journal entry.
library;

import 'package:life_os/features/journal/data/repositories/journal_entry_repository.dart';

/// Soft-deletes a journal entry.
class DeleteJournalEntry {
  /// Creates a [DeleteJournalEntry].
  const DeleteJournalEntry(this._repository);
  final JournalEntryRepository _repository;

  /// Executes the use case.
  Future<void> call(String id) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.delete(id);
  }
}
