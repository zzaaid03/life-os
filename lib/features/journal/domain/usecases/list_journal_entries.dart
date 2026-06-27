/// Use case: List all journal entries for a user.
library;

import 'package:life_os/features/journal/data/models/journal_entry.dart';
import 'package:life_os/features/journal/data/repositories/journal_entry_repository.dart';

/// Fetches all journal entries for a given user.
class ListJournalEntries {
  /// Creates a [ListJournalEntries].
  const ListJournalEntries(this._repository);
  final JournalEntryRepository _repository;

  /// Executes the use case.
  Future<List<JournalEntry>> call(String userId) {
    // TODO: Add filtering, sorting, and pagination.
    return _repository.getAll(userId);
  }
}
