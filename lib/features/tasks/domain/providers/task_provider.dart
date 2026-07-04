/// Riverpod providers for the tasks feature.
///
/// Wires up the local and remote data sources, the offline-first
/// repository, the sync service, and a [TaskListNotifier] that
/// exposes task list state to the UI. Also provides filtered
/// derived providers for today, upcoming, and completed tasks.
///
/// On web (where Drift is not supported), the local data source
/// is replaced with a remote-only fallback.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/services/app_database.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/core/sync/sync_service.dart';
import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:life_os/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

/// Provides the singleton [AppDatabase] instance (native only).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Provides the [TaskLocalDataSource].
///
/// On web, Drift is not available, so this provider throws.
/// The [taskRepositoryProvider] handles the web case by
/// falling back to remote-only mode.
final taskLocalDataSourceProvider = Provider<TaskLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TaskLocalDataSource(db);
});

/// Provides the [TaskRemoteDataSource].
final taskRemoteDataSourceProvider = Provider<TaskRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TaskRemoteDataSource(client);
});

/// Provides the [SyncQueue] used to trigger background syncs.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  return const NoopSyncQueue();
});

/// Provides the [SyncService].
///
/// On web, sync is not needed (remote-only mode).
final syncServiceProvider = Provider<SyncService>((ref) {
  final remote = ref.watch(taskRemoteDataSourceProvider);

  if (kIsWeb) {
    // No-op sync service for web
    return SyncService(localTasks: _NullLocalDataSource(), remoteTasks: remote);
  }

  final local = ref.watch(taskLocalDataSourceProvider);
  return SyncService(localTasks: local, remoteTasks: remote);
});

/// A null local data source that returns empty results.
/// Used on web where Drift is not available.
class _NullLocalDataSource implements TaskLocalDataSource {
  @override
  Future<Task?> getById(String id) async => null;

  @override
  Future<List<Task>> getAll(String userId) async => [];

  @override
  Future<List<Task>> getByStatus(String userId, TaskStatus status) async => [];

  @override
  Future<void> insert(Task task) async {}

  @override
  Future<void> update(Task task) async {}

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<void> purge(String id) async {}

  @override
  Future<List<Task>> getPendingSync(String userId) async => [];
}

/// Provides the [TaskRepositoryImpl].
///
/// On web, the local data source is unavailable (Drift uses FFI).
/// In that case, a remote-only repository is used instead.
final taskRepositoryProvider = Provider<TaskRepositoryImpl>((ref) {
  final remote = ref.watch(taskRemoteDataSourceProvider);
  final syncQueue = ref.watch(syncQueueProvider);

  if (kIsWeb) {
    return TaskRepositoryImpl.remoteOnly(remote: remote, syncQueue: syncQueue);
  }

  final local = ref.watch(taskLocalDataSourceProvider);
  return TaskRepositoryImpl(local: local, remote: remote, syncQueue: syncQueue);
});

/// The loading status of the task list.
enum TaskListStatus { loading, loaded, error }

/// The state managed by [TaskListNotifier].
class TaskListState {
  /// Creates a [TaskListState].
  const TaskListState({
    this.status = TaskListStatus.loading,
    this.tasks = const <Task>[],
    this.error,
  });

  /// The current loading status.
  final TaskListStatus status;

  /// The current list of tasks.
  final List<Task> tasks;

  /// An error message, if loading failed.
  final String? error;

  /// Creates a copy of this state with the given fields replaced.
  TaskListState copyWith({
    TaskListStatus? status,
    List<Task>? tasks,
    String? error,
  }) {
    return TaskListState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      error: error,
    );
  }
}

/// Manages the task list state and exposes CRUD operations.
class TaskListNotifier extends StateNotifier<TaskListState> {
  /// Creates a [TaskListNotifier].
  TaskListNotifier(this._repository, this._syncService)
    : super(const TaskListState());

  final TaskRepositoryImpl _repository;
  final SyncService _syncService;

  String? _userId;

  /// Loads tasks for the given [userId] from local storage.
  Future<void> loadTasks(String userId) async {
    _userId = userId;
    state = const TaskListState(status: TaskListStatus.loading);
    try {
      final tasks = await _repository.getAll(userId);
      state = TaskListState(status: TaskListStatus.loaded, tasks: tasks);
    } catch (e) {
      state = const TaskListState(
        status: TaskListStatus.error,
        error: 'Failed to load tasks. Please try again.',
      );
    }
  }

  /// Creates a new task.
  ///
  /// A fresh UUID is generated for the task if it does not already
  /// have one. The task is written locally and a background sync is
  /// triggered.
  Future<void> createTask(Task task) async {
    final userId = _userId ?? task.userId;
    final toCreate = task.id.isEmpty
        ? task.copyWith(id: const Uuid().v4(), userId: userId)
        : task.copyWith(userId: userId);
    final created = await _repository.create(toCreate);
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: [...state.tasks, created],
    );
  }

  /// Updates an existing task in the local store.
  Future<void> updateTask(Task task) async {
    final updated = await _repository.update(task);
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: state.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
    );
  }

  /// Soft-deletes a task by [id].
  Future<void> deleteTask(String id) async {
    await _repository.delete(id);
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
  }

  /// Marks a task as completed, setting [Task.completedAt] to now.
  Future<void> completeTask(String id) async {
    final task = state.tasks.firstWhere((t) => t.id == id);
    final completed = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );
    await updateTask(completed);
  }

  /// Reloads tasks from local storage for the current user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await loadTasks(userId);
  }

  /// Triggers a sync with the remote server for the current user.
  Future<void> sync() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _syncService.syncTasks(userId);
      await refresh();
    } catch (e) {
      state = state.copyWith(
        status: TaskListStatus.error,
        error: 'Sync failed. Please try again.',
      );
    }
  }
}

/// Provides the [TaskListNotifier] and its [TaskListState].
final taskListProvider = StateNotifierProvider<TaskListNotifier, TaskListState>(
  (ref) {
    final repository = ref.watch(taskRepositoryProvider);
    final syncService = ref.watch(syncServiceProvider);
    final notifier = TaskListNotifier(repository, syncService);

    // Auto-load tasks when the user becomes authenticated.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          next.userId != null &&
          (previous == null ||
              !previous.isAuthenticated ||
              previous.userId != next.userId)) {
        notifier.loadTasks(next.userId!);
      }
    });

    return notifier;
  },
);

/// Whether a task is due today (ignoring time-of-day).
bool _isDueToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

/// Tasks that are due today and not yet completed or archived.
final todayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskListProvider).tasks;
  return tasks
      .where(
        (t) =>
            t.dueDate != null &&
            _isDueToday(t.dueDate!) &&
            t.status != TaskStatus.completed &&
            t.status != TaskStatus.archived,
      )
      .toList();
});

/// Tasks that are due after today and not yet completed or archived.
final upcomingTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskListProvider).tasks;
  final today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  return tasks
      .where(
        (t) =>
            t.dueDate != null &&
            t.dueDate!.isAfter(today) &&
            t.status != TaskStatus.completed &&
            t.status != TaskStatus.archived,
      )
      .toList();
});

/// Tasks that have been completed.
final completedTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskListProvider).tasks;
  return tasks.where((t) => t.status == TaskStatus.completed).toList();
});
