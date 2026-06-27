/// Supabase implementation of [ProfileRepository].
///
/// Handles all profile data operations through Supabase.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/profile/data/models/profile.dart';
import 'package:life_os/features/profile/data/repositories/profile_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider for the [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseProfileRepository(supabase);
});

/// Supabase-backed implementation of [ProfileRepository].
class SupabaseProfileRepository implements ProfileRepository {
  /// Creates a [SupabaseProfileRepository].
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'profiles';

  @override
  Future<Profile?> getProfile(String userId) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;

    return Profile.fromJson(response);
  }

  @override
  Future<Profile> upsertProfile(Profile profile) async {
    await _client.from(_table).upsert(profile.toJson());

    // Fetch the upserted profile to get server-computed fields
    final updated = await getProfile(profile.id);
    return updated ?? profile;
  }

  @override
  Future<Profile> updateDisplayName(String userId, String displayName) async {
    await _client
        .from(_table)
        .update({
          'display_name': displayName,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);

    final updated = await getProfile(userId);
    if (updated == null) {
      throw StateError('Profile not found after update');
    }
    return updated;
  }
}
