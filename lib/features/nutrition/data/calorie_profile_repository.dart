/// The body details behind the daily calorie target (`public.profiles`).
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and writes the seven calorie-target columns of the user's profile.
abstract class CalorieProfileRepository {
  /// The saved profile, or an empty one when nothing is stored yet.
  Future<CalorieProfile> load();

  /// Saves [p]. Throws on failure.
  Future<void> save(CalorieProfile p);
}

/// Supabase-backed [CalorieProfileRepository].
class SupabaseCalorieProfileRepository implements CalorieProfileRepository {
  /// Creates a [SupabaseCalorieProfileRepository].
  const SupabaseCalorieProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _columns =
      'weight_kg, height_cm, birth_year, sex, activity_level, '
      'calorie_goal, unit_system';

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  @override
  Future<CalorieProfile> load() async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', _userId())
        .maybeSingle();
    return row == null ? const CalorieProfile() : CalorieProfile.fromRow(row);
  }

  @override
  Future<void> save(CalorieProfile p) async {
    // Only these columns: never send the whole profile row.
    await _client.from('profiles').update(p.toRow()).eq('id', _userId());
  }
}

/// Provides the [CalorieProfileRepository]. Demo mode overrides it.
final calorieProfileRepositoryProvider = Provider<CalorieProfileRepository>((
  ref,
) {
  return SupabaseCalorieProfileRepository(ref.watch(supabaseClientProvider));
});
