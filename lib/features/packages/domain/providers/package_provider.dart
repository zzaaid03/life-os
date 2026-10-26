/// Riverpod providers for the Packages screen.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/data/repositories/package_repository.dart';
import 'package:riverpod/riverpod.dart';

/// The loading status of the packages list.
enum PackageListStatus { loading, loaded, error }

/// State managed by [PackageListNotifier].
class PackageListState {
  /// Creates a [PackageListState].
  const PackageListState({
    this.status = PackageListStatus.loading,
    this.packages = const <Package>[],
    this.error,
  });

  /// The current loading status.
  final PackageListStatus status;

  /// The loaded packages (live rows only).
  final List<Package> packages;

  /// An error message, if the last load failed.
  final String? error;
}

/// Loads and mutates the user's packages.
class PackageListNotifier extends StateNotifier<PackageListState> {
  /// Creates a [PackageListNotifier].
  PackageListNotifier(this._repository) : super(const PackageListState());

  final PackageRepository _repository;

  String? _userId;

  /// Loads packages for [userId].
  Future<void> load(String userId) async {
    _userId = userId;
    if (state.packages.isEmpty) {
      state = const PackageListState();
    }
    try {
      final packages = await _repository.fetchPackages(userId);
      state = PackageListState(
        status: PackageListStatus.loaded,
        packages: packages,
      );
    } catch (e) {
      debugPrint('Packages load failed: $e');
      // Keep a list that is already on screen and say the refresh failed.
      state = state.packages.isNotEmpty
          ? PackageListState(
              status: PackageListStatus.loaded,
              packages: state.packages,
              error:
                  "Couldn't refresh your packages. Check your connection and try again.",
            )
          : const PackageListState(
              status: PackageListStatus.error,
              error: 'Failed to load packages.',
            );
    }
  }

  /// Reloads for the last-loaded user.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  /// Marks a package delivered and reloads.
  Future<void> markDelivered(String id) async {
    await _repository.markDelivered(id);
    await refresh();
  }

  /// Soft-deletes a package and reloads.
  ///
  /// The row leaves the list at once, because a swiped Dismissible must be
  /// gone from the tree before its callback returns. A failed write reloads
  /// (so the row comes back) and rethrows.
  Future<void> softDelete(String id) async {
    state = PackageListState(
      status: state.status,
      packages: [
        for (final p in state.packages)
          if (p.id != id) p,
      ],
    );
    try {
      await _repository.softDelete(id);
    } catch (_) {
      await refresh();
      rethrow;
    }
    await refresh();
  }

  /// Brings a soft-deleted package back and reloads.
  Future<void> restore(String id) async {
    await _repository.restore(id);
    await refresh();
  }
}

/// Provides the [PackageListNotifier] and its state.
final packageListProvider =
    StateNotifierProvider<PackageListNotifier, PackageListState>((ref) {
      final notifier = PackageListNotifier(
        ref.watch(packageRepositoryProvider),
      );

      ref.listen<AuthState>(authProvider, (previous, next) {
        if (next.isAuthenticated &&
            next.userId != null &&
            (previous == null ||
                !previous.isAuthenticated ||
                previous.userId != next.userId)) {
          notifier.load(next.userId!);
        }
      });

      // Cold start: the session may already be restored, so load eagerly.
      final currentAuth = ref.read(authProvider);
      if (currentAuth.isAuthenticated && currentAuth.userId != null) {
        Future.microtask(() => notifier.load(currentAuth.userId!));
      }

      return notifier;
    });
