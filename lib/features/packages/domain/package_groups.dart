/// Splits the package list into the sections the Packages screen shows.
library;

import 'package:life_os/features/packages/data/models/package.dart';

/// How long a delivered package stays in "Delivered" before it moves to
/// "Older".
const Duration kDeliveredRecentWindow = Duration(days: 7);

/// The packages grouped for display.
class PackageGroups {
  /// Creates [PackageGroups].
  const PackageGroups({
    required this.onTheWay,
    required this.delivered,
    required this.older,
  });

  /// Not delivered yet, soonest expected date first, no date last.
  final List<Package> onTheWay;

  /// Delivered within the last 7 days, newest first.
  final List<Package> delivered;

  /// Delivered more than 7 days ago, newest first.
  final List<Package> older;

  /// Whether there is nothing to show at all.
  bool get isEmpty => onTheWay.isEmpty && delivered.isEmpty && older.isEmpty;
}

/// Groups [packages] as of [now]. Deleted packages are left out. A delivered
/// package with no `delivered_at` counts as recent, so it never vanishes.
PackageGroups groupPackages(List<Package> packages, DateTime now) {
  final cutoff = now.toUtc().subtract(kDeliveredRecentWindow);
  final onTheWay = <Package>[];
  final delivered = <Package>[];
  final older = <Package>[];

  for (final p in packages) {
    if (p.isDeleted) continue;
    if (p.status != PackageStatus.delivered) {
      onTheWay.add(p);
    } else if (p.deliveredAt != null && p.deliveredAt!.isBefore(cutoff)) {
      older.add(p);
    } else {
      delivered.add(p);
    }
  }

  onTheWay.sort((a, b) {
    final x = a.expectedDate;
    final y = b.expectedDate;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  int newestFirst(Package a, Package b) =>
      (b.deliveredAt ?? epoch).compareTo(a.deliveredAt ?? epoch);

  delivered.sort(newestFirst);
  older.sort(newestFirst);
  return PackageGroups(onTheWay: onTheWay, delivered: delivered, older: older);
}
