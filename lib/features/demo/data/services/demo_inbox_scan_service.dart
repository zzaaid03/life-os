/// In-memory demo override of [InboxScanService] — plays a realistic
/// scanning beat then returns fixed, canned results. Never calls the
/// `extract-tasks` edge function.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An [InboxScanService] that never hits the network — [scanInbox] waits a
/// couple of seconds then returns a fixed [ScanResult].
class DemoInboxScanService extends InboxScanService {
  /// Creates a [DemoInboxScanService].
  DemoInboxScanService() : super(Supabase.instance.client);

  @override
  Future<ScanResult> scanInbox({int maxResults = 10}) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    String dueHint(int days) {
      final date = now.add(Duration(days: days));
      return '${_weekday(date.weekday)} (${date.month}/${date.day})';
    }

    return ScanResult(
      scannedAccount: 'alex.demo@gmail.com',
      tasks: [
        SuggestedTask(
          title: 'Reply to Cascade Robotics recruiter about availability',
          dueDateHint: dueHint(1),
          priority: 'high',
          sourceEmailId: 'demo-email-cascade-recruiter',
        ),
        SuggestedTask(
          title: 'Complete coding challenge for Beacon Software',
          dueDateHint: dueHint(3),
          priority: 'medium',
          sourceEmailId: 'demo-email-beacon-challenge',
        ),
      ],
      jobUpdates: const [
        JobUpdate(
          company: 'Cascade Robotics',
          role: 'Software PM',
          status: 'applied',
          summary: 'Recruiter reached out about a PM opening.',
          sourceEmailId: 'demo-email-cascade-recruiter',
        ),
      ],
    );
  }
}

String _weekday(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[weekday - 1];
}
