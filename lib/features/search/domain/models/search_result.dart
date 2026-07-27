/// Unified search result types.
///
/// Search spans three sources that are fetched very differently: tasks and
/// goals are filtered from lists the app already holds in memory, while files
/// are queried server-side because they are network-only by design and are
/// never mirrored locally. This sealed type is what lets one results list
/// render all three without the UI caring where each came from.
library;

import 'package:equatable/equatable.dart';
import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// A single item matching a search query.
///
/// Sealed so a `switch` over results is exhaustive: adding a fourth searchable
/// type becomes a compile error at every render site instead of a silently
/// missing section.
sealed class SearchResult extends Equatable {
  /// Creates a [SearchResult].
  const SearchResult();

  /// The text the result is sorted and grouped by.
  String get title;
}

/// A task that matched the query.
class TaskSearchResult extends SearchResult {
  /// Creates a [TaskSearchResult].
  const TaskSearchResult(this.task);

  /// The matching task.
  final Task task;

  @override
  String get title => task.title;

  @override
  List<Object?> get props => [task];
}

/// A goal that matched the query.
class GoalSearchResult extends SearchResult {
  /// Creates a [GoalSearchResult].
  const GoalSearchResult(this.goal);

  /// The matching goal.
  final Goal goal;

  @override
  String get title => goal.title;

  @override
  List<Object?> get props => [goal];
}

/// A stored file that matched the query.
///
/// Search is the ONLY way to reach an uploaded file: there is deliberately no
/// browse list and no Files tab. That makes this the only place a file can be
/// opened or deleted, so both actions belong on its result tile.
class FileSearchResult extends SearchResult {
  /// Creates a [FileSearchResult].
  const FileSearchResult(this.file);

  /// The matching file.
  final StoredFile file;

  @override
  String get title => file.userNote.isNotEmpty ? file.userNote : file.fileName;

  @override
  List<Object?> get props => [file];
}
