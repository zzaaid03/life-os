/// Supabase client service.
///
/// Provides a configured [SupabaseClient] instance
/// initialized from environment variables.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:life_os/core/config/env_config.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the Supabase client.
///
/// This is the single source of truth for all Supabase interactions.
/// All repositories should depend on this provider.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError(
    'SupabaseClient must be initialized before use. '
    'Call SupabaseService.initialize() in main() before runApp().',
  );
});

/// Service responsible for initializing and managing Supabase.
abstract final class SupabaseService {
  SupabaseService._();

  /// Initializes Supabase with credentials from environment variables.
  ///
  /// Must be called in [main] before [runApp].
  /// Throws [StateError] if required environment variables are missing.
  static Future<Supabase> initialize() async {
    final url = dotenv.env[EnvConfig.supabaseUrlKey];
    final anonKey = dotenv.env[EnvConfig.supabaseAnonKeyKey];

    if (url == null ||
        url.isEmpty ||
        url == 'https://your-project-id.supabase.co') {
      throw StateError(
        'SUPABASE_URL is not configured. '
        'Copy .env to your local .env file and fill in your Supabase project URL.',
      );
    }

    if (anonKey == null || anonKey.isEmpty || anonKey == 'your-anon-key-here') {
      throw StateError(
        'SUPABASE_ANON_KEY is not configured. '
        'Copy .env to your local .env file and fill in your Supabase anon key.',
      );
    }

    return Supabase.initialize(url: url, publishableKey: anonKey);
  }
}
