/// Seed data for the sandbox demo mode.
///
/// Builds a fixed persona ("Alex," a Product Manager mid job-hunt) with
/// tasks, job applications, and goals. All dates are computed relative to
/// [DateTime.now] at call time so the demo never looks stale.
library;

import 'package:life_os/features/files/data/models/stored_file.dart';
import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// Fixed user id for the demo persona.
const demoUserId = 'demo-user';

/// Goal id for "Land a Product Manager role by Q4".
const demoGoalPmId = 'demo-goal-pm';

/// Goal id for "Build a standout portfolio".
const demoGoalPortfolioId = 'demo-goal-portfolio';

/// Base64 of a genuine 96x96 JPEG (a plain diagonal gradient square), used
/// as the seeded thumbnail for the one demo image file. Decodes to a real
/// image — this is not placeholder junk.
const _demoImageThumbnailBase64 =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIfIiEmKzcvJik0KSEiMEExNDk7Pj4+JS5ESUM8SDc9PjsBCgsLDg0OHBAQHDsoIig7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O//AABEIAGAAYAMBEQACEQEDEQH/xAGiAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgsQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+gEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoLEQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AOUUV4TifNRJVFQ4nRElUVDidMSVRUOJ0RJVFQ4nTElUVDidESZRUOJ0xJVFS4nRElUVDidMSVRUOJ0RJVFQ4nTElUVDidETiVFfUOJ+QxJVFQ4nRElUVDidMSVRUuJ0RJVFQ4nTElUVDidESVRUOJ0xJlFQ4nRElUVDidMSVRUOJ0RJVFS4nTElUVDidETiVFfUOJ+QRJVFQ4nTElUVDidESVRUOJ0xJVFQ4nRElUVDidMSVRUOJ0RJVFS4nTEmUVDidESVRUOJ0xJVFQ4nRElUVDidMTiVFfUOJ+QRJVFQ4nRElUVDidMSVRUuJ0RJVFQ4nTElUVDidESVRUOJ0xJVFQ4nREmUVDidMSVRUOJ0RJVFQ4nTElUVLidETiVFfUOJ+QRJVFQ4nTElUVDidESVRUOJ0xJVFQ4nRElUVDidMSVRUOJ0RJVFS4nTElUVDidESZRUOJ0xJVFQ4nRElUVDidMTiVFfUOJ+QRJVFQ4nRElUVDidMSVRUuJ0RJVFQ4nTElUVDidMSVRUOJ0RJVFQ4nRElUVDidMSZRUOJ0RJVFQ4nTElUVLidETiVFfUOJ+QxJVFQ4nRElUVDidMSVRUOJ0RJVFQ4nTElUVDidESVRUOJ0xJVFS4nRElUVDidMSVRUOJ0RJVFQ4nTEmUVDidETiVFfUOJ+QRJVFQ4nTElUVDidESVRUuJ0xJVFQ4nRElUVDidMSVRUOJ0RJVFQ4nTElUVDidESVRUOJ0xJVFQ4nRElUVLidMTilFfUOJ+QRJVFQ4nRElUVDidMSVRUOJ0RJVFQ4nTElUVDidESVRUOJ0xJVFS4nRElUVDidMSVRUOJ0RJVFQ4nTElUVDidETiVFfUOJ+QRJlFQ4nTElUVDidESVRUuJ0xJVFQ4nTElUVDidESVRUOJ0RJVFQ4nTElUVDidESVRUOJ0xJVFS4nRElUVDidMTiVFfUOJ+QRJVFQ4nTEmUVDidESVRUOJ0xJVFQ4nRElUVDidMSVRUOJ0RJVFS4nTElUVDidESVRUOJ0xJVFQ4nRElUVDidMTiVFfUOJ+QRJVFQ4nRElUVDidMSZRUuJ0RJVFQ4nTElUVDidESVRUOJ0xJVFQ4nRElUVDidMSVRUOJ0RJVFQ4nTElUVLidET//Z';

