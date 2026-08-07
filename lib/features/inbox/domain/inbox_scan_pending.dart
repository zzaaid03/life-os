/// Shared contract for incremental inbox scanning.
///
/// The scan used to read the 10 most recent inbox emails every time, with no
/// record of where it left off. If more than 10 arrived between scans the
/// older ones fell out of the window and were never read, and nothing told the
/// user. This file defines the vocabulary the client and `extract-tasks` share
/// so a scan can work through everything instead.
///
/// Coverage comes from a set difference, not a watermark. The server lists the
/// inbox ids inside a rolling horizon, subtracts the ids already recorded in
/// `processed_emails`, and what remains is pending. A single watermark could
/// not express "the newest 20 and the oldest 20 are done but the middle is
/// not", which is exactly what letting the user pick an order produces.
library;

/// Which end of the pending pile a scan should work from.
enum ScanOrder {
  /// Most recent pending email first. The default, and what someone tapping
  /// scan expects to see.
  newest,

  /// Oldest pending email first, for working forward through a backlog.
  oldest;

  /// Wire value sent to `extract-tasks`.
  String get wire => name;
}

/// Above this many pending emails, the user chooses how to work through them
/// instead of the app silently picking. Below it a scan just runs.
const int kScanChoiceThreshold = 50;

/// How far back a scan will ever look, in days.
///
/// This bounds the work: without it, counting pending emails for someone who
/// has never scanned would mean paging their entire mailbox. An email older
/// than this that was never scanned is not something the app should suddenly
/// surface as a task.
const int kScanHorizonDays = 30;

/// How many emails one scan sends to the model.
///
/// Kept small on purpose. The extractor's accuracy is per email, so a bigger
/// batch multiplies both cost and any false-positive rate rather than
/// improving anything.
const int kScanBatchSize = 20;

/// The result of asking how much mail is waiting, without analysing any of it.
///
/// This is a cheap call: it lists Gmail message ids and compares them against
/// `processed_emails`. It never fetches an email body and never calls the
/// model, so it is safe to run every time the scan screen opens.
class InboxScanPending {
  const InboxScanPending({
    required this.pending,
    required this.capped,
    this.horizonDays = kScanHorizonDays,
  });

  /// Builds a pending count from the `extract-tasks` count response.
  ///
  /// Anything missing or malformed reads as zero pending rather than throwing.
  /// A count is an optimisation, so a bad one should degrade to "just scan"
  /// instead of blocking the feature.
  factory InboxScanPending.fromJson(Map<String, dynamic> json) {
    final raw = json['pending'];
    final pending = raw is num ? raw.toInt() : 0;
    return InboxScanPending(
      pending: pending < 0 ? 0 : pending,
      capped: json['capped'] == true,
      horizonDays: (json['horizonDays'] as num?)?.toInt() ?? kScanHorizonDays,
    );
  }

  /// Emails inside the horizon that have never been analysed.
  final int pending;

  /// True when the real number is higher than [pending] but the server stopped
  /// counting. Display this as "500+" rather than as an exact figure.
  final bool capped;

  /// The horizon the count was taken over, echoed back by the server.
  final int horizonDays;

  /// Whether to ask the user how they want to work through the backlog.
  bool get needsChoice => pending > kScanChoiceThreshold;

  /// How many a single scan will actually get through.
  int get batchSize => pending < kScanBatchSize ? pending : kScanBatchSize;

  /// Count for display, honouring the server's cap.
  String get label => capped ? '$pending+' : '$pending';
}
