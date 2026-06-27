/// Journal Entry repository interface.
library;

import 'package:life_os/features/journal/data/models/journal_entry.dart';

/// Abstract repository for JournalEntry operations.
abstract class JournalEntryRepository {
  /// Fetches a single journal entry by [id].
  Future<JournalEntry?> getById(String id);

  /// Fetches all journal entries for the given [userId].
  Future<List<JournalEntry>> getAll(String userId);

  /// Fetches journal entries within a date range.
  Future<List<JournalEntry>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  /// Creates a new journal entry.
  Future<JournalEntry> create(JournalEntry entry);

  /// Updates an existing journal entry.
  Future<JournalEntry> update(JournalEntry entry);

  /// Soft-deletes a journal entry by [id].
  Future<void> delete(String id);

  /// Hard-deletes a journal entry by [id] (permanent removal).
  Future<void> purge(String id);
}
