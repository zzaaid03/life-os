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
import 'package:life_os/features/subscriptions/data/models/subscription.dart';
import 'package:life_os/features/subscriptions/domain/billing.dart';
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

/// Parses a model-supplied `yyyy-mm-dd` string into local midnight, or null.
///
/// The model is instructed to emit a plain ISO date and nothing else, but it
/// is still a model: anything unparseable is dropped rather than guessed at.
/// Parsed as local midnight to match how the app stores dates.
DateTime? _parseIsoDate(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return null;
  final parts = trimmed.split('-').map(int.parse).toList();
  final parsed = DateTime(parts[0], parts[1], parts[2]);
  // Reject a roll-over from an impossible date such as 2026-02-31.
  if (parsed.month != parts[1] || parsed.day != parts[2]) return null;
  return parsed;
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
      dueDate: _parseIsoDate(json['dueDate']),
      dueDateHint: (json['dueDateHint'] as String?)?.trim(),
      priority: (json['priority'] as String? ?? 'none').trim().toLowerCase(),
      sourceEmailId: json['sourceEmailId'] as String?,
    );
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

/// An AI-suggested recurring charge extracted from an email.
///
/// This is a *suggestion*, never a stored row. It is deliberately looser than
/// [Subscription]: every field except the name may be null, because a model
/// that could not find an amount in an email must say so rather than invent
/// one. The review card hands these to the editor pre-filled and the user
/// confirms them, so a null here costs one typed field, while a guess would
/// put a wrong number on a screen about real money.
class SuggestedSubscription {
  /// Creates a [SuggestedSubscription].
  const SuggestedSubscription({
    required this.name,
    this.amountCents,
    this.currency,
    this.cycle,
    this.nextChargeDate,
    this.sourceEmailId,
  });

  /// Parses a [SuggestedSubscription] from the Edge Function JSON.
  ///
  /// The model sends the amount as the literal text it read in the email
  /// ("9.99"), not as cents. Converting it here means the arithmetic happens
  /// in tested Dart via the same [parseAmountCents] the editor's own field
  /// uses, instead of asking a language model to multiply by 100.
  factory SuggestedSubscription.fromJson(Map<String, dynamic> json) {
    return SuggestedSubscription(
      name: (json['name'] as String? ?? '').trim(),
      amountCents: _parseAmount(json['amount']),
      currency: _parseCurrency(json['currency']),
      cycle: _parseCycle(json['cycle']),
      nextChargeDate: _parseIsoDate(json['nextChargeDate']),
      sourceEmailId: json['sourceEmailId'] as String?,
    );
  }

  static int? _parseAmount(Object? raw) {
    // Accept a number too: a model told to send a string sometimes sends
    // 9.99 anyway, and that is still a faithful reading of the email.
    if (raw is num) return parseAmountCents(raw.toString());
    if (raw is! String) return null;
    return parseAmountCents(raw);
  }

  /// Normalises the currency to the exact `^[A-Z]{3}$` the column's CHECK
  /// constraint allows, or null.
  ///
  /// Null on anything else, including a bare symbol. `$` is deliberately NOT
  /// mapped to USD: it is equally CAD, AUD and several others, so resolving it
  /// would be a guess about the user's money. An unresolved currency leaves
  /// the editor on its default for the user to correct.
  static String? _parseCurrency(Object? raw) {
    if (raw is! String) return null;
    final upper = raw.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(upper)) return null;
    return upper;
  }

  /// Strictly parses the billing cycle, returning null on anything
  /// unrecognised.
  ///
  /// Deliberately not [BillingCycle.parse], which falls back to monthly. That
  /// fallback is right for reading a stored row we can still mostly show, and
  /// wrong here: it would silently turn "the model did not say" into a
  /// confident "monthly" and quietly change what the totals claim.
  static BillingCycle? _parseCycle(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim().toLowerCase();
    for (final cycle in BillingCycle.values) {
      if (cycle.name == value) return cycle;
    }
    return null;
  }

  /// The service or plan being charged for, e.g. "Netflix".
  final String name;

  /// The charge in cents, or null when the email did not state one clearly.
  final int? amountCents;

  /// Three-letter uppercase ISO code, or null when it could not be resolved.
  final String? currency;

  /// How often it recurs, or null when the email did not say.
  final BillingCycle? cycle;

  /// The next charge date at local midnight, or null.
  final DateTime? nextChargeDate;

  /// The Gmail message id this suggestion was derived from, if any.
  ///
  /// Carried through to the stored row, where the partial unique index on
  /// `(user_id, source_email_id)` stops the same email being added twice.
  final String? sourceEmailId;
}

/// The result of an inbox scan.
class ScanResult {
  /// Creates a [ScanResult].
  const ScanResult({
    required this.tasks,
    required this.jobUpdates,
    this.subscriptions = const [],
    this.scannedAccount,
    this.remaining = 0,
  });

  /// Parses a [ScanResult] from the Edge Function response body.
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    final rawJobs = json['jobUpdates'] as List<dynamic>? ?? const [];
    // A server that predates subscriptions omits this key entirely, which is
    // exactly what happens between shipping this client and deploying the
    // function. An absent key must mean "no suggestions", never an error.
    final rawSubs = json['subscriptions'] as List<dynamic>? ?? const [];
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
      subscriptions: rawSubs
          .whereType<Map<String, dynamic>>()
          .map(SuggestedSubscription.fromJson)
          // A nameless suggestion is unreviewable: the card would show a blank
          // row and the editor would open with nothing identifying it.
          .where((s) => s.name.isNotEmpty)
          .toList(),
      scannedAccount: (json['scannedAccount'] as String?)?.trim(),
      remaining: rawRemaining is num ? rawRemaining.toInt() : 0,
    );
  }

  /// Suggested tasks to add.
  final List<SuggestedTask> tasks;

  /// Job-application updates detected.
  final List<JobUpdate> jobUpdates;

  /// Recurring charges detected. Always empty against a server that predates
  /// the feature, and never auto-created: these surface as review cards.
  final List<SuggestedSubscription> subscriptions;

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
