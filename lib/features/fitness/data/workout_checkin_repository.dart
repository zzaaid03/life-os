/// Reads and writes the daily "did you train today?" check-in.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Check-in storage. Dates are local calendar dates as "YYYY-MM-DD".
abstract class WorkoutCheckinRepository {
  /// Whether the user trained on [localDate], or null when not answered yet.
  Future<bool?> fetch(String localDate);

  /// Saves the answer for [localDate], replacing an earlier one.
  Future<void> save(String localDate, {required bool trained});
}

/// Supabase-backed [WorkoutCheckinRepository].
class SupabaseWorkoutCheckinRepository implements WorkoutCheckinRepository {
  /// Creates a [SupabaseWorkoutCheckinRepository].
  const SupabaseWorkoutCheckinRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool?> fetch(String localDate) async {
    final rows = await _client
        .from('workout_checkins')
        .select('trained')
        .eq('local_date', localDate)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['trained'] as bool;
  }

  @override
  Future<void> save(String localDate, {required bool trained}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    final rows = await _client
        .from('workout_checkins')
        .upsert({
          'user_id': userId,
          'local_date': localDate,
          'trained': trained,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,local_date')
        .select('local_date');
    // RLS can make a write touch 0 rows without an error.
    if (rows.isEmpty) {
      throw StateError('Could not save the check-in: no row changed');
    }
  }
}

/// Provides the [WorkoutCheckinRepository].
final workoutCheckinRepositoryProvider = Provider<WorkoutCheckinRepository>((
  ref,
) {
  return SupabaseWorkoutCheckinRepository(ref.watch(supabaseClientProvider));
});
