/// Use case: List all tags for a user.
library;

import 'package:life_os/features/tags/data/models/tag.dart';
import 'package:life_os/features/tags/data/repositories/tag_repository.dart';

/// Fetches all tags for a given user.
class ListTags {
  /// Creates a [ListTags].
  const ListTags(this._repository);
  final TagRepository _repository;

  /// Executes the use case.
  Future<List<Tag>> call(String userId) {
    // TODO: Add filtering, sorting, and pagination.
    return _repository.getAll(userId);
  }
}
