/// In-memory demo [AuthRepository] — always authenticated as the fixed
/// demo persona, "Alex." No Supabase, no network.
library;

import 'dart:async';

import 'package:life_os/features/auth/data/models/auth_state.dart';
import 'package:life_os/features/auth/data/repositories/auth_repository.dart';
import 'package:life_os/features/demo/data/demo_seed.dart';
import 'package:life_os/features/demo/demo_mode.dart';

/// Fixed authenticated state for the demo persona.
const demoAuthState = AuthState(
  status: AuthStatus.authenticated,
  userId: demoUserId,
  email: 'alex.demo@lifeos.app',
  displayName: 'Alex',
);

/// Stateless demo [AuthRepository] — always reports [demoAuthState].
///
/// [signOut] is the demo exit path: it flips [demoModeController] back to
/// `false`, which rebuilds the whole `ProviderScope` back to the real app.
class DemoAuthRepository implements AuthRepository {
  /// Creates a [DemoAuthRepository].
  const DemoAuthRepository();

  @override
  Future<AuthState> getCurrentAuthState() async => demoAuthState;

  @override
  Stream<AuthState> get authStateChanges => Stream.value(demoAuthState);

  @override
  Future<AuthState> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => demoAuthState;

  @override
  Future<AuthState> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async => demoAuthState;

  @override
  Future<AuthState> signInWithGoogle() async => demoAuthState;

  @override
  Future<void> signOut() async {
    // Deferred so the flip doesn't dispose the current ProviderScope
    // (and this repository along with it) mid-call.
    unawaited(Future.microtask(exitDemoMode));
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  String? currentGoogleAccessToken() => null;
}
