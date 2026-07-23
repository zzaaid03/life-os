/// Supabase implementation of [AuthRepository].
///
/// Handles all authentication operations through Supabase Auth.
library;

import 'package:flutter/foundation.dart';
import 'package:life_os/core/services/supabase_service.dart';
import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/data/repositories/auth_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide
        AuthState; // Hide Supabase's AuthState to avoid conflict with our model.

/// Riverpod provider for the [AuthRepository].
///
/// Provides the Supabase-backed implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(supabase);
});

/// Supabase-backed implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  /// Creates a [SupabaseAuthRepository] with the given [SupabaseClient].
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Extracts the best available display name from auth user metadata.
  ///
  /// Email/password sign-up stores the name under `display_name`.
  /// Google (and most OAuth providers) instead populate `full_name`
  /// or `name`. Checking all three ensures every sign-in method ends
  /// up with a real name instead of falling back to the email prefix.
  String? _extractDisplayName(Map<String, dynamic>? metadata) {
    return metadata?['display_name'] as String? ??
        metadata?['full_name'] as String? ??
        metadata?['name'] as String?;
  }

  @override
  Future<AuthState> getCurrentAuthState() async {
    final session = _client.auth.currentSession;
    final user = session?.user;

    if (user == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.id,
      email: user.email,
      displayName: _extractDisplayName(user.userMetadata),
    );
  }

  @override
  Future<AuthState> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.id,
      email: user.email,
      displayName: _extractDisplayName(user.userMetadata),
    );
  }

  @override
  Future<AuthState> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    final user = response.user;
    if (user == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.id,
      email: user.email,
      displayName: displayName,
    );
  }

  @override
  Future<AuthState> signInWithGoogle() async {
    // On web, Google needs to redirect back to the exact localhost origin
    // (e.g. http://localhost:51915). Without redirectTo, Supabase defaults
    // to the Site URL configured in the dashboard, which is the production
    // URL — Google redirects there instead, breaking local dev.
    //
    // On native platforms (Android, iOS), OAuth uses platform-specific
    // deep links / custom URL schemes, so no redirectTo is needed.
    final redirectTo =
        kIsWeb ? Uri.base.origin : 'com.lifeos.app://login-callback';

    final response = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      // Request read-only Gmail access in addition to the default
      // profile/email scopes so the `extract-tasks` Edge Function can read
      // the user's inbox server-side. `access_type: offline` asks Google for
      // a refresh token; `prompt: 'select_account consent'` always shows the
      // account chooser AND forces the consent screen, so Google returns a
      // fresh refresh token on every sign-in (needed to persist access).
      scopes: 'email profile https://www.googleapis.com/auth/gmail.readonly',
      queryParams: const {
        'access_type': 'offline',
        'prompt': 'select_account consent',
      },
    );

    // OAuth flow redirects; state will be updated via authStateChanges.
    if (response) {
      return getCurrentAuthState();
    }

    return const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  String? currentGoogleAccessToken() {
    // `providerToken` is only present in-session right after a Google
    // sign-in; it is not restored on session refresh / page reload, so
    // this can legitimately return null even while authenticated.
    return _client.auth.currentSession?.providerToken;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'display_name': displayName}),
    );
  }

  @override
  Stream<AuthState> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final session = event.session;
      final user = session?.user;

      if (user == null) {
        return const AuthState(status: AuthStatus.unauthenticated);
      }

      return AuthState(
        status: AuthStatus.authenticated,
        userId: user.id,
        email: user.email,
        displayName: _extractDisplayName(user.userMetadata),
      );
    });
  }
}
