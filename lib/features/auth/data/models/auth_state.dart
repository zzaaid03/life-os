/// Authentication state model.
///
/// Represents the current authentication state of the user.
library;

import 'package:equatable/equatable.dart';

/// The current status of authentication.
enum AuthStatus {
  /// Initial state — authentication has not been checked yet.
  unknown,

  /// User is authenticated.
  authenticated,

  /// User is not authenticated.
  unauthenticated,
}

/// Represents the full authentication state.
class AuthState extends Equatable {
  /// Creates an [AuthState].
  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.email,
    this.displayName,
  });

  /// The current authentication status.
  final AuthStatus status;

  /// The authenticated user's ID, if available.
  final String? userId;

  /// The authenticated user's email, if available.
  final String? email;

  /// The authenticated user's display name, if available.
  final String? displayName;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Whether the authentication state is still being determined.
  bool get isLoading => status == AuthStatus.unknown;

  /// Creates a copy of this state with the given fields replaced.
  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    String? displayName,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [status, userId, email, displayName];
}
