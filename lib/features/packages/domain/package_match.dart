/// Pure matching of scan package updates against existing packages.
///
/// No I/O here so every rule can be tested. The repository loads the
/// candidate rows, calls [matchPackageUpdates], then writes the result.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/domain/package_number.dart';

/// What to write after matching a batch of updates.
class PackageChanges {
  /// Creates [PackageChanges].
  const PackageChanges({
    required this.inserts,
    required this.updates,
    required this.changedCount,
  });

  /// Brand-new packages (their `id` is empty).
  final List<Package> inserts;

  /// Existing packages in their final merged state.
  final List<Package> updates;

  /// How many packages were inserted or visibly changed. A known package
  /// whose email told us nothing new is still rewritten (last email time) but
  /// does not count.
  final int changedCount;
}

/// Applies [updates] one at a time against a working copy of [existing], so
/// two emails in one batch about the same package land on the same row.
///
/// Identity uses ONE field: the tracking number, else the order number. A
/// match on a deleted package is skipped, never revived.
PackageChanges matchPackageUpdates(
  List<Package> existing,
  List<PackageUpdate> updates, {
  required DateTime now,
}) {
  final working = <_Entry>[for (final p in existing) _Entry(p, isNew: false)];

  for (final u in updates) {
    final match = _find(working, u);
    if (match == null) {
      final entry = _Entry(
        _merge(
          Package(id: '', status: u.status),
          u,
          now,
        ),
        isNew: true,
      )..dirty = true;
      working.add(entry);
      continue;
    }
    if (match.pkg.isDeleted) continue;
    final merged = _merge(match.pkg, u, now);
    if (_visiblyDiffers(match.pkg, merged)) match.changed = true;
    match.pkg = merged;
    match.dirty = true;
  }

  return PackageChanges(
    inserts: [
      for (final e in working)
        if (e.isNew) e.pkg,
    ],
    updates: [
      for (final e in working)
        if (!e.isNew && e.dirty) e.pkg,
    ],
    changedCount: [
      for (final e in working)
        if (e.isNew || e.changed) e,
    ].length,
  );
}

_Entry? _find(List<_Entry> working, PackageUpdate u) {
  final tracking = u.trackingNumber;
  if (tracking != null) {
    for (final e in working) {
      // Stored rows may predate normalization (e.g. a saved "#305-..."), so
      // normalize them before comparing.
      if (normalizePackageNumber(e.pkg.trackingNumber) == tracking) return e;
    }
  }
  final order = u.orderNumber;
  if (order != null) {
    for (final e in working) {
      if (normalizePackageNumber(e.pkg.orderNumber) != order) continue;
      // Same order, but it already has a different tracking number and this
      // email brings its own: a split shipment, so a separate package.
      if (e.pkg.trackingNumber != null && tracking != null) continue;
      return e;
    }
  }
  return null;
}

Package _merge(Package old, PackageUpdate u, DateTime now) {
  final status = u.status.rank > old.status.rank ? u.status : old.status;
  final becameDelivered =
      status == PackageStatus.delivered && old.deliveredAt == null;
  // Emails can arrive newest first, so an older one must not overwrite the
  // details of a package that is further along.
  final advances = u.status.rank >= old.status.rank;
  return old.copyWith(
    merchant: old.merchant ?? u.merchant,
    item: old.item ?? u.item,
    carrier: old.carrier ?? u.carrier,
    trackingNumber: old.trackingNumber ?? u.trackingNumber,
    orderNumber: old.orderNumber ?? u.orderNumber,
    status: status,
    expectedDate:
        advances && status != PackageStatus.delivered ? u.expectedDate : null,
    deliveredAt: becameDelivered ? now.toUtc() : null,
    lastUpdate: advances && u.summary.isNotEmpty ? u.summary : null,
    sourceEmailId: advances ? u.sourceEmailId : null,
    lastEmailAt: now.toUtc(),
  );
}

bool _visiblyDiffers(Package a, Package b) =>
    a.status != b.status ||
    a.merchant != b.merchant ||
    a.item != b.item ||
    a.carrier != b.carrier ||
    a.trackingNumber != b.trackingNumber ||
    a.orderNumber != b.orderNumber ||
    a.expectedDate != b.expectedDate ||
    a.lastUpdate != b.lastUpdate;

class _Entry {
  _Entry(this.pkg, {required this.isNew});

  Package pkg;
  final bool isNew;
  bool dirty = false;
  bool changed = false;
}
