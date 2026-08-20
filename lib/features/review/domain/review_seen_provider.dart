/// Per-user "last seen weekly review" state.
///
/// Stores WHICH week was last seen, not a bare bool. A bool cannot re-raise
/// the pointer once a new week ends; a week identifier can, by simply not
/// matching the current week anymore.
library;

import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/review/domain/weekly_review.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State of the current user's last-seen weekly review.
class ReviewSeenState {
  /// Creates a [ReviewSeenState].
  const ReviewSeenState({this.userId, this.lastSeenWeekStart, this.loaded = false});

  /// The user ID this state was loaded for, or null if logged out.
  final String? userId;

  /// ISO 8601 date string of the last week's `weekStart` the user opened
  /// the review for, or null if never opened.
  final String? lastSeenWeekStart;

  /// Whether the stored value has finished loading from disk.
  final bool loaded;

  /// Whether there is a weekly review the user has not yet opened.
  ///
  /// True once loaded, as long as the stored week does not match the
  /// current most-recently-ended week.
  bool hasUnseenReview(DateTime now) {
    if (!loaded) return false;
    final currentWeekStart = mostRecentEndedWeekStart(now).toIso8601String();
    return lastSeenWeekStart != currentWeekStart;
  }

  /// Returns a copy with the given fields replaced.
  ReviewSeenState copyWith({
    String? userId,
    String? lastSeenWeekStart,
    bool? loaded,
  }) {
    return ReviewSeenState(
      userId: userId ?? this.userId,
      lastSeenWeekStart: lastSeenWeekStart ?? this.lastSeenWeekStart,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Loads and persists the current user's last-seen weekly review week.
class ReviewSeenController extends StateNotifier<ReviewSeenState> {
  /// Creates a [ReviewSeenController] with no user loaded yet.
  ReviewSeenController() : super(const ReviewSeenState());

  String _keyFor(String userId) => 'weekly_review_seen_$userId';

  /// Loads the last-seen week for [userId], or resets to logged-out state
  /// if [userId] is null.
  Future<void> loadFor(String? userId) async {
    if (userId == null) {
      state = const ReviewSeenState();
      return;
    }

    state = ReviewSeenState(userId: userId, lastSeenWeekStart: null, loaded: false);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_keyFor(userId));
      // Guard against the user switching mid-load.
      if (state.userId != userId) return;
      state = ReviewSeenState(
        userId: userId,
        lastSeenWeekStart: lastSeen,
        loaded: true,
      );
    } catch (_) {
      if (state.userId != userId) return;
      // Treat any storage failure as "not seen": the worst case is the
      // pointer re-showing, which is harmless.
      state = ReviewSeenState(userId: userId, lastSeenWeekStart: null, loaded: true);
    }
  }

  /// Marks [weekStart] as seen for [userId] and persists it.
  Future<void> markSeen(String userId, DateTime weekStart) async {
    final weekStartIso = weekStart.toIso8601String();
    state = ReviewSeenState(
      userId: userId,
      lastSeenWeekStart: weekStartIso,
      loaded: true,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      // Guard against the user switching mid-write.
      if (state.userId != userId) return;
      await prefs.setString(_keyFor(userId), weekStartIso);
    } catch (_) {
      // If persistence fails the in-memory flag still hides the pointer
      // for the current session; it may reappear next launch.
    }
  }
}

/// The current user's last-seen weekly review state (persisted, per-user).
final reviewSeenProvider =
    StateNotifierProvider<ReviewSeenController, ReviewSeenState>((ref) {
      final controller = ReviewSeenController();
      ref.listen(authProvider, (prev, next) {
        if (prev?.userId != next.userId) controller.loadFor(next.userId);
      }, fireImmediately: true);
      return controller;
    });
