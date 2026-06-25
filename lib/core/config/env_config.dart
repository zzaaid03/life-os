/// Environment configuration loaded from .env.
///
/// Provides typed access to environment variables.
/// All values are loaded at startup via [flutter_dotenv].
abstract final class EnvConfig {
  EnvConfig._();

  /// Supabase project URL.
  static const String supabaseUrlKey = 'SUPABASE_URL';

  /// Supabase publishable (public) key.
  static const String supabasePublishableKeyKey = 'SUPABASE_PUBLISHABLE_KEY';

  /// Google OAuth web client ID.
  static const String googleClientIdKey = 'GOOGLE_CLIENT_ID';
}
