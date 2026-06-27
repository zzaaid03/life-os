/// Goal repository interface.
library;

import 'package:life_os/features/goals/data/models/goal.dart';

/// Abstract repository for Goal operations.
abstract class GoalRepository {
  /// Fetches a single goal by [id].
  Future<Goal?> getById(String id);

  /// Fetches all goals for the given [userId].
  Future<List<Goal>> getAll(String userId);

  /// Creates a new goal.
  Future<Goal> create(Goal goal);

  /// Updates an existing goal.
  Future<Goal> update(Goal goal);

  /// Soft-deletes a goal by [id].
  Future<void> delete(String id);

  /// Hard-deletes a goal by [id] (permanent removal).
  Future<void> purge(String id);
}
