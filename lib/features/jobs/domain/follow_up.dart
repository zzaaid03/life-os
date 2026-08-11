/// Pure logic for surfacing job applications that have gone quiet.
library;

import 'package:life_os/features/jobs/data/models/job_application.dart';

/// Statuses that mean the employer hasn't yet responded, i.e. worth a
/// follow-up. `rejected`/`accepted`/`interview` mean the employer already
/// responded or the loop is closed, so they never qualify.
const _followUpEligibleStatuses = {'applied', 'viewed'};

/// Returns the applications in [apps] that have had no employer response
/// for at least [threshold] as of [now], oldest first.
///
/// The reference date per application is `appliedAt ?? updatedAt`. Never
/// throws on an empty [apps] list.
List<JobApplication> staleApplications(
  List<JobApplication> apps,
  DateTime now, {
  Duration threshold = const Duration(days: 14),
}) {
  final stale = apps.where((app) {
    final status = app.status.toLowerCase().trim();
    if (!_followUpEligibleStatuses.contains(status)) return false;

    final reference = app.appliedAt ?? app.updatedAt;
    return now.difference(reference) >= threshold;
  }).toList();

  stale.sort((a, b) {
    final referenceA = a.appliedAt ?? a.updatedAt;
    final referenceB = b.appliedAt ?? b.updatedAt;
    return referenceA.compareTo(referenceB);
  });

  return stale;
}
