/// Google credentials repository.
///
/// Persists the user's Google OAuth refresh token (via RPC into
/// `public.google_credentials`) so the `extract-tasks` Edge Function
/// can mint fresh Gmail access tokens server-side, without the app ever
/// having to hold a live access token. The functions only ever act on the caller.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/auth/domain/providers/auth_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for the user's stored Google credentials.
///
/// The client has no access to the `google_credentials` table itself (the
/// refresh token must never reach the browser). Every call goes through a
/// SECURITY DEFINER function that acts on `auth.uid()` only. Failures are
/// logged (never the token) and rethrown so callers can tell "failed" from
/// "nothing there".
class GoogleCredentialsRepository {
  /// Creates a [GoogleCredentialsRepository].
  const GoogleCredentialsRepository(this._client);

  final SupabaseClient _client;

  /// Saves the [refreshToken] for the signed-in user (insert or update).
  Future<void> saveRefreshToken({required String refreshToken}) async {
    try {
      await _client.rpc<void>(
        'save_google_refresh_token',
        params: {'p_refresh_token': refreshToken},
      );
    } catch (e) {
      debugPrint('[gmail] save_google_refresh_token failed: $e');
      rethrow;
    }
  }

  /// Whether the signed-in user has a stored credential.
  Future<bool> hasCredentials() async {
    try {
      final response = await _client.rpc<bool>('google_connected');
      return response == true;
    } catch (e) {
      debugPrint('[gmail] google_connected failed: $e');
      rethrow;
    }
  }

  /// Deletes the signed-in user's stored refresh token.
  ///
  /// This revokes Life OS's own ability to mint Gmail access tokens for the
  /// user; it does not touch the grant on the Google account side (the user
  /// can also do that from myaccount.google.com). A missing row is a no-op,
  /// not an error, so disconnecting twice is harmless.
  Future<void> deleteCredentials() async {
    try {
      await _client.rpc<void>('disconnect_google');
    } catch (e) {
      debugPrint('[gmail] disconnect_google failed: $e');
      rethrow;
    }
  }
}

/// Provides the [GoogleCredentialsRepository].
final googleCredentialsRepositoryProvider =
    Provider<GoogleCredentialsRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return GoogleCredentialsRepository(client);
    });

/// Whether the signed-in user currently has a stored Gmail refresh token.
///
/// `autoDispose` so Settings re-checks fresh every time it's opened, rather
/// than caching a stale "connected" answer across a disconnect.
final gmailConnectedProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) return false;
  return ref.watch(googleCredentialsRepositoryProvider).hasCredentials();
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
        .saveRefreshToken(refreshToken: refreshToken)
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
