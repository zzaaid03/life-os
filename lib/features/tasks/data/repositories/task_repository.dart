/// Task repository interface.
library;

import 'package:life_os/features/tasks/data/models/task.dart';

/// Abstract repository for Task operations.
abstract class TaskRepository {
  /// Fetches a single task by [id].
  Future<Task?> getById(String id);

  /// Fetches all tasks for the given [userId].
  Future<List<Task>> getAll(String userId);

  /// Creates a new task.
  Future<Task> create(Task task);

  /// Updates an existing task.
  Future<Task> update(Task task);

  /// Soft-deletes a task by [id].
  Future<void> delete(String id);

  /// Hard-deletes a task by [id] (permanent removal).
  Future<void> purge(String id);
}
