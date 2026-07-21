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
  GoalListNotifier(this._repository) : super(const GoalListState());

  final GoalRepository _repository;

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

  /// Soft-deletes the goal with [id].
  Future<void> deleteGoal(String id) async {
    await _repository.delete(id);
    await refresh();
  }
}

/// Provides the [GoalListNotifier] and its [GoalListState].
final goalListProvider =
    StateNotifierProvider<GoalListNotifier, GoalListState>((ref) {
      final repository = ref.watch(goalRepositoryProvider);
      final notifier = GoalListNotifier(repository);

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
