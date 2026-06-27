/// Life OS — Application entry point.
///
/// Initializes all services, configures providers,
/// and launches the application with the configured router.
library;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/router/app_router.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/core/theme/app_theme.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:life_os/features/profile/domain/providers/profile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await SupabaseService.initialize();

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
    // Load profile when auth state becomes authenticated
    ref.listenManual(authProvider, (previous, next) {
      if (next.isAuthenticated &&
          next.userId != null &&
          (previous == null || !previous.isAuthenticated)) {
        ref.read(profileProvider.notifier).loadProfile(next.userId!);
      }
    });
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
