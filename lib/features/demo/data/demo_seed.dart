/// Seed data for the sandbox demo mode.
///
/// Builds a fixed persona ("Alex," a Product Manager mid job-hunt) with
/// tasks, job applications, and goals. All dates are computed relative to
/// [DateTime.now] at call time so the demo never looks stale.
library;

import 'package:life_os/features/goals/data/models/goal.dart';
import 'package:life_os/features/jobs/data/models/job_application.dart';
import 'package:life_os/features/tasks/data/models/task.dart';

/// Fixed user id for the demo persona.
const demoUserId = 'demo-user';

/// Goal id for "Land a Product Manager role by Q4".
const demoGoalPmId = 'demo-goal-pm';

/// Goal id for "Build a standout portfolio".
const demoGoalPortfolioId = 'demo-goal-portfolio';

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
