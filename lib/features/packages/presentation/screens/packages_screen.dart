/// The Packages screen: what is on the way, what arrived, and older ones.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/widgets/error_snackbar.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/domain/package_groups.dart';
import 'package:life_os/features/packages/domain/providers/package_provider.dart';
import 'package:life_os/features/packages/presentation/widgets/package_tile.dart';

/// Lists the user's packages, filled in by inbox scans.
class PackagesScreen extends ConsumerWidget {
  /// Creates a [PackagesScreen].
  const PackagesScreen({super.key});

  Future<void> _markDelivered(
    BuildContext context,
    WidgetRef ref,
    Package package,
  ) async {
    try {
      await ref.read(packageListProvider.notifier).markDelivered(package.id);
    } catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Could not mark the package delivered.');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Package package,
  ) async {
    final notifier = ref.read(packageListProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await notifier.softDelete(package.id);
    } catch (_) {
      if (context.mounted) {
        showErrorSnackBar(context, 'Could not delete the package.');
      }
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Package deleted'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await notifier.restore(package.id);
            } catch (_) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Could not restore the package.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Package package) {
    final delivered = package.status == PackageStatus.delivered;
    return Dismissible(
      key: ValueKey('package-${package.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      onDismissed: (_) => _delete(context, ref, package),
      child: PackageTile(
        package: package,
        onMarkDelivered: delivered
            ? null
            : () => _markDelivered(context, ref, package),
      ),
    );
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(packageListProvider);
    listenForRefreshError(
      ref,
      context,
      packageListProvider.select(
        (s) => s.status == PackageListStatus.loaded ? s.error : null,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Packages')),
      body: SafeArea(child: _body(context, ref, state)),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, PackageListState state) {
    if (state.status == PackageListStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == PackageListStatus.error) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error ?? 'Failed to load packages.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () =>
                    ref.read(packageListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final groups = groupPackages(state.packages, DateTime.now());
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'No packages yet. Run an inbox scan to find your orders.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(packageListProvider.notifier).refresh(),
      child: ListView(
        children: [
          if (groups.onTheWay.isNotEmpty) ...[
            _header(context, 'On the way'),
            for (final p in groups.onTheWay) _row(context, ref, p),
          ],
          if (groups.delivered.isNotEmpty) ...[
            _header(context, 'Delivered'),
            for (final p in groups.delivered) _row(context, ref, p),
          ],
          if (groups.older.isNotEmpty)
            ExpansionTile(
              title: Text('Older (${groups.older.length})'),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [for (final p in groups.older) _row(context, ref, p)],
            ),
        ],
      ),
    );
  }
}
