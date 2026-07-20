/// Daily Brief provider.
///
/// Fetches a short AI-written summary of the user's day from the
/// `daily-brief` Edge Function. Loads once per session (lazily, when the
/// dashboard first shows the card) and can be refreshed on demand.
library;

import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the daily brief.
enum DailyBriefStatus { initial, loading, loaded, error }

/// State held by [DailyBriefNotifier].
class DailyBriefState {
  /// Creates a [DailyBriefState].
  const DailyBriefState({this.status = DailyBriefStatus.initial, this.brief});

  /// The current loading status.
  final DailyBriefStatus status;

  /// The brief text, when loaded.
  final String? brief;
}

/// Loads and refreshes the daily brief.
class DailyBriefNotifier extends StateNotifier<DailyBriefState> {
  /// Creates a [DailyBriefNotifier].
  DailyBriefNotifier(this._ref) : super(const DailyBriefState());

  final Ref _ref;

  /// Loads the brief if it hasn't been fetched yet this session.
  Future<void> loadIfNeeded() async {
    if (state.status != DailyBriefStatus.initial) return;
    await refresh();
  }

  /// Fetches (or re-fetches) the brief.
  Future<void> refresh() async {
    state = const DailyBriefState(status: DailyBriefStatus.loading);
    try {
      final client = _ref.read(supabaseClientProvider);
      final response = await client.functions.invoke('daily-brief');
      final data = response.data;
      final brief = data is Map ? data['brief'] as String? : null;
      if (brief == null || brief.isEmpty) {
        state = const DailyBriefState(status: DailyBriefStatus.error);
        return;
      }
      state = DailyBriefState(status: DailyBriefStatus.loaded, brief: brief);
    } catch (_) {
      state = const DailyBriefState(status: DailyBriefStatus.error);
    }
  }
}

/// The app-wide daily brief.
final dailyBriefProvider =
    StateNotifierProvider<DailyBriefNotifier, DailyBriefState>((ref) {
      return DailyBriefNotifier(ref);
    });
