/// Use case: Get a journal entry by ID.
library;

import 'package:life_os/features/journal/data/models/journal_entry.dart';
import 'package:life_os/features/journal/data/repositories/journal_entry_repository.dart';

/// Fetches a single journal entry by its ID.
class GetJournalEntry {
  /// Creates a [GetJournalEntry].
  const GetJournalEntry(this._repository);
  final JournalEntryRepository _repository;

  /// Executes the use case.
  Future<JournalEntry?> call(String id) {
    // TODO: Add caching, permission checks, and side effects.
    return _repository.getById(id);
  }
}
