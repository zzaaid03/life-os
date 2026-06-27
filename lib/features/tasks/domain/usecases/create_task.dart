/// Use case: Create a task.
library;

import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Creates a new task.
class CreateTask {
  /// Creates a [CreateTask].
  const CreateTask(this._repository);
  final TaskRepository _repository;

  /// Executes the use case.
  Future<Task> call(Task task) {
    // TODO: Add validation, business rules, and side effects.
    return _repository.create(task);
  }
}
