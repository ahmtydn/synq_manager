/// Authentication state for the sync system
class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.user,
    this.isGuest = false,
    this.guestId,
    this.accessToken,
    this.refreshToken,
  });

  /// Factory for unauthenticated state
  factory AuthState.unauthenticated() {
    return const AuthState(isAuthenticated: false);
  }

  /// Factory for guest state
  factory AuthState.guest(String guestId) {
    return AuthState(
      isAuthenticated: false,
      isGuest: true,
      guestId: guestId,
    );
  }

  /// Factory for authenticated state
  factory AuthState.authenticated({
    required SyncUser user,
    String? accessToken,
    String? refreshToken,
  }) {
    return AuthState(
      isAuthenticated: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Whether the user is authenticated
  final bool isAuthenticated;

  /// The authenticated user (if any)
  final SyncUser? user;

  /// Whether the user is in guest mode
  final bool isGuest;

  /// Guest ID for tracking guest data
  final String? guestId;

  /// Access token for API calls
  final String? accessToken;

  /// Refresh token for token renewal
  final String? refreshToken;

  /// Copy with new values
  AuthState copyWith({
    bool? isAuthenticated,
    SyncUser? user,
    bool? isGuest,
    String? guestId,
    String? accessToken,
    String? refreshToken,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      isGuest: isGuest ?? this.isGuest,
      guestId: guestId ?? this.guestId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}

/// User model for authentication
class SyncUser {
  const SyncUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.metadata,
  });

  /// Create from JSON
  factory SyncUser.fromJson(Map<String, dynamic> json) {
    return SyncUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Unique user identifier
  final String id;

  /// User email
  final String email;

  /// Display name
  final String? name;

  /// Avatar URL
  final String? avatarUrl;

  /// Additional user metadata
  final Map<String, dynamic>? metadata;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'metadata': metadata,
    };
  }
}
