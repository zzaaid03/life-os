/// Profile state provider using Riverpod.
///
/// Manages profile fetching, creation, and updates.
library;

import 'package:life_os/features/profile/data/models/profile.dart';
import 'package:life_os/features/profile/data/repositories/profile_repository.dart';
import 'package:life_os/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Possible states for profile loading.
enum ProfileStatus { initial, loading, loaded, error }

/// The profile state managed by [ProfileNotifier].
class ProfileState {
  /// Creates a [ProfileState].
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.error,
  });

  /// The current loading status.
  final ProfileStatus status;

  /// The user's profile, if loaded.
  final Profile? profile;

  /// An error message, if loading failed.
  final String? error;
}

/// Manages profile data and operations.
class ProfileNotifier extends StateNotifier<ProfileState> {
  /// Creates a [ProfileNotifier].
  ProfileNotifier(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  /// Loads the profile for the given [userId].
  Future<void> loadProfile(String userId) async {
    state = const ProfileState(status: ProfileStatus.loading);
    try {
      final profile = await _repository.getProfile(userId);
      state = ProfileState(
        status: profile != null ? ProfileStatus.loaded : ProfileStatus.initial,
        profile: profile,
      );
    } catch (e) {
      state = const ProfileState(
        status: ProfileStatus.error,
        error: 'Failed to load profile. Please try again.',
      );
    }
  }

  /// Creates or updates the profile.
  ///
  /// Throws if the upsert fails, so callers can react to the
  /// specific error. The error state is still set for UI observation.
  Future<void> upsertProfile(Profile profile) async {
    state = const ProfileState(status: ProfileStatus.loading);
    try {
      final updated = await _repository.upsertProfile(profile);
      state = ProfileState(status: ProfileStatus.loaded, profile: updated);
    } catch (e) {
      state = ProfileState(status: ProfileStatus.error, error: e.toString());
      rethrow;
    }
  }

  /// Updates the user's display name.
  Future<void> updateDisplayName(String userId, String displayName) async {
    state = const ProfileState(status: ProfileStatus.loading);
    try {
      final updated = await _repository.updateDisplayName(userId, displayName);
      state = ProfileState(status: ProfileStatus.loaded, profile: updated);
    } catch (e) {
      state = const ProfileState(
        status: ProfileStatus.error,
        error: 'Failed to update name. Please try again.',
      );
    }
  }
}

/// The profile provider.
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((
  ref,
) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});
