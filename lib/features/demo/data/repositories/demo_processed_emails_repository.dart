/// In-memory demo override of [ProcessedEmailsRepository] — always reports
/// nothing as processed so the canned scan results always appear fresh.
library;

import 'package:life_os/features/inbox/data/processed_emails_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [ProcessedEmailsRepository] that never hits the network: lookups
/// always return empty and marking processed is a no-op.
class DemoProcessedEmailsRepository extends ProcessedEmailsRepository {
  /// Creates a [DemoProcessedEmailsRepository].
  DemoProcessedEmailsRepository() : super(Supabase.instance.client);

  @override
  Future<Set<String>> getProcessedIds(
    String userId,
    List<String> emailIds,
  ) async {
    return const {};
  }

  @override
  Future<void> markProcessed(String userId, List<String> emailIds) async {}
}
