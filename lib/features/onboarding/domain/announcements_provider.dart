/// Announcements (onboarding / "what's new") acknowledgement state.
///
/// Tracks the highest release version the user has seen, persisted with
/// SharedPreferences, so the onboarding/what's-new carousel is shown only
/// for releases the user hasn't acknowledged yet.
library;

import 'package:life_os/features/onboarding/domain/release_notes.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for the acknowledged release version.
const String _kAnnouncementsAckedVersionKey = 'announcements_acked_version';

/// State of the user's announcement acknowledgements.
class AnnouncementsState {
  /// Creates an [AnnouncementsState].
  const AnnouncementsState({this.ackedVersion = 0, this.loaded = false});

  /// Highest release version the user has acknowledged.
  final int ackedVersion;

  /// Whether the stored value has finished loading from disk.
  ///
  /// The UI must wait for this to be `true` before deciding whether to show
  /// the carousel — otherwise a returning user briefly sees the default
  /// `ackedVersion: 0` and gets the tour again incorrectly.
  final bool loaded;

  /// Returns a copy with the given fields replaced.
  AnnouncementsState copyWith({int? ackedVersion, bool? loaded}) {
    return AnnouncementsState(
      ackedVersion: ackedVersion ?? this.ackedVersion,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Loads and persists the user's acknowledged announcements version.
class AnnouncementsController extends StateNotifier<AnnouncementsState> {
  /// Creates an [AnnouncementsController] and eagerly loads the stored value.
  AnnouncementsController() : super(const AnnouncementsState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final acked = prefs.getInt(_kAnnouncementsAckedVersionKey) ?? 0;
      state = AnnouncementsState(ackedVersion: acked, loaded: true);
    } catch (_) {
      // Treat any storage failure as "nothing acknowledged" — the worst
      // case is showing the tour again, which is safe.
      state = const AnnouncementsState(ackedVersion: 0, loaded: true);
    }
  }

  /// Marks all current releases as seen and persists it.
  Future<void> acknowledgeAll() async {
    state = state.copyWith(ackedVersion: kLatestReleaseVersion);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kAnnouncementsAckedVersionKey,
        kLatestReleaseVersion,
      );
    } catch (_) {
      // If persistence fails the in-memory flag still lets the current
      // session proceed; the tour may reappear next launch.
    }
  }
}

/// The user's announcement acknowledgement state (persisted).
final announcementsProvider =
    StateNotifierProvider<AnnouncementsController, AnnouncementsState>((ref) {
      return AnnouncementsController();
    });

/// Releases newer than [acked], in ascending version order.
List<Release> unseenReleases(int acked) {
  return kReleases.where((r) => r.version > acked).toList();
}
