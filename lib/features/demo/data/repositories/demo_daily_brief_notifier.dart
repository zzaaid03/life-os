/// In-memory demo override of [DailyBriefNotifier]: exposes a fixed,
/// canned brief and never calls the `daily-brief` edge function.
library;

import 'package:life_os/features/home/domain/daily_brief_provider.dart';

const _demoBrief =
    'Alex, you have 2 overdue tasks: Follow up with Nimbus Labs recruiter, '
    'Submit portfolio to Vertex Design. 2 tasks are due today. 2 tasks are '
    'due in the next few days. Your top priority is "Follow up with Nimbus '
    'Labs recruiter". Meridian Financial, interview stage. Next step: Prep '
    'for Meridian Financial interview. You completed 2 tasks this week.';

/// A [DailyBriefNotifier] that never hits the network: [refresh] (and
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
