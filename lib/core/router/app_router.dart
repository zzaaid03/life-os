/// Application router configuration using GoRouter.
///
/// Defines all routes, authentication guards, shell routes,
/// and navigation logic for Life OS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:life_os/features/auth/presentation/screens/login_screen.dart';
import 'package:life_os/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:life_os/features/auth/presentation/screens/splash_screen.dart';
import 'package:life_os/features/auth/presentation/screens/welcome_screen.dart';
import 'package:life_os/features/home/presentation/screens/home_screen.dart';
import 'package:life_os/features/inbox/presentation/screens/inbox_scan_screen.dart';
import 'package:life_os/features/jobs/presentation/screens/job_applications_screen.dart';
import 'package:life_os/features/life/presentation/screens/life_screen.dart';
import 'package:life_os/features/permissions/presentation/screens/calendar_permission_screen.dart';
import 'package:life_os/features/permissions/presentation/screens/files_permission_screen.dart';
import 'package:life_os/features/permissions/presentation/screens/notification_permission_screen.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';
import 'package:life_os/features/profile/presentation/screens/create_profile_screen.dart';
import 'package:life_os/features/search/presentation/screens/search_screen.dart';
import 'package:life_os/features/settings/presentation/screens/settings_screen.dart';
import 'package:life_os/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:life_os/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:life_os/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:life_os/shared/widgets/app_shell.dart';

/// Named route constants.
abstract final class AppRoutes {
  AppRoutes._();

  // Auth flow
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  // Onboarding flow (post-auth)
  static const String createProfile = '/create-profile';
  static const String permissionNotifications = '/permissions/notifications';
  static const String permissionCalendar = '/permissions/calendar';
  static const String permissionFiles = '/permissions/files';

  // Main app
  static const String home = '/home';
  static const String timeline = '/timeline';
  static const String life = '/life';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';

  // AI inbox assistant
  static const String inboxScan = '/inbox-scan';
  static const String jobApplications = '/job-applications';
}

/// Creates and configures the GoRouter instance.
GoRouter createRouter({required WidgetRef ref}) {
  final authState = ref.watch(authProvider);
  final profileState = ref.watch(profileProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final location = state.matchedLocation;

      // Auth screens
      final isAuthScreen =
          location == AppRoutes.login ||
          location == AppRoutes.signUp ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.welcome;
      final isSplash = location == AppRoutes.splash;

      // Onboarding screens
      final isOnboarding =
          location == AppRoutes.createProfile ||
          location == AppRoutes.permissionNotifications ||
          location == AppRoutes.permissionCalendar ||
          location == AppRoutes.permissionFiles;

      // Splash always allowed
      if (isSplash) return null;

      // Authenticated user trying to access auth screens → home
      if (isAuthenticated && isAuthScreen) {
        return AppRoutes.home;
      }

      // Unauthenticated user → welcome
      if (!isAuthenticated && !isAuthScreen && !isSplash) {
        return AppRoutes.welcome;
      }

      // Authenticated but no profile → create profile
      if (isAuthenticated &&
          !isOnboarding &&
          profileState.profile == null &&
          profileState.status != ProfileStatus.loading &&
          location != AppRoutes.createProfile &&
          !location.startsWith('/permissions')) {
        return AppRoutes.createProfile;
      }

      return null;
    },

    routes: [
      // Auth flow
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.createProfile,
        name: 'createProfile',
        builder: (context, state) => const CreateProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.permissionNotifications,
        name: 'permissionNotifications',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.permissionCalendar,
        name: 'permissionCalendar',
        builder: (context, state) => const CalendarPermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.permissionFiles,
        name: 'permissionFiles',
        builder: (context, state) => const FilesPermissionScreen(),
      ),

      // Main app — wrapped in AppShell with floating nav + FAB
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.timeline,
            name: 'timeline',
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: AppRoutes.life,
            name: 'life',
            builder: (context, state) => const LifeScreen(),
          ),
          GoRoute(
            path: AppRoutes.search,
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            name: 'tasks',
            builder: (context, state) => const TaskListScreen(),
          ),
        ],
      ),

      // Task detail — standalone, no nav bar
      GoRoute(
        path: AppRoutes.taskDetail,
        name: 'taskDetail',
        builder: (context, state) =>
            TaskDetailScreen(taskId: state.pathParameters['id']!),
      ),

      // AI inbox assistant — standalone, no nav bar
      GoRoute(
        path: AppRoutes.inboxScan,
        name: 'inboxScan',
        builder: (context, state) => const InboxScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.jobApplications,
        name: 'jobApplications',
        builder: (context, state) => const JobApplicationsScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you\'re looking for doesn\'t exist.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
