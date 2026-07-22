/// Goal breakdown service.
///
/// Thin client over the deployed `goal-breakdown` Supabase Edge Function.
/// The function asks Groq for an ordered list of concrete tasks toward a
/// goal and computes each task's suggested due date server-side.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when the Edge Function call fails for any reason (network error,
/// function error, malformed response).
class GoalBreakdownException implements Exception {
  /// Creates a [GoalBreakdownException].
  const GoalBreakdownException(this.message);

  /// A human-readable explanation.
  final String message;

  @override
  String toString() => 'GoalBreakdownException: $message';
}

/// An AI-suggested task generated toward a goal.
class SuggestedGoalTask {
  /// Creates a [SuggestedGoalTask].
  const SuggestedGoalTask({
    required this.title,
    this.description,
    required this.priority,
    required this.suggestedDueDate,
  });

  /// Parses a [SuggestedGoalTask] from the Edge Function JSON.
  factory SuggestedGoalTask.fromJson(Map<String, dynamic> json) {
    return SuggestedGoalTask(
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String?)?.trim(),
      priority: (json['priority'] as String? ?? 'none').trim().toLowerCase(),
      suggestedDueDate:
          DateTime.parse(json['suggestedDueDate'] as String).toLocal(),
    );
  }

  /// Short imperative task title.
  final String title;

  /// Optional one-sentence context, or null.
  final String? description;

  /// Priority as a raw string: none | low | medium | high.
  final String priority;

  /// The computed due date for this task.
  final DateTime suggestedDueDate;
}

/// Calls the `goal-breakdown` Edge Function and parses its response.
class GoalBreakdownService {
  /// Creates a [GoalBreakdownService].
  const GoalBreakdownService(this.client);

  /// The Supabase client used to invoke the Edge Function. The user's JWT
  /// is attached automatically.
  final SupabaseClient client;

  /// Generates suggested tasks for a goal.
  ///
  /// Throws [GoalBreakdownException] on any failure.
  Future<List<SuggestedGoalTask>> generateTasks({
    required String goalTitle,
    String? goalDescription,
    DateTime? targetDate,
  }) async {
    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'goal-breakdown',
        body: {
          'goalTitle': goalTitle,
          'goalDescription': goalDescription,
          'targetDate': targetDate?.toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      throw GoalBreakdownException(
        'Could not reach the goal assistant. ($e)',
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw const GoalBreakdownException(
        'The goal assistant returned no data.',
      );
    }
    final map = Map<String, dynamic>.from(data);

    if (map['error'] != null && map['tasks'] == null) {
      throw GoalBreakdownException('Goal breakdown failed: ${map['error']}');
    }

    final rawTasks = map['tasks'] as List<dynamic>? ?? const [];
    return rawTasks
        .whereType<Map<String, dynamic>>()
        .map(SuggestedGoalTask.fromJson)
        .where((t) => t.title.isNotEmpty)
        .toList();
  }
}

/// Provides the [GoalBreakdownService].
final goalBreakdownServiceProvider = Provider<GoalBreakdownService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return GoalBreakdownService(client);
});
