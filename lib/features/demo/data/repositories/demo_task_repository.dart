/// In-memory demo repository for [Task]s.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';

/// Stateful in-memory [TaskRepository] backing the sandbox demo mode.
class DemoTaskRepository implements TaskRepository {
  /// Creates a [DemoTaskRepository] seeded with demo data.
  DemoTaskRepository() : _tasks = buildDemoTasks();

  final List<Task> _tasks;

  @override
  Future<Task?> getById(String id) async {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<List<Task>> getAll(String userId) async {
    return _tasks
        .where((t) => t.userId == userId && t.deletedAt == null)
        .toList();
  }

  @override
  Future<Task> create(Task task) async {
    _tasks.add(task);
    return task;
  }

  @override
  Future<Task> update(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
    return task;
  }

  @override
  Future<void> delete(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(deletedAt: DateTime.now());
    }
  }

  @override
  Future<void> purge(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }
}
