/// Use case: Get a tag by ID.
library;

import 'package:life_os/features/tags/data/models/tag.dart';
import 'package:life_os/features/tags/data/repositories/tag_repository.dart';

/// Fetches a single tag by its ID.
class GetTag {
  /// Creates a [GetTag].
  const GetTag(this._repository);
  final TagRepository _repository;

  /// Executes the use case.
  Future<Tag?> call(String id) {
    // TODO: Add caching, permission checks, and side effects.
    return _repository.getById(id);
  }
}
