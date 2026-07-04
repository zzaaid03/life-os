import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/data/entity.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

void main() {
  final now = DateTime.now();

  group('Task model', () {
    test('serializes to and from JSON correctly', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Buy groceries',
        description: 'Milk, eggs, bread',
        priority: TaskPriority.high,
        status: TaskStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final json = task.toJson();
      final restored = Task.fromJson(json);

      expect(restored.id, equals(task.id));
      expect(restored.title, equals(task.title));
      expect(restored.priority, equals(TaskPriority.high));
      expect(restored.status, equals(TaskStatus.pending));
    });

    test('copyWith preserves unchanged fields', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Original',
        createdAt: now,
        updatedAt: now,
      );

      final updated = task.copyWith(title: 'Updated');

      expect(updated.title, equals('Updated'));
      expect(updated.id, equals(task.id));
      expect(updated.userId, equals(task.userId));
    });

    test('completed task has correct status', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Done task',
        status: TaskStatus.completed,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(task.status, equals(TaskStatus.completed));
      expect(task.completedAt, isNotNull);
    });

    test('sync status defaults to synced', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Test',
        createdAt: now,
        updatedAt: now,
      );

      expect(task.syncStatus, equals(SyncStatus.synced));
      expect(task.isSynced, isTrue);
      expect(task.needsPush, isFalse);
    });

    test('pendingCreate status needs push', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Test',
        syncStatus: SyncStatus.pendingCreate,
        createdAt: now,
        updatedAt: now,
      );

      expect(task.needsPush, isTrue);
      expect(task.isSynced, isFalse);
    });

    test('soft delete sets deletedAt', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Test',
        deletedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(task.isDeleted, isTrue);
    });

    test('version increments correctly via copyWith', () {
      final task = Task(
        id: 't1',
        userId: 'u1',
        title: 'Test',
        version: 1,
        createdAt: now,
        updatedAt: now,
      );

      final updated = task.copyWith(version: task.version + 1);
      expect(updated.version, equals(2));
    });

    test('priority enum has correct order', () {
      expect(TaskPriority.values, hasLength(4));
      expect(TaskPriority.none.index, equals(0));
      expect(TaskPriority.low.index, equals(1));
      expect(TaskPriority.medium.index, equals(2));
      expect(TaskPriority.high.index, equals(3));
    });

    test('status parsing handles all variants', () {
      expect(
        Task.fromJson({
          'id': 't1',
          'user_id': 'u1',
          'title': 'Test',
          'status': 'pending',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).status,
        equals(TaskStatus.pending),
      );

      expect(
        Task.fromJson({
          'id': 't1',
          'user_id': 'u1',
          'title': 'Test',
          'status': 'in_progress',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).status,
        equals(TaskStatus.inProgress),
      );

      expect(
        Task.fromJson({
          'id': 't1',
          'user_id': 'u1',
          'title': 'Test',
          'status': 'completed',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).status,
        equals(TaskStatus.completed),
      );
    });

    test('equatable compares correctly', () {
      final a = Task(
        id: 't1',
        userId: 'u1',
        title: 'Same',
        createdAt: now,
        updatedAt: now,
      );
      final b = Task(
        id: 't1',
        userId: 'u1',
        title: 'Same',
        createdAt: now,
        updatedAt: now,
      );
      final c = Task(
        id: 't2',
        userId: 'u1',
        title: 'Different',
        createdAt: now,
        updatedAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
