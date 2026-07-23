/// In-memory demo [ProfileRepository] — always returns a non-null demo
/// profile so the router never redirects to `/create-profile`.
library;

import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/profile/data/models/profile.dart';
import 'package:life_os/features/profile/data/repositories/profile_repository.dart';

/// Stateless demo [ProfileRepository] for the persona "Alex."
class DemoProfileRepository implements ProfileRepository {
  /// Creates a [DemoProfileRepository] with a fixed demo [Profile].
  DemoProfileRepository() : _profile = _buildProfile();

  final Profile _profile;

  static Profile _buildProfile() {
    final now = DateTime.now();
    return Profile(
      id: demoUserId,
      displayName: 'Alex',
      email: 'alex.demo@lifeos.app',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<Profile?> getProfile(String userId) async => _profile;

  @override
  Future<Profile> upsertProfile(Profile profile) async => profile;

  @override
  Future<Profile> updateDisplayName(String userId, String displayName) async {
    return _profile.copyWith(displayName: displayName);
  }
}
