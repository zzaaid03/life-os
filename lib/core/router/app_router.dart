/// Application router configuration using GoRouter.
///
/// Defines all routes, authentication guards, and navigation
/// logic for Life OS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/auth/presentation/screens/login_screen.dart';
import 'package:life_os/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:life_os/features/auth/presentation/screens/splash_screen.dart';
import 'package:life_os/features/home/presentation/screens/home_screen.dart';
import 'package:life_os/features/life/presentation/screens/life_screen.dart';
import 'package:life_os/features/search/presentation/screens/search_screen.dart';
import 'package:life_os/features/settings/presentation/screens/settings_screen.dart';
import 'package:life_os/features/timeline/presentation/screens/timeline_screen.dart';

/// Named route constants.
///
/// Always use these constants instead of raw strings
/// when navigating to avoid typos and enable refactoring.
abstract final class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String timeline = '/timeline';
  static const String life = '/life';
  static const String search = '/search';
  static const String settings = '/settings';
}

/// Creates and configures the GoRouter instance.
///
/// Requires a [Ref] for accessing Riverpod providers
/// (e.g., authentication state).
GoRouter createRouter({required WidgetRef ref}) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,

    // --- Redirect logic ---
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final isSplash = state.matchedLocation == AppRoutes.splash;

      // Allow splash to always show
      if (isSplash) return null;

      // If not authenticated, redirect to login
      if (!isAuthenticated && !isLoggingIn && !isOnboarding) {
        return AppRoutes.login;
      }

      // If authenticated and trying to access auth screens, go to home
      if (isAuthenticated && (isLoggingIn || isOnboarding)) {
        return AppRoutes.home;
      }

      return null;
    },

    routes: [
      // --- Splash ---
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // --- Onboarding ---
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // --- Login ---
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // --- Home ---
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // --- Timeline ---
      GoRoute(
        path: AppRoutes.timeline,
        name: 'timeline',
        builder: (context, state) => const TimelineScreen(),
      ),

      // --- Life ---
      GoRoute(
        path: AppRoutes.life,
        name: 'life',
        builder: (context, state) => const LifeScreen(),
      ),

      // --- Search ---
      GoRoute(
        path: AppRoutes.search,
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),

      // --- Settings ---
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // --- Error / Unknown Route ---
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
