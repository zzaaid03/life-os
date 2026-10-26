/// One package row on the Packages screen.
library;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/packages/data/models/package.dart';

/// Icon and label for each [PackageStatus]. Both are always shown, so the
/// status never relies on colour alone.
({IconData icon, String label}) packageStatusLook(PackageStatus status) {
  switch (status) {
    case PackageStatus.ordered:
      return (icon: Icons.receipt_long_outlined, label: 'Ordered');
    case PackageStatus.shipped:
      return (icon: Icons.local_shipping_outlined, label: 'Shipped');
    case PackageStatus.outForDelivery:
      return (icon: Icons.delivery_dining_outlined, label: 'Out for delivery');
    case PackageStatus.delivered:
      return (icon: Icons.check_circle_outline, label: 'Delivered');
  }
}

/// A package row: merchant, item, status, dates, carrier and tracking number.
class PackageTile extends StatelessWidget {
  /// Creates a [PackageTile].
  const PackageTile({super.key, required this.package, this.onMarkDelivered});

  /// The package to show.
  final Package package;

  /// Called from the menu. Null hides the menu (already delivered).
  final VoidCallback? onMarkDelivered;

  String? _dateLine() {
    final expected = package.expectedDate;
    final deliveredAt = package.deliveredAt;
    if (package.status == PackageStatus.delivered) {
      return deliveredAt == null
          ? null
          : 'Delivered ${formatDay(deliveredAt.toLocal())}';
    }
    return expected == null ? null : 'Expected ${formatDay(expected)}';
  }

  String? _carrierLine() {
    final parts = [
      if (package.carrier != null && package.carrier!.isNotEmpty)
        package.carrier!,
      if (package.trackingNumber != null && package.trackingNumber!.isNotEmpty)
        package.trackingNumber!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = packageStatusLook(package.status);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final item = package.item;
    final dateLine = _dateLine();
    final carrierLine = _carrierLine();
    final lastUpdate = package.lastUpdate;
    final merchant = package.merchant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant == null || merchant.isEmpty ? 'Package' : merchant,
                  style: theme.textTheme.titleMedium,
                ),
                if (item != null && item.isNotEmpty)
                  Text(item, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(look.icon, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Text(look.label, style: theme.textTheme.labelLarge),
                      ],
                    ),
                    if (dateLine != null)
                      Text(dateLine, style: theme.textTheme.bodySmall),
                  ],
                ),
                if (carrierLine != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    carrierLine,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                if (lastUpdate != null && lastUpdate.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lastUpdate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMarkDelivered != null)
            PopupMenuButton<String>(
              tooltip: 'Package actions',
              onSelected: (_) => onMarkDelivered!(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delivered',
                  child: Text('Mark delivered'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
