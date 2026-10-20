/// Banner shown on native when task changes failed to sync.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/sync/sync_state.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';

/// A slim banner with a retry button. Renders nothing on web, or unless the
/// last sync failed and some tasks are still waiting to be pushed.
class SyncStatusBanner extends ConsumerWidget {
  /// Creates a [SyncStatusBanner].
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();

    final sync = ref.watch(syncStateProvider);
    if (sync.lastError == null || sync.pendingCount <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Some changes haven’t synced yet. '
              'They’re saved on this phone.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (sync.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () => ref.read(taskListProvider.notifier).syncNow(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
