/// Use case: Delete a tag.
library;

import 'package:life_os/features/tags/data/repositories/tag_repository.dart';

/// Soft-deletes a tag.
class DeleteTag {
  /// Creates a [DeleteTag].
  const DeleteTag(this._repository);
  final TagRepository _repository;

  /// Executes the use case.
  Future<void> call(String id) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.delete(id);
  }
}
