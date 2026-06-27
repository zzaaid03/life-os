/// Use case: Delete a task.
library;

import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Soft-deletes a task.
class DeleteTask {
  /// Creates a [DeleteTask].
  const DeleteTask(this._repository);
  final TaskRepository _repository;

  /// Executes the use case.
  Future<void> call(String id) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.delete(id);
  }
}
