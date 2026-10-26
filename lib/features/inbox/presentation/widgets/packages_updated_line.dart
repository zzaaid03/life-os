/// Tappable "N packages updated" line shown after a scan that saved packages.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/theme/app_spacing.dart';

/// Opens the Packages screen. The packages are already saved by the scan.
class PackagesUpdatedLine extends StatelessWidget {
  /// Creates a [PackagesUpdatedLine].
  const PackagesUpdatedLine({super.key, required this.count});

  /// How many packages the scan inserted or changed.
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return InkWell(
      onTap: () => context.push(AppRoutes.packages),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                count == 1 ? '1 package updated' : '$count packages updated',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
