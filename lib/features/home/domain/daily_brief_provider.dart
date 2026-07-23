/// Daily Brief provider.
///
/// Fetches a short summary of the user's day from the `daily-brief` Edge
/// Function. Loads once per session (lazily, when the dashboard first shows
/// the card), refreshes automatically when the task list changes, and can
/// be refreshed on demand.
library;

import 'dart:async';

import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
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
  DailyBriefNotifier(this._ref) : super(const DailyBriefState()) {
    _ref.listen<TaskListState>(taskListProvider, (previous, next) {
      final signature = _signatureFor(next.tasks);
      if (signature == _lastTaskSignature) return;
      _lastTaskSignature = signature;

      // Only auto-refresh once a brief has actually been loaded; the initial
      // fetch is handled by `loadIfNeeded()`.
      if (state.status == DailyBriefStatus.initial) return;
      _scheduleDebouncedRefresh();
    }, fireImmediately: false);
  }

  final Ref _ref;

  String? _lastTaskSignature;
  Timer? _debounceTimer;
  bool _refreshInFlight = false;
  bool _refreshPending = false;

  /// Cheap signature of the task list so unrelated rebuilds don't trigger
  /// a re-fetch — only an actual change to id/status/dueDate does.
  String _signatureFor(List<Task> tasks) {
    final sorted = [...tasks]..sort((a, b) => a.id.compareTo(b.id));
    return sorted
        .map(
          (t) =>
              '${t.id}:${t.status.name}:'
              '${t.dueDate?.toIso8601String() ?? 'null'}',
        )
        .join('|');
  }

  void _scheduleDebouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _debounceTimer = null;
      _runRefresh();
    });
  }

  Future<void> _runRefresh() async {
    if (_refreshInFlight) {
      _refreshPending = true;
      return;
    }
    _refreshInFlight = true;
    await refresh();
    _refreshInFlight = false;
    if (_refreshPending) {
      _refreshPending = false;
      await _runRefresh();
    }
  }

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
      final response = await client.functions.invoke(
        'daily-brief',
        body: {'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes},
      );
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// The app-wide daily brief.
final dailyBriefProvider =
    StateNotifierProvider<DailyBriefNotifier, DailyBriefState>((ref) {
      return DailyBriefNotifier(ref);
    });
