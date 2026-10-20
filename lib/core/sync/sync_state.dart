/// Observable state of the native task sync, for the UI to display.
library;

import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

/// A snapshot of the task sync: running or not, last result, backlog.
@immutable
class SyncState {
  /// Creates a [SyncState].
  const SyncState({
    this.isSyncing = false,
    this.lastSuccessAt,
    this.lastError,
    this.pendingCount = 0,
  });

  /// Whether a sync run is in progress.
  final bool isSyncing;

  /// When the last fully successful run finished.
  final DateTime? lastSuccessAt;

  /// The error of the last run, or `null` if it succeeded.
  final String? lastError;

  /// Number of local tasks whose sync status is not synced.
  final int pendingCount;

  /// Returns a copy with [isSyncing] changed.
  SyncState copyWith({bool? isSyncing, int? pendingCount}) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSuccessAt: lastSuccessAt,
      lastError: lastError,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// Holds the [SyncState]; written only by the sync service.
class SyncStateNotifier extends StateNotifier<SyncState> {
  /// Creates a [SyncStateNotifier].
  SyncStateNotifier() : super(const SyncState());

  /// Marks the start of a run.
  void started() {
    if (!mounted) return;
    state = state.copyWith(isSyncing: true);
  }

  /// Marks the end of a run. A null [error] means success.
  void finished({required String? error, required int pendingCount}) {
    if (!mounted) return;
    state = SyncState(
      lastSuccessAt: error == null ? DateTime.now() : state.lastSuccessAt,
      lastError: error,
      pendingCount: pendingCount,
    );
  }
}

/// Provides the [SyncState] of the task sync.
final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>(
  (ref) => SyncStateNotifier(),
);
