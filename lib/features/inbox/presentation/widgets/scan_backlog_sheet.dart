/// Backlog choice sheet for the inbox scan.
///
/// Shown when there is more pending mail than one scan can get through.
/// Presentation only: it takes its data as a parameter and returns the
/// order the user chose, nothing more.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_radius.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/features/inbox/domain/inbox_scan_pending.dart';

/// Shows the backlog choice sheet.
///
/// Resolves to the [ScanOrder] the user picked, or `null` if they dismissed
/// the sheet without choosing.
Future<ScanOrder?> showScanBacklogSheet(
  BuildContext context,
  InboxScanPending pending,
) {
  return showModalBottomSheet<ScanOrder>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => ScanBacklogSheet(pending: pending),
  );
}

/// Lets the user choose which end of a mail backlog to scan from.
class ScanBacklogSheet extends StatelessWidget {
  /// Creates a [ScanBacklogSheet].
  const ScanBacklogSheet({required this.pending, super.key});

  /// How much mail is waiting and how much one scan will cover.
  final InboxScanPending pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You have ${pending.label} emails to catch up on',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'A scan works through ${pending.batchSize} at a time. '
              'Where should this one start?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _BacklogChoice(
              icon: Icons.new_releases_outlined,
              title: 'Newest first',
              subtitle: 'Start with what just arrived.',
              onTap: () => Navigator.of(context).pop(ScanOrder.newest),
            ),
            const SizedBox(height: AppSpacing.md),
            _BacklogChoice(
              icon: Icons.history_outlined,
              title: 'Oldest first',
              subtitle: 'Work forward through the backlog.',
              onTap: () => Navigator.of(context).pop(ScanOrder.oldest),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklogChoice extends StatelessWidget {
  const _BacklogChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
