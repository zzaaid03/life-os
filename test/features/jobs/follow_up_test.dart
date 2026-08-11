import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/jobs/domain/follow_up.dart';

JobApplication _app({
  required String id,
  required String status,
  DateTime? appliedAt,
  required DateTime updatedAt,
}) {
  return JobApplication(
    id: id,
    company: 'Company $id',
    role: 'Role $id',
    status: status,
    appliedAt: appliedAt,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group('staleApplications', () {
    final now = DateTime(2026, 1, 15);

    test('returns an empty list for empty input', () {
      expect(staleApplications(const [], now), isEmpty);
    });

    test('only applied and viewed qualify among the five statuses', () {
      final oldDate = now.subtract(const Duration(days: 30));
      final apps = [
        _app(id: 'applied', status: 'applied', updatedAt: oldDate),
        _app(id: 'viewed', status: 'viewed', updatedAt: oldDate),
        _app(id: 'interview', status: 'interview', updatedAt: oldDate),
        _app(id: 'rejected', status: 'rejected', updatedAt: oldDate),
        _app(id: 'accepted', status: 'accepted', updatedAt: oldDate),
      ];

      final result = staleApplications(apps, now);

      expect(result.map((a) => a.id), containsAll(['applied', 'viewed']));
      expect(result.length, 2);
    });

    test('status matching is case-insensitive and trims whitespace', () {
      final oldDate = now.subtract(const Duration(days: 30));
      final apps = [
        _app(id: 'a', status: ' Applied ', updatedAt: oldDate),
        _app(id: 'b', status: 'VIEWED', updatedAt: oldDate),
      ];

      final result = staleApplications(apps, now);

      expect(result.length, 2);
    });

    test('falls back to updatedAt when appliedAt is null', () {
      final apps = [
        _app(
          id: 'a',
          status: 'applied',
          appliedAt: null,
          updatedAt: now.subtract(const Duration(days: 20)),
        ),
      ];

      final result = staleApplications(apps, now);

      expect(result, hasLength(1));
    });

    test('prefers appliedAt over updatedAt when both are present', () {
      final apps = [
        _app(
          id: 'a',
          status: 'applied',
          // appliedAt is old enough, updatedAt (recent) should be ignored.
          appliedAt: now.subtract(const Duration(days: 20)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final result = staleApplications(apps, now);

      expect(result, hasLength(1));
    });

    test('exactly at the threshold is included', () {
      final apps = [
        _app(
          id: 'a',
          status: 'applied',
          appliedAt: now.subtract(const Duration(days: 14)),
          updatedAt: now.subtract(const Duration(days: 14)),
        ),
      ];

      final result = staleApplications(apps, now);

      expect(result, hasLength(1));
    });

    test('one day under the threshold is excluded', () {
      final apps = [
        _app(
          id: 'a',
          status: 'applied',
          appliedAt: now.subtract(const Duration(days: 13)),
          updatedAt: now.subtract(const Duration(days: 13)),
        ),
      ];

      final result = staleApplications(apps, now);

      expect(result, isEmpty);
    });

    test('respects a custom threshold', () {
      final apps = [
        _app(
          id: 'a',
          status: 'applied',
          appliedAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(days: 5)),
        ),
      ];

      expect(
        staleApplications(apps, now, threshold: const Duration(days: 7)),
        isEmpty,
      );
      expect(
        staleApplications(apps, now, threshold: const Duration(days: 3)),
        hasLength(1),
      );
    });

    test('returns results oldest first', () {
      final apps = [
        _app(
          id: 'newest',
          status: 'applied',
          appliedAt: now.subtract(const Duration(days: 15)),
          updatedAt: now.subtract(const Duration(days: 15)),
        ),
        _app(
          id: 'oldest',
          status: 'viewed',
          appliedAt: now.subtract(const Duration(days: 40)),
          updatedAt: now.subtract(const Duration(days: 40)),
        ),
        _app(
          id: 'middle',
          status: 'applied',
          appliedAt: now.subtract(const Duration(days: 25)),
          updatedAt: now.subtract(const Duration(days: 25)),
        ),
      ];

      final result = staleApplications(apps, now);

      expect(result.map((a) => a.id).toList(), [
        'oldest',
        'middle',
        'newest',
      ]);
    });
  });
}
