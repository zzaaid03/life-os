/// Profile data model.
///
/// Represents a user's Life OS profile stored in Supabase.
/// Mirrors the `public.profiles` table schema.
library;

import 'package:equatable/equatable.dart';

/// Authentication provider used to sign in.
enum AuthProvider {
  /// Email and password authentication.
  email,

  /// Google OAuth authentication.
  google,
}

/// A user's Life OS profile.
///
/// Created automatically on first sign-in via Supabase trigger.
/// Contains the user's display name, email, and metadata.
class Profile extends Equatable {
  /// Creates a [Profile].
  const Profile({
    required this.id,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.provider = AuthProvider.email,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates an empty profile for initialization.
  const Profile.empty()
    : id = '',
      displayName = null,
      email = null,
      avatarUrl = null,
      provider = AuthProvider.email,
      createdAt = null,
      updatedAt = null;

  /// Creates a [Profile] from a Supabase JSON response.
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      provider: _parseProvider(json['provider'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// The user's unique ID (matches auth.users.id).
  final String id;

  /// The user's chosen display name.
  final String? displayName;

  /// The user's email address.
  final String? email;

  /// URL to the user's avatar image.
  final String? avatarUrl;

  /// The authentication provider used.
  final AuthProvider provider;

  /// When the profile was created.
  final DateTime? createdAt;

  /// When the profile was last updated.
  final DateTime? updatedAt;

  /// Creates a copy of this profile with the given fields replaced.
  Profile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    AuthProvider? provider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this profile to a JSON map for Supabase.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'avatar_url': avatarUrl,
      'provider': provider.name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static AuthProvider _parseProvider(String? value) {
    return switch (value) {
      'google' => AuthProvider.google,
      _ => AuthProvider.email,
    };
  }

  @override
  List<Object?> get props => [
    id,
    displayName,
    email,
    avatarUrl,
    provider,
    createdAt,
    updatedAt,
  ];
}
