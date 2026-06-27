/// Use case: Update a task.
library;

import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Updates an existing task.
class UpdateTask {
  /// Creates an [UpdateTask].
  const UpdateTask(this._repository);
  final TaskRepository _repository;

  /// Executes the use case.
  Future<Task> call(Task task) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.update(task);
  }
}
