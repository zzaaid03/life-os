/// Sandbox demo mode — swaps every repository for an in-memory demo
/// implementation via a keyed [ProviderScope] rebuild.
///
/// Entering/exiting demo mode flips [demoModeController], which
/// `AppBootstrap` (in `main.dart`) listens to and uses to rebuild the whole
/// `ProviderScope` under a new key — giving demo mode a completely fresh,
/// ephemeral container (and wiping it clean again on exit or reload).
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/demo/data/repositories/demo_auth_repository.dart';
import 'package:life_os/features/demo/data/repositories/demo_daily_brief_notifier.dart';
import 'package:life_os/features/demo/data/repositories/demo_goal_repository.dart';
import 'package:life_os/features/demo/data/repositories/demo_job_application_repository.dart';
import 'package:life_os/features/demo/data/repositories/demo_profile_repository.dart';
import 'package:life_os/features/demo/data/repositories/demo_task_repository.dart';
import 'package:life_os/features/goals/data/repositories/supabase_goal_repository.dart';
import 'package:life_os/features/home/domain/daily_brief_provider.dart';
import 'package:life_os/features/jobs/data/repositories/job_application_repository.dart';
import 'package:life_os/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:life_os/features/tasks/domain/providers/task_provider.dart';
import 'package:riverpod/riverpod.dart';

/// Whether the app is currently showing the sandbox demo experience.
final demoModeController = ValueNotifier<bool>(false);

/// Enters demo mode — the app rebuilds against in-memory demo repositories.
void enterDemoMode() => demoModeController.value = true;

/// Exits demo mode — the app rebuilds against the real repositories.
void exitDemoMode() => demoModeController.value = false;

/// Provider overrides that route every repository read to its in-memory
/// demo counterpart, so demo mode never makes a Supabase or edge-function
/// call.
List<Override> buildDemoOverrides() {
  return [
    authRepositoryProviderOverride.overrideWithValue(
      const DemoAuthRepository(),
    ),
    profileRepositoryProvider.overrideWithValue(DemoProfileRepository()),
    taskRepositoryProvider.overrideWithValue(DemoTaskRepository()),
    jobApplicationRepositoryProvider.overrideWithValue(
      DemoJobApplicationRepository(),
    ),
    goalRepositoryProvider.overrideWithValue(DemoGoalRepository()),
    dailyBriefProvider.overrideWith(DemoDailyBriefNotifier.new),
  ];
}