/// Builds the demo job applications.
List<JobApplication> buildDemoJobs() {
  final now = DateTime.now();
  return [
    JobApplication(
      id: 'demo-job-meridian',
      company: 'Meridian Financial',
      role: 'Product Manager',
      status: 'interview',
      summary: 'On-site interview scheduled',
      createdAt: now,
      updatedAt: now,
    ),
    JobApplication(
      id: 'demo-job-nimbus',
      company: 'Nimbus Labs',
      role: 'Associate PM',
      status: 'applied',
      createdAt: now,
      updatedAt: now,
    ),
    JobApplication(
      id: 'demo-job-vertex',
      company: 'Vertex Design',
      role: 'UX Researcher',
      status: 'viewed',
      createdAt: now,
      updatedAt: now,
    ),
    JobApplication(
      id: 'demo-job-orbital',
      company: 'Orbital Systems',
      role: 'Program Manager',
      status: 'rejected',
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

/// Builds the demo goals.
List<Goal> buildDemoGoals() {
  final now = DateTime.now();
  return [
    Goal(
      id: demoGoalPmId,
      userId: demoUserId,
      title: 'Land a Product Manager role by Q4',
      targetDate: now.add(const Duration(days: 90)),
      progress: 0.2,
      createdAt: now,
      updatedAt: now,
    ),
    Goal(
      id: demoGoalPortfolioId,
      userId: demoUserId,
      title: 'Build a standout portfolio',
      targetDate: now.add(const Duration(days: 60)),
      progress: 0.2,
      createdAt: now,
      updatedAt: now,
    ),
  ];
}

/// Builds the demo tasks.
List<Task> buildDemoTasks() {
  final now = DateTime.now();

  DateTime dayOffset(int days) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: days));

  return [
    Task(
      id: 'demo-task-follow-nimbus',
      userId: demoUserId,
      title: 'Follow up with Nimbus Labs recruiter',
      priority: TaskPriority.high,
      dueDate: dayOffset(-1),
      goalId: demoGoalPmId,
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-submit-vertex-portfolio',
      userId: demoUserId,
      title: 'Submit portfolio to Vertex Design',
      priority: TaskPriority.medium,
      dueDate: dayOffset(-2),
      goalId: demoGoalPortfolioId,
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-prep-meridian-interview',
      userId: demoUserId,
      title: 'Prep for Meridian Financial interview',
      priority: TaskPriority.high,
      dueDate: dayOffset(0),
      goalId: demoGoalPmId,
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-update-linkedin',
      userId: demoUserId,
      title: 'Update LinkedIn headline',
      priority: TaskPriority.low,
      dueDate: dayOffset(0),
      goalId: demoGoalPortfolioId,
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-practice-system-design',
      userId: demoUserId,
      title: 'Practice system-design questions',
      priority: TaskPriority.medium,
      dueDate: dayOffset(2),
      goalId: demoGoalPmId,
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-thank-you-orbital',
      userId: demoUserId,
      title: 'Send thank-you note to Orbital Systems',
      priority: TaskPriority.medium,
      dueDate: dayOffset(3),
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-research-salary',
      userId: demoUserId,
      title: 'Research PM salary bands',
      priority: TaskPriority.low,
      dueDate: dayOffset(5),
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 'demo-task-apex-takehome',
      userId: demoUserId,
      title: 'Finish Apex Analytics take-home',
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 2)),
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Task(
      id: 'demo-task-halcyon-phone-screen',
      userId: demoUserId,
      title: 'Attend Halcyon Health phone screen',
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 4)),
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 4)),
    ),
  ];
}

/// Builds the demo files.
List<StoredFile> buildDemoFiles() {
  final now = DateTime.now();
  return [
    StoredFile(
      id: 'demo-file-resume',
      userId: demoUserId,
      storagePath: '$demoUserId/resume.pdf',
      fileName: 'Alex_Resume.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 182_400,
      isPrivate: false,
      attachedEntityType: FileAttachmentType.jobApplication,
      attachedEntityId: 'demo-job-meridian',
      createdAt: now.subtract(const Duration(days: 6)),
      updatedAt: now.subtract(const Duration(days: 6)),
    ),
    StoredFile(
      id: 'demo-file-interview-prep',
      userId: demoUserId,
      storagePath: '$demoUserId/interview_prep.pdf',
      fileName: 'Meridian_Financial_Interview_Prep_Notes.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 96_200,
      isPrivate: false,
      attachedEntityType: FileAttachmentType.jobApplication,
      attachedEntityId: 'demo-job-meridian',
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    StoredFile(
      id: 'demo-file-interview-notes-screenshot',
      userId: demoUserId,
      storagePath: '$demoUserId/interview_notes.png',
      fileName: 'interview_notes_screenshot.png',
      mimeType: 'image/png',
      sizeBytes: 412_900,
      isPrivate: false,
      thumbnailBase64: _demoImageThumbnailBase64,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    StoredFile(
      id: 'demo-file-salary-notes',
      userId: demoUserId,
      storagePath: '$demoUserId/salary_notes.pdf',
      fileName: 'Salary_negotiation_notes.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 61_300,
      isPrivate: true,
      createdAt: now.subtract(const Duration(hours: 5)),
      updatedAt: now.subtract(const Duration(hours: 5)),
    ),
  ];
}
