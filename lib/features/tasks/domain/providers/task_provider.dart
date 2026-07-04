/// Riverpod providers for the tasks feature.
///
/// Wires up the local and remote data sources, the offline-first
/// repository, the sync service, and a [TaskListNotifier] that
/// exposes task list state to the UI.
///
/// Key performance decisions:
/// - State updates are **optimistic** — UI updates before sync completes
/// - Sync runs in the **background** after every mutation
/// - Loading state only shows on initial load (not on refresh)
/// - On web, reads go to Supabase directly (no local cache)
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

/// Provides the [TaskLocalDataSource] (native only).
final taskLocalDataSourceProvider = Provider<TaskLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TaskLocalDataSource(db);
});

/// Provides the [TaskRemoteDataSource].
final taskRemoteDataSourceProvider = Provider<TaskRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TaskRemoteDataSource(client);
});

/// Provides the [SyncQueue].
final syncQueueProvider = Provider<SyncQueue>((ref) {
  return const NoopSyncQueue();
});

/// Provides the [SyncService] (native only; no-op on web).
final syncServiceProvider = Provider<SyncService>((ref) {
  final remote = ref.watch(taskRemoteDataSourceProvider);

  if (kIsWeb) {
    return SyncService(localTasks: _NullLocalDataSource(), remoteTasks: remote);
  }

  final local = ref.watch(taskLocalDataSourceProvider);
  return SyncService(localTasks: local, remoteTasks: remote);
});

/// Null local data source for web.
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
  const TaskListState({
    this.status = TaskListStatus.loading,
    this.tasks = const <Task>[],
    this.error,
  });

  final TaskListStatus status;
  final List<Task> tasks;
  final String? error;

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

/// Manages the task list state with optimistic updates.
///
/// All mutations update the UI state **immediately** before
/// the repository call completes. Sync runs in the background.
class TaskListNotifier extends StateNotifier<TaskListState> {
  TaskListNotifier(this._repository, this._syncService)
    : super(const TaskListState());

  final TaskRepositoryImpl _repository;
  final SyncService _syncService;

  String? _userId;

  /// Loads tasks for the given [userId].
  ///
  /// Only shows loading spinner on initial load (when state is empty).
  /// On refresh, keeps existing data visible while loading.
  Future<void> loadTasks(String userId) async {
    _userId = userId;

    // Only show loading spinner if we have no data yet
    if (state.tasks.isEmpty) {
      state = const TaskListState(status: TaskListStatus.loading);
    }

    try {
      final tasks = await _repository.getAll(userId);
      state = TaskListState(status: TaskListStatus.loaded, tasks: tasks);
      // Background sync after load (non-blocking)
      _syncInBackground(userId);
    } catch (e) {
      // If we already have tasks, keep them visible
      if (state.tasks.isNotEmpty) {
        state = state.copyWith(status: TaskListStatus.loaded);
      } else {
        state = const TaskListState(
          status: TaskListStatus.error,
          error: 'Failed to load tasks.',
        );
      }
    }
  }

  /// Creates a new task with **optimistic UI update**.
  ///
  /// The task is added to the state immediately. The repository
  /// write and sync happen in the background.
  Future<void> createTask(Task task) async {
    final userId = _userId ?? task.userId;
    final toCreate = task.id.isEmpty
        ? task.copyWith(id: const Uuid().v4(), userId: userId)
        : task.copyWith(userId: userId);

    // Optimistic: add to state immediately
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: [...state.tasks, toCreate],
    );

    // Background write + sync (non-blocking)
    try {
      await _repository.create(toCreate);
      _syncInBackground(userId);
    } catch (e) {
      // Revert on failure
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != toCreate.id).toList(),
        error: 'Failed to create task.',
      );
    }
  }

  /// Updates a task with **optimistic UI update**.
  Future<void> updateTask(Task task) async {
    final oldTask = state.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );

    // Optimistic: update state immediately
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: state.tasks.map((t) => t.id == task.id ? task : t).toList(),
    );

    try {
      await _repository.update(task);
      _syncInBackground(_userId ?? task.userId);
    } catch (e) {
      // Revert on failure
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == task.id ? oldTask : t).toList(),
      );
    }
  }

  /// Soft-deletes a task with **optimistic UI update**.
  Future<void> deleteTask(String id) async {
    final oldTasks = state.tasks;

    // Optimistic: remove from state immediately
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );

    try {
      await _repository.delete(id);
      _syncInBackground(_userId ?? '');
    } catch (e) {
      // Revert on failure
      state = state.copyWith(tasks: oldTasks);
    }
  }

  /// Marks a task as completed with **optimistic UI update**.
  Future<void> completeTask(String id) async {
    final task = state.tasks.firstWhere((t) => t.id == id);
    final completed = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await updateTask(completed);
  }

  /// Reloads tasks from the data source.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await loadTasks(userId);
  }

  /// Triggers a background sync (non-blocking, silent).
  void _syncInBackground(String userId) {
    if (userId.isEmpty) return;
    // Fire and forget — don't block UI
    _syncService.syncTasks(userId).catchError((_) {
      // Silent failure — sync will retry on next mutation
    });
  }
}

/// Provides the [TaskListNotifier] and its [TaskListState].
final taskListProvider = StateNotifierProvider<TaskListNotifier, TaskListState>(
  (ref) {
    final repository = ref.watch(taskRepositoryProvider);
    final syncService = ref.watch(syncServiceProvider);
    final notifier = TaskListNotifier(repository, syncService);

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

/// Whether a task is due today.
bool _isDueToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

/// Tasks due today (not completed/archived).
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

/// Tasks due after today (not completed/archived).
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

/// Completed tasks.
final completedTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskListProvider).tasks;
  return tasks.where((t) => t.status == TaskStatus.completed).toList();
});
