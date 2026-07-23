/// In-memory demo override of [DailyBriefNotifier] — exposes a fixed,
/// canned brief and never calls the `daily-brief` edge function.
library;

import 'package:life_os/features/home/domain/daily_brief_provider.dart';

const _demoBrief =
    'Morning, Alex. Your Meridian Financial interview prep is due today — '
    'make it the priority. 2 tasks are overdue, including following up with '
    'the Nimbus Labs recruiter. Nice work finishing the Apex Analytics '
    'take-home this week.';

/// A [DailyBriefNotifier] that never hits the network — [refresh] (and
/// therefore [loadIfNeeded], which calls it) just sets the fixed demo brief.
class DemoDailyBriefNotifier extends DailyBriefNotifier {
  /// Creates a [DemoDailyBriefNotifier].
  DemoDailyBriefNotifier(super.ref);

  @override
  Future<void> refresh() async {
    state = const DailyBriefState(
      status: DailyBriefStatus.loaded,
      brief: _demoBrief,
    );
  }
}
