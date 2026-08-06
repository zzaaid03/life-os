/// In-memory demo override of [GoalBreakdownService]: plays a realistic
/// generating beat then returns a fixed breakdown for the demo persona's
/// Product Manager goal. Never calls the `goal-breakdown` edge function.
library;

import 'package:life_os/features/goals/data/goal_breakdown_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [GoalBreakdownService] that never hits the network: [generateTasks]
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
        title:
            'Write a one-page story for each of your three strongest '
            'shipped projects',
        priority: 'high',
        suggestedDueDate: now.add(const Duration(days: 3)),
      ),
      SuggestedGoalTask(
        title:
            'Rewrite your CV so every bullet names an outcome, not a '
            'responsibility',
        priority: 'high',
        suggestedDueDate: now.add(const Duration(days: 6)),
      ),
      SuggestedGoalTask(
        title: 'List 15 target companies and find the hiring manager for each',
        priority: 'medium',
        suggestedDueDate: now.add(const Duration(days: 10)),
      ),
      SuggestedGoalTask(
        title:
            'Practise the product-sense and metrics questions out loud '
            'twice a week',
        priority: 'medium',
        suggestedDueDate: now.add(const Duration(days: 14)),
      ),
      SuggestedGoalTask(
        title: 'Ask two PMs already in the role for a 20-minute conversation',
        priority: 'low',
        suggestedDueDate: now.add(const Duration(days: 20)),
      ),
    ];
  }
}
