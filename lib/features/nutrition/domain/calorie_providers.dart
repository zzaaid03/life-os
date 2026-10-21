/// State for the daily calorie target.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/nutrition/data/calorie_profile_repository.dart';
import 'package:life_os/features/nutrition/domain/calorie_target.dart';
import 'package:life_os/features/recipes/domain/providers/recipe_providers.dart';
import 'package:riverpod/riverpod.dart';

/// State of the saved calorie profile.
class CalorieProfileState {
  /// Creates a [CalorieProfileState].
  const CalorieProfileState({
    this.loaded = false,
    this.profile = const CalorieProfile(),
    this.loadFailed = false,
  });

  /// Whether the first load finished (successfully or not).
  final bool loaded;

  /// True when the load failed, so an empty [profile] means "unknown", not "unset".
  final bool loadFailed;

  /// The saved profile. Empty until loaded.
  final CalorieProfile profile;
}

/// Loads and saves the calorie profile.
class CalorieProfileNotifier extends StateNotifier<CalorieProfileState> {
  /// Creates a [CalorieProfileNotifier].
  CalorieProfileNotifier(this._repository) : super(const CalorieProfileState());

  final CalorieProfileRepository _repository;

  /// Loads the profile. A failure marks loaded with
  /// [CalorieProfileState.loadFailed] set, so the screen can refuse to save
  /// over data it never saw. The [userId] is unused: the repository reads the
  /// signed-in user itself.
  Future<void> load([String? userId]) async {
    try {
      final profile = await _repository.load();
      state = CalorieProfileState(loaded: true, profile: profile);
    } catch (e) {
      debugPrint('Calorie profile load failed: $e');
      state = CalorieProfileState(
        loaded: true,
        profile: state.profile,
        loadFailed: true,
      );
    }
  }

  /// Saves [profile]. Throws on failure so the caller can say so; the stored
  /// value only changes once the write succeeded.
  Future<void> save(CalorieProfile profile) async {
    if (state.loadFailed) throw StateError('Calorie profile never loaded');
    await _repository.save(profile);
    state = CalorieProfileState(loaded: true, profile: profile);
  }
}

/// Provides the [CalorieProfileNotifier].
final calorieProfileProvider =
    StateNotifierProvider<CalorieProfileNotifier, CalorieProfileState>((ref) {
      final notifier = CalorieProfileNotifier(
        ref.watch(calorieProfileRepositoryProvider),
      );
      autoLoadOnSignIn(ref, notifier.load);
      return notifier;
    });

/// The daily kcal target, or null when the profile is incomplete or invalid.
final dailyTargetProvider = Provider<int?>((ref) {
  final profile = ref.watch(calorieProfileProvider).profile;
  return dailyTargetKcal(profile, now: DateTime.now());
});
