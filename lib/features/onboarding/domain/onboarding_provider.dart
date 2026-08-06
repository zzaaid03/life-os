/// Per-user "onboarding completed" state.
///
/// A DB trigger auto-creates a `profiles` row synchronously at sign-up time,
/// so `profile == null` is never a reliable "needs onboarding" signal. This
/// tracks completion locally instead, persisted with SharedPreferences and
/// keyed by user ID, so the router can gate `/create-profile` correctly.
library;

import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State of the current user's onboarding completion.
class OnboardingState {
  /// Creates an [OnboardingState].
  const OnboardingState({this.userId, this.completed = false, this.loaded = false});

  /// The user ID this state was loaded for, or null if logged out.
  final String? userId;

  /// Whether this user has completed onboarding (create-profile step).
  final bool completed;

  /// Whether the stored value has finished loading from disk.
  ///
  /// The router must wait for this to be `true` before deciding whether to
  /// redirect to `/create-profile`, otherwise a returning user briefly sees
  /// the default `completed: false` and gets redirected incorrectly.
  final bool loaded;

  /// Returns a copy with the given fields replaced.
  OnboardingState copyWith({String? userId, bool? completed, bool? loaded}) {
    return OnboardingState(
      userId: userId ?? this.userId,
      completed: completed ?? this.completed,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Loads and persists the current user's onboarding completion flag.
class OnboardingController extends StateNotifier<OnboardingState> {
  /// Creates an [OnboardingController] with no user loaded yet.
  OnboardingController() : super(const OnboardingState());

  String _keyFor(String userId) => 'onboarding_completed_$userId';

  /// Loads the onboarding flag for [userId], or resets to logged-out state
  /// if [userId] is null.
  Future<void> loadFor(String? userId) async {
    if (userId == null) {
      state = const OnboardingState();
      return;
    }

    state = OnboardingState(userId: userId, completed: false, loaded: false);

    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_keyFor(userId)) ?? false;
      // Guard against the user switching mid-load.
      if (state.userId != userId) return;
      state = OnboardingState(userId: userId, completed: completed, loaded: true);
    } catch (_) {
      if (state.userId != userId) return;
      // Treat any storage failure as "not completed": the worst case is
      // re-showing create-profile, which just re-upserts.
      state = OnboardingState(userId: userId, completed: false, loaded: true);
    }
  }

  /// Marks onboarding as completed for [userId] and persists it.
  Future<void> markCompleted(String userId) async {
    state = OnboardingState(userId: userId, completed: true, loaded: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFor(userId), true);
    } catch (_) {
      // If persistence fails the in-memory flag still lets the current
      // session proceed; the create-profile screen may reappear next launch.
    }
  }
}

/// The current user's onboarding completion state (persisted, per-user).
final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
      final controller = OnboardingController();
      ref.listen(authProvider, (prev, next) {
        if (prev?.userId != next.userId) controller.loadFor(next.userId);
      }, fireImmediately: true);
      return controller;
    });
