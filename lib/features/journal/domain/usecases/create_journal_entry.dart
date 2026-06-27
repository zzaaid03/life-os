/// Use case: Create a journal entry.
library;

import 'package:life_os/features/journal/data/models/journal_entry.dart';
import 'package:life_os/features/journal/data/repositories/journal_entry_repository.dart';

/// Creates a new journal entry.
class CreateJournalEntry {
  /// Creates a [CreateJournalEntry].
  const CreateJournalEntry(this._repository);
  final JournalEntryRepository _repository;

  /// Executes the use case.
  Future<JournalEntry> call(JournalEntry entry) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.create(entry);
  }
}
