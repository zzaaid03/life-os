/// In-memory demo override of [InboxScanService]: plays a realistic
/// scanning beat then returns fixed, canned results. Never calls the
/// `extract-tasks` edge function.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/inbox/domain/inbox_scan_pending.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An [InboxScanService] that never hits the network: [scanInbox] waits a
/// couple of seconds then returns a fixed [ScanResult].
class DemoInboxScanService extends InboxScanService {
  /// Creates a [DemoInboxScanService].
  DemoInboxScanService() : super(Supabase.instance.client);

  @override
  Future<ScanResult> scanInbox({
    int maxResults = kScanBatchSize,
    ScanOrder order = ScanOrder.newest,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    DateTime dueDate(int days) {
      final date = now.add(Duration(days: days));
      return DateTime(date.year, date.month, date.day);
    }

    String dueHint(int days) {
      final date = now.add(Duration(days: days));
      return '${_weekday(date.weekday)} (${date.month}/${date.day})';
    }

    return ScanResult(
      scannedAccount: 'alex.demo@gmail.com',
      tasks: [
        SuggestedTask(
          title: 'Reply to Beacon Software to confirm your interview time',
          dueDateHint: dueHint(1),
          priority: 'high',
          sourceEmailId: 'demo-email-beacon-interview',
        ),
        SuggestedTask(
          title: 'Send the signed rental contract back to the landlord',
          dueDateHint: dueHint(3),
          priority: 'medium',
          sourceEmailId: 'demo-email-landlord-contract',
        ),
        SuggestedTask(
          title: r'Pay your electric bill, $84.12 due',
          dueDate: dueDate(5),
          dueDateHint: dueHint(5),
          priority: 'high',
          sourceEmailId: 'demo-email-electric-bill',
        ),
        SuggestedTask(
          title: 'Cancel or confirm your streaming subscription renewal',
          dueDate: dueDate(6),
          dueDateHint: dueHint(6),
          priority: 'medium',
          sourceEmailId: 'demo-email-streaming-renewal',
        ),
        SuggestedTask(
          title: 'Attend your dentist appointment',
          dueDate: dueDate(4),
          dueDateHint: dueHint(4),
          priority: 'medium',
          sourceEmailId: 'demo-email-dentist-appointment',
        ),
      ],
      jobUpdates: const [
        JobUpdate(
          company: 'Beacon Software',
          role: 'Product Manager',
          status: 'interview',
          summary:
              'Beacon Software invited you to a first-round interview for '
              'the Product Manager role.',
          sourceEmailId: 'demo-email-beacon-interview',
        ),
        JobUpdate(
          company: 'Cascade Robotics',
          role: 'Associate Product Manager',
          status: 'rejected',
          summary:
              'Cascade Robotics is not moving forward with your application '
              'for the Associate Product Manager role.',
          sourceEmailId: 'demo-email-cascade-decision',
        ),
      ],
    );
  }

  @override
  Future<InboxScanPending> countPending() async {
    return const InboxScanPending(pending: 0, capped: false);
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
