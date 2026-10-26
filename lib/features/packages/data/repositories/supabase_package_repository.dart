/// Supabase-backed repository for packages.
///
/// Reads and writes `public.packages`. RLS scopes rows to the user, and every
/// query also filters on `user_id` explicitly.
library;

import 'package:life_os/features/inbox/data/inbox_scan_service.dart';
import 'package:life_os/features/packages/data/models/package.dart';
import 'package:life_os/features/packages/data/repositories/package_repository.dart';
import 'package:life_os/features/packages/domain/package_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for [Package] records backed by Supabase.
class SupabasePackageRepository implements PackageRepository {
  /// Creates a [SupabasePackageRepository].
  const SupabasePackageRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'packages';

  @override
  Future<List<Package>> fetchPackages(String userId) async {
    // Capped at 200: a list longer than that is not useful on one screen, and
    // it keeps the response far below the 1000-row cap.
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .order('updated_at', ascending: false)
        .limit(200);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Package.fromJson)
        .toList();
  }

  @override
  Future<void> markDelivered(String id) {
    return _write(id, {
      'status': PackageStatus.delivered.dbValue,
      'delivered_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> softDelete(String id) {
    return _write(id, {'deleted_at': DateTime.now().toUtc().toIso8601String()});
  }

  @override
  Future<void> restore(String id) => _write(id, {'deleted_at': null});

  /// Updates one row and throws when RLS or a missing row matched nothing.
  Future<void> _write(String id, Map<String, dynamic> values) async {
    final rows = await _client
        .from(_table)
        .update(values)
        .eq('id', id)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError('Could not update package $id.');
    }
  }

  @override
  Future<void> applyScanUpdates(
    List<PackageUpdate> updates,
    String userId,
  ) async {
    if (updates.isEmpty) return;
    final existing = await _loadCandidates(updates, userId);
    final changes = matchPackageUpdates(
      existing,
      updates,
      now: DateTime.now().toUtc(),
    );

    if (changes.inserts.isNotEmpty) {
      final rows = await _client
          .from(_table)
          .insert([
            for (final p in changes.inserts)
              {'user_id': userId, ...p.toScanJson()},
          ])
          .select('id');
      if ((rows as List).length != changes.inserts.length) {
        throw StateError('Could not save every new package.');
      }
    }

    for (final p in changes.updates) {
      final rows = await _client
          .from(_table)
          .update(p.toScanJson())
          .eq('id', p.id)
          .eq('user_id', userId)
          .select('id');
      if ((rows as List).isEmpty) {
        throw StateError('Could not update package ${p.id}.');
      }
    }
  }

  /// Loads only the rows that share a tracking or order number with the
  /// batch, soft-deleted ones included. Never "load all".
  Future<List<Package>> _loadCandidates(
    List<PackageUpdate> updates,
    String userId,
  ) async {
    final tracking = {
      for (final u in updates)
        if (u.trackingNumber != null) u.trackingNumber!,
    }.toList();
    final orders = {
      for (final u in updates)
        if (u.orderNumber != null) u.orderNumber!,
    }.toList();

    final byId = <String, Package>{};
    Future<void> load(String column, List<String> values) async {
      if (values.isEmpty) return;
      // One scan batch carries a few dozen numbers at most, so a match set
      // this size cannot reach the 1000-row cap.
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .inFilter(column, values);
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final p = Package.fromJson(row);
        byId[p.id] = p;
      }
    }

    await load('tracking_number', tracking);
    await load('order_number', orders);
    return byId.values.toList();
  }
}
