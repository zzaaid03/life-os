/// Life OS — Application entry point.
///
/// Initializes all services, configures providers,
/// and launches the application with the configured router.
///
/// Includes global startup error handling: if any fatal exception
/// occurs during initialization, a friendly error screen is shown
/// instead of a blank page or crashed browser tab.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_theme.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/inbox/data/google_credentials_repository.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  try {
    await _initializeAndRun();
  } catch (error, stackTrace) {
    // Log the error in debug mode so developers can see it.
    debugPrint('FATAL: Startup initialization failed');
    debugPrint('Error: $error');
    debugPrint('Stack: $stackTrace');

    // Show a friendly error screen instead of a white page or
    // a silently closed browser tab.
    runApp(_StartupErrorApp(error: error));
  }
}

/// Performs the normal startup sequence and launches the app.
Future<void> _initializeAndRun() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await SupabaseService.initialize();

  // On web, the OAuth redirect is consumed during `Supabase.initialize()`, so
  // the freshly-restored session is the ONLY place `providerRefreshToken` is
  // available — it's gone by the time the `googleCredentialsCaptureProvider`
  // listener subscribes in `LifeOSApp.initState`. Persist it here, right away,
  // so the `extract-tasks` function can mint Gmail tokens later. The provider
  // listener still runs as a backup for native / in-session sign-ins.
  final session = Supabase.instance.client.auth.currentSession;
  final providerRefreshToken = session?.providerRefreshToken;
  final userId = session?.user.id;
  debugPrint(
    '[gmail] post-init refreshToken present: '
    '${providerRefreshToken != null && providerRefreshToken.isNotEmpty}, '
    'user: $userId',
  );
  if (providerRefreshToken != null &&
      providerRefreshToken.isNotEmpty &&
      userId != null) {
    try {
      await Supabase.instance.client.from('google_credentials').upsert(
        {'user_id': userId, 'refresh_token': providerRefreshToken},
        onConflict: 'user_id',
      );
      debugPrint('[gmail] refresh token saved for $userId');
    } catch (e) {
      debugPrint('[gmail] failed to save refresh token: $e');
    }
  }

  runApp(const ProviderScope(child: LifeOSApp()));
}

/// The root widget of Life OS.
class LifeOSApp extends ConsumerStatefulWidget {
  const LifeOSApp({super.key});

  @override
  ConsumerState<LifeOSApp> createState() => _LifeOSAppState();
}

class _LifeOSAppState extends ConsumerState<LifeOSApp> {
  @override
  void initState() {
    super.initState();
    // Activate the Google refresh-token capture listener for the whole app
    // session. Reading the provider starts its raw `onAuthStateChange`
    // subscription so any Google sign-in persists its refresh token.
    ref.read(googleCredentialsCaptureProvider);

    // Load profile when auth state becomes authenticated
    ref.listenManual(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          next.userId != null &&
          (previous == null || !previous.isAuthenticated)) {
        ref.read(profileProvider.notifier).loadProfile(next.userId!);
      }
    });

    // Cold-start fix: `listenManual` only fires on a state *transition*.
    // If the session was already restored (e.g. Google OAuth) by the
    // time this widget is first built, there's no transition to listen
    // for, so the profile would never load. Deferred via
    // `Future.microtask` since this runs during `initState`.
    final currentAuth = ref.read(authProvider);
    if (currentAuth.isAuthenticated && currentAuth.userId != null) {
      Future.microtask(
        () =>
            ref.read(profileProvider.notifier).loadProfile(currentAuth.userId!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = createRouter(ref: ref);

    return MaterialApp.router(
      title: 'Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Startup Error Fallback
// ---------------------------------------------------------------------------

/// A minimal MaterialApp shown when startup initialization fails.
///
/// Renders a friendly error screen so the user sees something helpful
/// instead of a blank white page or a silently closed browser tab.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  /// The exception that prevented startup.
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _StartupErrorScreen(error: error),
    );
  }
}

/// A friendly error screen for startup failures.
class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 32),

              // Heading
              Text(
                'Something went wrong',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Explanation
              Text(
                'Life OS couldn\'t start. This is usually because '
                'the connection to Supabase failed or the '
                'configuration is missing.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Error details (collapsible in debug mode)
              if (kDebugMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    '$error',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              if (kDebugMode) const SizedBox(height: 24),

              // Retry button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    // On web, reloading the page re-runs the Flutter bootstrap
                    // which calls main() again. On native platforms, this
                    // restarts the app through the platform channel.
                    //
                    // For a full restart on all platforms, the simplest
                    // cross-platform approach is to call runApp again, but
                    // that won't re-run main(). We tell the user to manually
                    // restart. A Retry that shows the error again is better
                    // than a white screen.
                    //
                    // TODO: Implement proper restart via platform channel
                    // when native targets are fully supported.
                  },
                  child: const Text('Retry'),
                ),
              ),
              const SizedBox(height: 12),

              // Manual restart hint
              Text(
                'If the problem persists, try restarting the app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
