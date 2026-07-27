/// Search providers.
///
/// Tasks and goals are filtered in memory from lists the app already holds
/// (no network cost). Files are network-only, so their query is debounced
/// (300ms) and serialised: a request counter ignores any response that is
/// no longer the latest one, so a fast typist never has an older response
/// overwrite a newer one.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/files/data/repositories/file_repository.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/goals/domain/providers/goal_provider.dart';
import 'package:life_os/features/tasks/data/models/task.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';

/// The current, raw search query text.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Tasks matching the current query, filtered in memory.
///
/// Blank query yields no results and touches no data source.
final matchingTasksProvider = Provider<List<Task>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final tasks = ref.watch(taskListProvider).tasks;
  return tasks
      .where(
        (t) =>
            t.status != TaskStatus.archived &&
            (t.title.toLowerCase().contains(query) ||
                (t.description?.toLowerCase().contains(query) ?? false)),
      )
      .toList();
});

/// Goals matching the current query, filtered in memory.
///
/// Blank query yields no results and touches no data source.
final matchingGoalsProvider = Provider<List<Goal>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final goals = ref.watch(goalListProvider).goals;
  return goals
      .where(
        (g) =>
            g.status != GoalStatus.archived &&
            (g.title.toLowerCase().contains(query) ||
                (g.description?.toLowerCase().contains(query) ?? false)),
      )
      .toList();
});

/// State for the debounced file search.
class FileSearchState {
  /// Creates a [FileSearchState].
  const FileSearchState({this.results = const [], this.isLoading = false});

  /// The current result set for the latest completed query.
  final List<StoredFile> results;

  /// True while a debounced query is in flight.
  final bool isLoading;
}

/// Debounces and serialises the network-backed file search.
///
/// A new call to [search] restarts the 300ms debounce timer. When it fires,
/// a request id is captured; if a later call's response arrives first (or
/// this one arrives after being superseded), a stale response is dropped
/// instead of overwriting newer results.
class FileSearchNotifier extends StateNotifier<FileSearchState> {
  /// Creates a [FileSearchNotifier].
  FileSearchNotifier(this._repository) : super(const FileSearchState());

  final FileRepository _repository;
  Timer? _debounce;
  int _requestId = 0;

  /// Searches [userId]'s files for [query], debounced by 300ms.
  ///
  /// A blank/whitespace-only [query] clears results immediately with no
  /// network call.
  void search(String userId, String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _requestId++;
      state = const FileSearchState();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final requestId = ++_requestId;
      try {
        final results = await _repository.search(userId, trimmed);
        if (requestId != _requestId || !mounted) return;
        state = FileSearchState(results: results);
      } catch (_) {
        if (requestId != _requestId || !mounted) return;
        state = const FileSearchState();
      }
    });
  }

  /// Drops [file] from the currently displayed results without a re-query.
  void removeLocally(StoredFile file) {
    state = FileSearchState(
      results: state.results.where((f) => f.id != file.id).toList(),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// Provides the debounced [FileSearchNotifier] and its [FileSearchState].
final fileSearchProvider =
    StateNotifierProvider<FileSearchNotifier, FileSearchState>((ref) {
      return FileSearchNotifier(ref.watch(fileRepositoryProvider));
    });
