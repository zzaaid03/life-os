/// Use case: Update a journal entry.
library;

import 'package:life_os/features/journal/data/models/journal_entry.dart';
import 'package:life_os/features/journal/data/repositories/journal_entry_repository.dart';

/// Updates an existing journal entry.
class UpdateJournalEntry {
  /// Creates an [UpdateJournalEntry].
  const UpdateJournalEntry(this._repository);
  final JournalEntryRepository _repository;

  /// Executes the use case.
  Future<JournalEntry> call(JournalEntry entry) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.update(entry);
  }
}
