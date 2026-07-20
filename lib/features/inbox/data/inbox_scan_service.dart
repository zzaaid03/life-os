/// Inbox scan service.
///
/// Thin client over the deployed `extract-tasks` Supabase Edge Function.
/// The function identifies the user from their Supabase JWT, loads their
/// stored Google refresh token server-side, mints a fresh Gmail token, and
/// returns AI-derived actionable tasks and job-application updates. The app
/// never sends or holds a Google access token; email bodies never reach the
/// client.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when the user has no stored Google refresh token yet.
///
/// The Edge Function returns `{error: 'gmail_not_connected'}` (HTTP 200) in
/// this case. The UI should catch this and prompt the user to connect Gmail
/// by running the Google sign-in flow, which stores the refresh token.
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
      status: (json['status'] as String? ?? 'applied').trim().toLowerCase(),
      summary: (json['summary'] as String? ?? '').trim(),
      sourceEmailId: json['sourceEmailId'] as String?,
    );
  }

  /// The company the application is with.
  final String company;

  /// The role applied for.
  final String role;

  /// Status: applied | viewed | interview | rejected | accepted.
  final String status;

  /// One-sentence human summary of the outcome.
  final String summary;

  /// The Gmail message id this update was derived from, if any.
  final String? sourceEmailId;
}

/// The result of an inbox scan.
class ScanResult {
  /// Creates a [ScanResult].
  const ScanResult({
    required this.tasks,
    required this.jobUpdates,
    this.scannedAccount,
  });

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
          // Keep updates that carry meaningful info even without a company —
          // e.g. a rejection whose company the AI couldn't identify.
          .where((j) => j.summary.isNotEmpty || j.company.isNotEmpty)
          .toList(),
      scannedAccount: (json['scannedAccount'] as String?)?.trim(),
    );
  }

  /// Suggested tasks to add.
  final List<SuggestedTask> tasks;

  /// Job-application updates detected.
  final List<JobUpdate> jobUpdates;

  /// The Gmail address that was scanned, as reported by the function.
  final String? scannedAccount;
}

/// Calls the `extract-tasks` Edge Function and parses its response.
class InboxScanService {
  /// Creates an [InboxScanService].
  const InboxScanService(this.client);

  /// The Supabase client used to invoke the Edge Function. The user's JWT is
  /// attached automatically, so no Google token is sent from the app.
  final SupabaseClient client;

  /// Scans the user's inbox and returns suggested tasks + job updates.
  ///
  /// The function resolves the Gmail account server-side from the user's
  /// stored refresh token. Throws [GmailNotConnectedException] when no
  /// refresh token is stored yet, and [InboxScanException] for any other
  /// failure.
  Future<ScanResult> scanInbox({int maxResults = 10}) async {
    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'extract-tasks',
        body: {'maxResults': maxResults},
      );
    } catch (e) {
      throw InboxScanException('Could not reach the inbox assistant. ($e)');
    }

    final data = response.data;
    if (data is! Map) {
      throw const InboxScanException('The inbox assistant returned no data.');
    }
    final map = Map<String, dynamic>.from(data);

    // The function returns { error: 'gmail_not_connected' } (HTTP 200) when
    // the user has no stored refresh token yet.
    if (map['error'] == 'gmail_not_connected') {
      throw const GmailNotConnectedException();
    }
    if (map['error'] != null && map['tasks'] == null) {
      throw InboxScanException('Inbox scan failed: ${map['error']}');
    }

    return ScanResult.fromJson(map);
  }
}

/// Provides the [InboxScanService].
final inboxScanServiceProvider = Provider<InboxScanService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InboxScanService(client);
});
