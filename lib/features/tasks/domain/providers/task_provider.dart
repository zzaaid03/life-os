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

import 'dart:async';

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
    debugPrint('[taskRepositoryProvider] kIsWeb=true → remoteOnly');
    return TaskRepositoryImpl.remoteOnly(remote: remote, syncQueue: syncQueue);
  }

  debugPrint('[taskRepositoryProvider] kIsWeb=false → local+remote');
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
  Future<void> loadTasks(String userId) async {
    _userId = userId;
    debugPrint('[TaskListNotifier] loadTasks($userId) called');
    debugPrint(
      '[TaskListNotifier] state.tasks.length BEFORE load: ${state.tasks.length}',
    );

    if (state.tasks.isEmpty) {
      state = const TaskListState(status: TaskListStatus.loading);
    }

    try {
      final tasks = await _repository.getAll(userId);
      debugPrint('[TaskListNotifier] getAll returned ${tasks.length} tasks');
      for (final t in tasks) {
        debugPrint(
          '[TaskListNotifier]   task: id=${t.id} title="${t.title}" '
          'status=${t.status} dueDate=${t.dueDate} '
          'deletedAt=${t.deletedAt} syncStatus=${t.syncStatus}',
        );
      }
      state = TaskListState(status: TaskListStatus.loaded, tasks: tasks);
      debugPrint(
        '[TaskListNotifier] state set: ${state.tasks.length} tasks, '
        'status=${state.status}',
      );
      _syncInBackground(userId);
    } catch (e) {
      debugPrint('[TaskListNotifier] loadTasks EXCEPTION: $e');
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
  /// write happens in the background — this method returns
  /// immediately after the state update.
  Future<void> createTask(Task task) async {
    final userId = _userId ?? task.userId;
    final toCreate = task.id.isEmpty
        ? task.copyWith(id: const Uuid().v4(), userId: userId)
        : task.copyWith(userId: userId);

    debugPrint('[TaskListNotifier] createTask called');
    debugPrint(
      '[TaskListNotifier]   toCreate: id=${toCreate.id} '
      'title="${toCreate.title}" userId=$userId '
      'status=${toCreate.status} dueDate=${toCreate.dueDate}',
    );
    debugPrint(
      '[TaskListNotifier]   state.tasks.length BEFORE optimistic: '
      '${state.tasks.length}',
    );

    // Optimistic: add to state immediately
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: [...state.tasks, toCreate],
    );
    debugPrint(
      '[TaskListNotifier]   state.tasks.length AFTER optimistic: '
      '${state.tasks.length}',
    );

    // Background write (fire and forget — don't block the caller)
    unawaited(
      _repository
          .create(toCreate)
          .then((created) {
            debugPrint(
              '[TaskListNotifier] repository.create succeeded: '
              'id=${created.id} title="${created.title}"',
            );
            _syncInBackground(userId);
          })
          .catchError((Object e) {
            debugPrint('[TaskListNotifier] repository.create FAILED: $e');
            state = state.copyWith(
              tasks: state.tasks.where((t) => t.id != toCreate.id).toList(),
            );
            debugPrint(
              '[TaskListNotifier]   reverted: '
              'state.tasks.length=${state.tasks.length}',
            );
          }),
    );
  }

  /// Updates a task with **optimistic UI update**.
  Future<void> updateTask(Task task) async {
    final oldTask = state.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );

    debugPrint(
      '[TaskListNotifier] updateTask: id=${task.id} '
      'title="${task.title}" status=${task.status}',
    );

    // Optimistic: update state immediately
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: state.tasks.map((t) => t.id == task.id ? task : t).toList(),
    );

    // Background write (fire and forget)
    unawaited(
      _repository
          .update(task)
          .then((updated) {
            debugPrint(
              '[TaskListNotifier] repository.update succeeded: '
              'id=${updated.id}',
            );
            _syncInBackground(_userId ?? task.userId);
          })
          .catchError((Object e) {
            debugPrint('[TaskListNotifier] repository.update FAILED: $e');
            state = state.copyWith(
              tasks: state.tasks
                  .map((t) => t.id == task.id ? oldTask : t)
                  .toList(),
            );
          }),
    );
  }

  /// Soft-deletes a task with **optimistic UI update**.
  Future<void> deleteTask(String id) async {
    final oldTasks = state.tasks;

    debugPrint('[TaskListNotifier] deleteTask: id=$id');

    // Optimistic: remove from state immediately
    state = TaskListState(
      status: TaskListStatus.loaded,
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );

    // Background write (fire and forget)
    unawaited(
      _repository
          .delete(id)
          .then((_) {
            debugPrint(
              '[TaskListNotifier] repository.delete succeeded: '
              'id=$id',
            );
            _syncInBackground(_userId ?? '');
          })
          .catchError((Object e) {
            debugPrint('[TaskListNotifier] repository.delete FAILED: $e');
            state = state.copyWith(tasks: oldTasks);
          }),
    );
  }

  /// Toggles a task between completed and pending.
  ///
  /// If completed → becomes pending again (uncompletes).
  /// If pending → becomes completed.
  Future<void> toggleTaskComplete(String id) async {
    final task = state.tasks.firstWhere((t) => t.id == id);
    final isCompleted = task.status == TaskStatus.completed;
    debugPrint(
      '[TaskListNotifier] toggleTaskComplete: id=$id '
      'currently completed=$isCompleted → '
      'will become ${isCompleted ? 'pending' : 'completed'}',
    );
    final updated = task.copyWith(
      status: isCompleted ? TaskStatus.pending : TaskStatus.completed,
      completedAt: isCompleted ? null : DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await updateTask(updated);
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
    debugPrint('[TaskListNotifier] _syncInBackground($userId)');
    _syncService
        .syncTasks(userId)
        .then((_) {
          debugPrint('[TaskListNotifier] sync completed');
        })
        .catchError((Object e) {
          debugPrint('[TaskListNotifier] sync FAILED: $e');
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
        debugPrint(
          '[taskListProvider] auth state changed → loading tasks for '
          'userId=${next.userId}',
        );
        notifier.loadTasks(next.userId!);
      }
    });

    return notifier;
  },
);

/// Whether a task is due today (or has no due date — counts as today).
bool _isDueToday(DateTime? dueDate) {
  if (dueDate == null) return true; // No due date = today by default
  final now = DateTime.now();
  return dueDate.year == now.year &&
      dueDate.month == now.month &&
      dueDate.day == now.day;
}

/// Tasks due today (not completed/archived).
/// Tasks with no due date are included as "today".
final todayTasksProvider = Provider<List<Task>>((ref) {
  final taskState = ref.watch(taskListProvider);
  final tasks = taskState.tasks;
  final filtered = tasks
      .where(
        (t) =>
            _isDueToday(t.dueDate) &&
            t.status != TaskStatus.completed &&
            t.status != TaskStatus.archived,
      )
      .toList();

  debugPrint(
    '[todayTasksProvider] received ${tasks.length} tasks from '
    'taskListProvider, returning ${filtered.length} after filtering',
  );
  for (final t in filtered) {
    debugPrint(
      '[todayTasksProvider]   id=${t.id} title="${t.title}" '
      'status=${t.status} dueDate=${t.dueDate}',
    );
  }

  return filtered;
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
