import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/data/entity.dart';
import 'package:life_os/features/attachments/data/models/attachment.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/tags/data/models/tag.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

void main() {
  final now = DateTime.now();

  group('Entity base interface', () {
    test('EntitySyncX extension reports correct sync states', () {
      final syncedTask = Task(
        id: '1',
        userId: 'user-1',
        title: 'Test',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.synced,
      );

      expect(syncedTask.isSynced, isTrue);
      expect(syncedTask.needsPush, isFalse);
      expect(syncedTask.isDeleted, isFalse);

      final pendingTask = Task(
        id: '2',
        userId: 'user-1',
        title: 'Pending',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pendingPush,
      );

      expect(pendingTask.needsPush, isTrue);
      expect(pendingTask.isSynced, isFalse);
    });

    test('isDeleted reports true when deletedAt is set', () {
      final deleted = Task(
        id: '3',
        userId: 'user-1',
        title: 'Deleted',
        createdAt: now,
        updatedAt: now,
        deletedAt: now.subtract(const Duration(days: 1)),
      );

      expect(deleted.isDeleted, isTrue);
    });
  });

  group('Task model', () {
    test('serializes to and from JSON', () {
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
      expect(restored.priority, equals(task.priority));
      expect(restored.status, equals(task.status));
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
      expect(updated.createdAt, equals(task.createdAt));
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

  group('Goal model', () {
    test('serializes to and from JSON', () {
      final goal = Goal(
        id: 'g1',
        userId: 'u1',
        title: 'Run marathon',
        progress: 0.5,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final json = goal.toJson();
      final restored = Goal.fromJson(json);

      expect(restored.id, equals(goal.id));
      expect(restored.progress, equals(0.5));
      expect(restored.status, equals(GoalStatus.active));
    });
  });

  group('Tag model', () {
    test('serializes to and from JSON', () {
      final tag = Tag(
        id: 'tag1',
        userId: 'u1',
        name: 'Work',
        color: '#00FF00',
        createdAt: now,
        updatedAt: now,
      );

      final json = tag.toJson();
      final restored = Tag.fromJson(json);

      expect(restored.id, equals(tag.id));
      expect(restored.name, equals('Work'));
      expect(restored.color, equals('#00FF00'));
    });
  });

  group('Attachment model', () {
    test('serializes to and from JSON', () {
      final attachment = Attachment(
        id: 'a1',
        userId: 'u1',
        entityType: 'task',
        entityId: 't1',
        fileName: 'photo.jpg',
        fileSize: 1024,
        mimeType: 'image/jpeg',
        storagePath: 'attachments/u1/photo.jpg',
        createdAt: now,
        updatedAt: now,
      );

      final json = attachment.toJson();
      final restored = Attachment.fromJson(json);

      expect(restored.id, equals(attachment.id));
      expect(restored.entityType, equals('task'));
      expect(restored.entityId, equals('t1'));
      expect(restored.fileName, equals('photo.jpg'));
      expect(restored.fileSize, equals(1024));
      expect(restored.storagePath, equals('attachments/u1/photo.jpg'));
    });
  });
}
