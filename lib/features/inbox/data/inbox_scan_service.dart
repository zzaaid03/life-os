/// Inbox scan service.
///
/// Thin client over the deployed `extract-tasks` Supabase Edge Function.
/// The function reads the user's recent Gmail server-side (using the Google
/// access token passed in) and returns AI-derived actionable tasks and
/// job-application updates. Email bodies never reach the client.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when no Google access token is available for the current session.
///
/// This is the normal state after a page reload (Supabase does not persist
/// the OAuth `providerToken`). The UI should catch this and prompt the user
/// to reconnect Gmail by re-running the Google sign-in flow.
class GmailNotConnectedException implements Exception {
  /// Creates a [GmailNotConnectedException].
  const GmailNotConnectedException([this.message = 'Gmail is not connected.']);

  /// A human-readable explanation.
  final String message;

  @override
  String toString() => 'GmailNotConnectedException: $message';
}

/// Thrown when the Edge Function call fails for any reason other than a
/// missing token (network error, function error, malformed response).
class InboxScanException implements Exception {
  /// Creates an [InboxScanException].
  const InboxScanException(this.message);

  /// A human-readable explanation.
  final String message;

  @override
  String toString() => 'InboxScanException: $message';
}

/// An AI-suggested task extracted from an email.
class SuggestedTask {
  /// Creates a [SuggestedTask].
  const SuggestedTask({
    required this.title,
    this.dueDateHint,
    required this.priority,
    this.sourceEmailId,
  });

  /// Parses a [SuggestedTask] from the Edge Function JSON.
  factory SuggestedTask.fromJson(Map<String, dynamic> json) {
    return SuggestedTask(
      title: (json['title'] as String? ?? '').trim(),
      dueDateHint: (json['dueDateHint'] as String?)?.trim(),
      priority: (json['priority'] as String? ?? 'none').trim().toLowerCase(),
      sourceEmailId: json['sourceEmailId'] as String?,
    );
  }

  /// Short imperative task title.
  final String title;

  /// Natural-language due-date hint (e.g. "Friday"), or null.
  final String? dueDateHint;

  /// Priority as a raw string: none | low | medium | high.
  final String priority;

  /// The Gmail message id this task was derived from, if any.
  final String? sourceEmailId;
}

/// An AI-derived job-application status update extracted from an email.
class JobUpdate {
  /// Creates a [JobUpdate].
  const JobUpdate({
    required this.company,
    required this.role,
    required this.status,
    required this.summary,
    this.sourceEmailId,
  });

  /// Parses a [JobUpdate] from the Edge Function JSON.
  factory JobUpdate.fromJson(Map<String, dynamic> json) {
    return JobUpdate(
      company: (json['company'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'other').trim().toLowerCase(),
      summary: (json['summary'] as String? ?? '').trim(),
      sourceEmailId: json['sourceEmailId'] as String?,
    );
  }

  /// The company the application is with.
  final String company;

  /// The role applied for.
  final String role;

  /// Status: applied | viewed | rejected | interview | offer | deadline | other.
  final String status;

  /// One-sentence human summary of the outcome.
  final String summary;

  /// The Gmail message id this update was derived from, if any.
  final String? sourceEmailId;
}

/// The result of an inbox scan.
class ScanResult {
  /// Creates a [ScanResult].
  const ScanResult({required this.tasks, required this.jobUpdates});

  /// Parses a [ScanResult] from the Edge Function response body.
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    final rawJobs = json['jobUpdates'] as List<dynamic>? ?? const [];
    return ScanResult(
      tasks: rawTasks
          .whereType<Map<String, dynamic>>()
          .map(SuggestedTask.fromJson)
          .where((t) => t.title.isNotEmpty)
          .toList(),
      jobUpdates: rawJobs
          .whereType<Map<String, dynamic>>()
          .map(JobUpdate.fromJson)
          .where((j) => j.company.isNotEmpty)
          .toList(),
    );
  }

  /// Suggested tasks to add.
  final List<SuggestedTask> tasks;

  /// Job-application updates detected.
  final List<JobUpdate> jobUpdates;
}

/// Calls the `extract-tasks` Edge Function and parses its response.
class InboxScanService {
  /// Creates an [InboxScanService].
  ///
  /// [getAccessToken] returns the current Google access token (or null when
  /// Gmail is not connected in this session).
  const InboxScanService({
    required this.client,
    required this.getAccessToken,
  });

  /// The Supabase client used to invoke the Edge Function.
  final SupabaseClient client;

  /// Returns the current Google access token, or null when Gmail is not
  /// connected in this session.
  final String? Function() getAccessToken;

  /// Scans the user's inbox and returns suggested tasks + job updates.
  ///
  /// Throws [GmailNotConnectedException] if no Google access token is
  /// available, and [InboxScanException] for any other failure.
  Future<ScanResult> scanInbox({int maxResults = 10}) async {
    final token = getAccessToken();
    if (token == null || token.isEmpty) {
      throw const GmailNotConnectedException();
    }

    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'extract-tasks',
        body: {'accessToken': token, 'maxResults': maxResults},
      );
    } catch (e) {
      throw InboxScanException('Could not reach the inbox assistant. ($e)');
    }

    final data = response.data;
    if (data is! Map) {
      throw const InboxScanException('The inbox assistant returned no data.');
    }
    final map = Map<String, dynamic>.from(data);

    // The function returns a 200 with { tasks, jobUpdates } on success, or a
    // non-2xx with { error }. `invoke` surfaces the body either way.
    if (map['error'] != null && map['tasks'] == null) {
      throw InboxScanException('Inbox scan failed: ${map['error']}');
    }

    return ScanResult.fromJson(map);
  }
}

/// Provides the [InboxScanService], wired to the current session's token.
final inboxScanServiceProvider = Provider<InboxScanService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InboxScanService(
    client: client,
    getAccessToken: () =>
        ref.read(authProvider.notifier).currentGoogleAccessToken(),
  );
});
