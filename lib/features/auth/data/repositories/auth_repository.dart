/// Authentication repository interface.
///
/// Defines the contract for authentication operations.
/// Implementations handle the actual auth logic (Supabase, etc.).
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';

/// Abstract repository for authentication operations.
abstract class AuthRepository {
  /// Returns the current authentication state.
  Future<AuthState> getCurrentAuthState();

  /// Signs in with email and password.
  Future<AuthState> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs up with email and password.
  Future<AuthState> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Signs in with Google.
  Future<AuthState> signInWithGoogle();

  /// Signs out the current user.
  Future<void> signOut();

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail({required String email});

  /// Updates the display name stored in the user's auth metadata.
  Future<void> updateDisplayName(String displayName);

  /// Returns the Google OAuth provider access token for the current session,
  /// or null if unavailable.
  ///
  /// This token is required to call the `extract-tasks` Edge Function, which
  /// reads the user's Gmail server-side. Supabase only populates
  /// `providerToken` in-session immediately after a Google sign-in — it is
  /// NOT persisted, so it returns null after a full page reload. Callers must
  /// handle a null result by asking the user to reconnect Gmail (re-run the
  /// Google sign-in flow).
  String? currentGoogleAccessToken();

  /// Stream of authentication state changes.
  Stream<AuthState> get authStateChanges;
}
