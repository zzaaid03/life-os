/// Google credentials repository.
///
/// Persists the user's Google OAuth refresh token in the
/// `public.google_credentials` table so the `extract-tasks` Edge Function
/// can mint fresh Gmail access tokens server-side — without the app ever
/// having to hold a live access token. Per-user RLS protects each row.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for the `google_credentials` table.
class GoogleCredentialsRepository {
  /// Creates a [GoogleCredentialsRepository].
  const GoogleCredentialsRepository(this._client);

  final SupabaseClient _client;

  /// The Supabase table name.
  static const String _table = 'google_credentials';

  /// Upserts the [refreshToken] for [userId], keyed on `user_id`.
  Future<void> saveRefreshToken({
    required String userId,
    required String refreshToken,
  }) async {
    await _client.from(_table).upsert({
      'user_id': userId,
      'refresh_token': refreshToken,
    }, onConflict: 'user_id');
  }

  /// Whether a stored credential row exists for [userId].
  Future<bool> hasCredentials(String userId) async {
    final response = await _client
        .from(_table)
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    return response != null;
  }
}

/// Provides the [GoogleCredentialsRepository].
final googleCredentialsRepositoryProvider =
    Provider<GoogleCredentialsRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return GoogleCredentialsRepository(client);
    });

/// Captures the Google refresh token from raw Supabase auth events and
/// persists it for the signed-in user.
///
/// `providerRefreshToken` is only populated on the [Session] immediately
/// after a Google sign-in (with `access_type: offline`). This provider
/// listens to the raw `onAuthStateChange` stream and upserts the token the
/// first time it sees a given value. Activate it once at app startup by
/// reading it (see `main.dart`). Failures are logged, never thrown.
final googleCredentialsCaptureProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final repository = ref.watch(googleCredentialsRepositoryProvider);

  // Guard against re-saving the same token on repeated auth events
  // (token refresh, tab focus, etc.) within a session.
  String? lastSavedToken;

  final subscription = client.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    final refreshToken = session?.providerRefreshToken;
    final userId = session?.user.id;

    // Log every auth event so a persistent reconnect loop can be diagnosed
    // from the console: was a refresh token present, and did the save work?
    debugPrint(
      '[gmail] auth event ${data.event}: refreshToken present: '
      '${refreshToken != null && refreshToken.isNotEmpty}, user: $userId',
    );

    if (refreshToken == null || refreshToken.isEmpty || userId == null) {
      return;
    }
    if (refreshToken == lastSavedToken) return;
    lastSavedToken = refreshToken;

    repository
        .saveRefreshToken(userId: userId, refreshToken: refreshToken)
        .then((_) {
          debugPrint('[gmail] refresh token saved for $userId (listener)');
        })
        .catchError((Object e) {
          // Persisting the refresh token is best-effort; if it fails the
          // user can simply reconnect Gmail again later.
          debugPrint('[gmail] failed to save refresh token (listener): $e');
        });
  });

  ref.onDispose(subscription.cancel);
});
