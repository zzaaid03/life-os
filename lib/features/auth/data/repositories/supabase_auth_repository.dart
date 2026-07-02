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
      displayName: user.userMetadata?['display_name'] as String?,
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
      displayName: user.userMetadata?['display_name'] as String?,
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
    final redirectTo = kIsWeb ? Uri.base.origin : null;

    final response = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );

    // OAuth flow redirects; state will be updated via authStateChanges.
    if (response) {
      return getCurrentAuthState();
    }

    return const AuthState(status: AuthStatus.unauthenticated);
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
        displayName: user.userMetadata?['display_name'] as String?,
      );
    });
  }
}
