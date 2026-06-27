/// Use case: Create a tag.
library;

import 'package:life_os/features/tags/data/models/tag.dart';
import 'package:life_os/features/tags/data/repositories/tag_repository.dart';

/// Creates a new tag.
class CreateTag {
  /// Creates a [CreateTag].
  const CreateTag(this._repository);
  final TagRepository _repository;

  /// Executes the use case.
  Future<Tag> call(Tag tag) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.create(tag);
  }
}
