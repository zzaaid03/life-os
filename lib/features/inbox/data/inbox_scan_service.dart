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
import 'package:life_os/features/inbox/domain/inbox_scan_pending.dart';
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
    this.dueDate,
    this.dueDateHint,
    required this.priority,
    this.sourceEmailId,
  });

  /// Parses a [SuggestedTask] from the Edge Function JSON.
  factory SuggestedTask.fromJson(Map<String, dynamic> json) {
    return SuggestedTask(
      title: (json['title'] as String? ?? '').trim(),
      dueDate: _parseDueDate(json['dueDate']),
      dueDateHint: (json['dueDateHint'] as String?)?.trim(),
      priority: (json['priority'] as String? ?? 'none').trim().toLowerCase(),
      sourceEmailId: json['sourceEmailId'] as String?,
    );
  }

  /// Parses the model's `dueDate` into local midnight, or null.
  ///
  /// The model is instructed to emit a plain ISO `yyyy-mm-dd` and nothing else,
  /// but it is still a model: anything unparseable is dropped rather than
  /// guessed at, which leaves the user picking a date by hand exactly as they
  /// do today. Parsed as local midnight to match how [Task] stores due dates.
  static DateTime? _parseDueDate(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return null;
    final parts = trimmed.split('-').map(int.parse).toList();
    final parsed = DateTime(parts[0], parts[1], parts[2]);
    // Reject a roll-over from an impossible date such as 2026-02-31.
    if (parsed.month != parts[1] || parsed.day != parts[2]) return null;
    return parsed;
  }

  /// Short imperative task title.
  final String title;

  /// Due date the email stated plainly, at local midnight, or null.
  ///
  /// Null is the common and correct case: the model emits a date only when the
  /// email says one outright, so an absent date means "the email did not say",
  /// never "the model could not decide".
  final DateTime? dueDate;

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
    this.remaining = 0,
  });

  /// Parses a [ScanResult] from the Edge Function response body.
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    final rawJobs = json['jobUpdates'] as List<dynamic>? ?? const [];
    final rawRemaining = json['remaining'];
    return ScanResult(
      tasks: rawTasks
          .whereType<Map<String, dynamic>>()
          .map(SuggestedTask.fromJson)
          .where((t) => t.title.isNotEmpty)
          .toList(),
      jobUpdates: rawJobs
          .whereType<Map<String, dynamic>>()
          .map(JobUpdate.fromJson)
          // Keep updates that carry meaningful info even without a company,
          // e.g. a rejection whose company the AI couldn't identify.
          .where((j) => j.summary.isNotEmpty || j.company.isNotEmpty)
          .toList(),
      scannedAccount: (json['scannedAccount'] as String?)?.trim(),
      remaining: rawRemaining is num ? rawRemaining.toInt() : 0,
    );
  }

  /// Suggested tasks to add.
  final List<SuggestedTask> tasks;

  /// Job-application updates detected.
  final List<JobUpdate> jobUpdates;

  /// The Gmail address that was scanned, as reported by the function.
  final String? scannedAccount;

  /// How many pending emails this scan did not get to. A server that
  /// predates this field, or the demo service, omits it and this is 0.
  final int remaining;
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
  Future<ScanResult> scanInbox({
    int maxResults = kScanBatchSize,
    ScanOrder order = ScanOrder.newest,
  }) async {
    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'extract-tasks',
        // tzOffsetMinutes anchors the model's date resolution to the user's
        // calendar. Without it the server reads dates in UTC and "due today"
        // lands a day out for anyone east of it, the same bug daily-brief hit.
        body: {
          'maxResults': maxResults,
          'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'order': order.wire,
        },
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

  /// Asks how many emails are waiting to be scanned, without analysing any
  /// of them.
  ///
  /// This call must never throw: it decides whether the scan screen offers a
  /// choice, so any failure (transport, malformed response, an `error` key,
  /// or a server that predates this feature and ignores `action`) degrades
  /// to zero pending, which is exactly today's behaviour, a scan just runs.
  Future<InboxScanPending> countPending() async {
    try {
      final response = await client.functions.invoke(
        'extract-tasks',
        body: {
          'action': 'count',
          'horizonDays': kScanHorizonDays,
          'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      final data = response.data;
      if (data is! Map) {
        return const InboxScanPending(pending: 0, capped: false);
      }
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        return const InboxScanPending(pending: 0, capped: false);
      }
      return InboxScanPending.fromJson(map);
    } catch (_) {
      return const InboxScanPending(pending: 0, capped: false);
    }
  }
}

/// Provides the [InboxScanService].
final inboxScanServiceProvider = Provider<InboxScanService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return InboxScanService(client);
});
