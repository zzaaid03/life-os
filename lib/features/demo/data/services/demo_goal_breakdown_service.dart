/// In-memory demo override of [GoalBreakdownService] — plays a realistic
/// generating beat then returns a fixed, goal-agnostic breakdown. Never
/// calls the `goal-breakdown` edge function.
library;

import 'package:life_os/features/goals/data/goal_breakdown_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [GoalBreakdownService] that never hits the network — [generateTasks]
/// waits a couple of seconds then returns a fixed set of suggested tasks.
class DemoGoalBreakdownService extends GoalBreakdownService {
  /// Creates a [DemoGoalBreakdownService].
  DemoGoalBreakdownService() : super(Supabase.instance.client);

  @override
  Future<List<SuggestedGoalTask>> generateTasks({
    required String goalTitle,
    String? goalDescription,
    DateTime? targetDate,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    return [
      SuggestedGoalTask(
        title: 'Define what success looks like and set a clear target date',
        priority: 'high',
        suggestedDueDate: now.add(const Duration(days: 2)),
      ),
      SuggestedGoalTask(
        title: 'Break the goal into 3 weekly milestones',
        priority: 'medium',
        suggestedDueDate: now.add(const Duration(days: 4)),
      ),
      SuggestedGoalTask(
        title: 'Identify the first concrete action and schedule it this week',
        priority: 'high',
        suggestedDueDate: now.add(const Duration(days: 1)),
      ),
      SuggestedGoalTask(
        title: 'Set a weekly check-in to review progress',
        priority: 'low',
        suggestedDueDate: now.add(const Duration(days: 7)),
      ),
    ];
  }
}
