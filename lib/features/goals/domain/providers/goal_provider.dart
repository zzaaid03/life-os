/// Riverpod providers for the goals feature.
///
/// Mirrors the jobs provider pattern: a list notifier that loads on
/// auth, supports create/update/delete + progress updates, and refreshes.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/data/repositories/goal_repository.dart';
import 'package:life_os/features/goals/data/repositories/supabase_goal_repository.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/data/repositories/task_repository.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:uuid/uuid.dart';

/// The loading status of the goal list.
enum GoalListStatus { loading, loaded, error }

/// State managed by [GoalListNotifier].
class GoalListState {
  /// Creates a [GoalListState].
  const GoalListState({
    this.status = GoalListStatus.loading,
    this.goals = const <Goal>[],
    this.error,
  });

  /// The current loading status.
  final GoalListStatus status;

  /// The loaded goals.
  final List<Goal> goals;

  /// An error message, if loading failed.
  final String? error;

  /// Returns a copy with the given overrides.
  GoalListState copyWith({
    GoalListStatus? status,
    List<Goal>? goals,
    String? error,
  }) {
    return GoalListState(
      status: status ?? this.status,
      goals: goals ?? this.goals,
      error: error,
    );
  }
}

/// Loads and mutates the user's goals.
class GoalListNotifier extends StateNotifier<GoalListState> {
  /// Creates a [GoalListNotifier].
  GoalListNotifier(this._repository, this._taskRepository)
    : super(const GoalListState());

  final GoalRepository _repository;
  final TaskRepository _taskRepository;

  String? _userId;

  /// Loads goals for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.goals.isEmpty) {
      state = const GoalListState(status: GoalListStatus.loading);
    }
    try {
      final goals = await _repository.getAll(userId);
      state = GoalListState(status: GoalListStatus.loaded, goals: goals);
    } catch (e) {
      if (state.goals.isNotEmpty) {
        state = state.copyWith(status: GoalListStatus.loaded);
      } else {
        state = const GoalListState(
          status: GoalListStatus.error,
          error: 'Failed to load goals.',
        );
      }
    }
  }

  /// Reloads for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  /// Creates a goal.
  Future<void> createGoal({
    required String title,
    String? description,
    double progress = 0,
    DateTime? targetDate,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final now = DateTime.now();
    await _repository.create(
      Goal(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        description: description,
        progress: progress,
        targetDate: targetDate,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
  }

  /// Updates an existing [goal].
  Future<void> updateGoal(Goal goal) async {
    await _repository.update(goal.copyWith(updatedAt: DateTime.now()));
    await refresh();
  }

  /// Sets a goal's progress (0.0–1.0), marking it completed at 100%.
  Future<void> setProgress(Goal goal, double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    await updateGoal(
      goal.copyWith(
        progress: clamped,
        status: clamped >= 1.0 ? GoalStatus.completed : GoalStatus.active,
      ),
    );
  }

  /// Soft-deletes the goal with [id], then deletes its linked tasks.
  Future<void> deleteGoal(String id) async {
    await _repository.delete(id);

    final userId = _userId;
    if (userId != null) {
      final tasks = await _taskRepository.getAll(userId);
      final linkedTasks = tasks.where((t) => t.goalId == id);
      for (final task in linkedTasks) {
        await _taskRepository.delete(task.id);
      }
    }

    await refresh();
  }
}

/// Provides the [GoalListNotifier] and its [GoalListState].
final goalListProvider =
    StateNotifierProvider<GoalListNotifier, GoalListState>((ref) {
      final repository = ref.watch(goalRepositoryProvider);
      final taskRepository = ref.watch(taskRepositoryProvider);
      final notifier = GoalListNotifier(repository, taskRepository);

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold-start: load eagerly if the session was already restored.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });

/// The number of tasks linked to the goal with [goalId].
///
/// A goal with `count == 0` has no AI-generated tasks and keeps its manual
/// progress slider; a goal with `count >= 1` shows derived progress instead.
final goalTaskCountProvider = Provider.family<int, String>((ref, goalId) {
  final tasks = ref.watch(taskListProvider).tasks;
  return tasks.where((t) => t.goalId == goalId).length;
});

/// The derived progress (0.0-1.0) for the goal with [goalId], computed as
/// completed-linked-tasks / total-linked-tasks. Returns 0.0 if the goal has
/// no linked tasks — callers should check [goalTaskCountProvider] first to
/// decide whether to show derived vs. manual progress.
final goalProgressProvider = Provider.family<double, String>((ref, goalId) {
  final tasks = ref
      .watch(taskListProvider)
      .tasks
      .where((t) => t.goalId == goalId)
      .toList();
  if (tasks.isEmpty) return 0.0;
  final completed = tasks
      .where((t) => t.status == TaskStatus.completed)
      .length;
  return completed / tasks.length;
});
