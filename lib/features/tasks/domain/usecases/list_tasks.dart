/// Use case: List all tasks for a user.
library;

import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Fetches all tasks for a given user.
class ListTasks {
  /// Creates a [ListTasks].
  const ListTasks(this._repository);
  final TaskRepository _repository;

  /// Executes the use case.
  Future<List<Task>> call(String userId) {
    // TODO: Add filtering, sorting, and pagination.
    return _repository.getAll(userId);
  }
}
