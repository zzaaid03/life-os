/// Profile repository interface.
///
/// Defines the contract for profile data operations.
library;

import 'package:life_os/features/profile/data/models/profile.dart';

/// Abstract repository for profile operations.
abstract class ProfileRepository {
  /// Fetches the profile for the given [userId].
  ///
  /// Returns `null` if no profile exists yet.
  Future<Profile?> getProfile(String userId);

  /// Creates or updates the profile for the given [userId].
  ///
  /// This is an upsert — it creates if missing, updates if exists.
  Future<Profile> upsertProfile(Profile profile);

  /// Updates only the display name of the profile.
  Future<Profile> updateDisplayName(String userId, String displayName);
}
