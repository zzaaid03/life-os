/// Use case: Get a task by ID.
library;

import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Fetches a single task by its ID.
class GetTask {
  /// Creates a [GetTask].
  const GetTask(this._repository);
  final TaskRepository _repository;

  /// Executes the use case.
  Future<Task?> call(String id) {
    // TODO: Add caching, permission checks, and side effects.
    return _repository.getById(id);
  }
}
