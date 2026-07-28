/// Repository interface for the learning system's inferred facts.
///
/// Facts are NETWORK-ONLY, the same deliberate choice already made for goals
/// and files: no Drift table, no offline sync. With no connection the mirror
/// is empty rather than stale.
///
/// This client never WRITES a fact. Facts are produced exclusively by the
/// `infer-facts` Edge Function, which is the only place with the evidence to
/// justify one. The only mutation available here is [suppress], the user
/// saying "that's not right".
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/learning/data/models/user_fact.dart';
import 'package:life_os/features/learning/data/repositories/supabase_fact_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Abstract repository for [UserFact] records.
abstract class FactRepository {
  /// Fetches this user's live (non-suppressed) facts, most recently
  /// confirmed first.
  Future<List<UserFact>> getAll(String userId);

  /// Marks a fact as rejected by the user.
  ///
  /// Implementations set `suppressed_at` rather than deleting the row. That
  /// is what makes the rejection permanent: the inference function upserts on
  /// `(user_id, fact_key)` and never clears the column, so re-deriving the
  /// same fact cannot bring it back. A hard delete would let it reappear the
  /// very next day.
  Future<void> suppress(UserFact fact);
}

/// Provides the [FactRepository].
final factRepositoryProvider = Provider<FactRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseFactRepository(client);
});
