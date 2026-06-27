/// Tag repository interface.
library;

import 'package:life_os/features/tags/data/models/tag.dart';

/// Abstract repository for Tag operations.
abstract class TagRepository {
  /// Fetches a single tag by [id].
  Future<Tag?> getById(String id);

  /// Fetches all tags for the given [userId].
  Future<List<Tag>> getAll(String userId);

  /// Fetches a tag by [name] for the given [userId].
  Future<Tag?> getByName(String userId, String name);

  /// Creates a new tag.
  Future<Tag> create(Tag tag);

  /// Updates an existing tag.
  Future<Tag> update(Tag tag);

  /// Soft-deletes a tag by [id].
  Future<void> delete(String id);

  /// Hard-deletes a tag by [id] (permanent removal).
  Future<void> purge(String id);
}
