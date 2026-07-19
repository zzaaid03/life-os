/// Authentication state provider using Riverpod.
///
/// Manages the global authentication state and exposes
/// methods for sign-in, sign-up, and sign-out.
library;

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/data/repositories/auth_repository.dart';
import 'package:life_os/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:riverpod/riverpod.dart';

/// Provider for overriding the [AuthRepository] in tests.
final authRepositoryProviderOverride = Provider<AuthRepository?>((ref) => null);

/// The main authentication state notifier.
class AuthNotifier extends StateNotifier<AuthState> {
  /// Creates an [AuthNotifier] with the given [repository].
  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  final AuthRepository _repository;

  void _init() {
    _repository.authStateChanges.listen((authState) {
      state = authState;
    });

    // Trigger initial state check.
    _repository.getCurrentAuthState().then((authState) {
      state = authState;
    });
  }

  /// Signs in with email and password.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.unknown);
    try {
      final newState = await _repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = newState;
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  /// Signs up with email and password.
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.unknown);
    try {
      final newState = await _repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = newState;
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  /// Signs in with Google.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.unknown);
    try {
      final newState = await _repository.signInWithGoogle();
      state = newState;
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      rethrow;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _repository.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _repository.sendPasswordResetEmail(email: email);
  }

  /// Updates the display name in the user's auth metadata.
  ///
  /// Updates local state immediately so the UI (e.g. the dashboard
  /// greeting) reflects the change without waiting for a session
  /// refresh or re-authentication.
  Future<void> updateDisplayName(String displayName) async {
    await _repository.updateDisplayName(displayName);
    state = state.copyWith(displayName: displayName);
  }
}

/// The global authentication provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repositoryOverride = ref.watch(authRepositoryProviderOverride);
  final AuthRepository repository;
  if (repositoryOverride != null) {
    repository = repositoryOverride;
  } else {
    repository = ref.watch(authRepositoryProvider);
  }
  return AuthNotifier(repository);
});
