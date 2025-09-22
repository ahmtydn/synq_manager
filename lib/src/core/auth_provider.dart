import 'package:synq_manager/src/domain/auth_state.dart';

/// Abstract interface for authentication providers
/// Supports both online and offline authentication modes
abstract class AuthProvider {
  /// Initialize the auth provider
  Future<void> initialize();

  /// Login with email and password
  Future<AuthState> login(String email, String password);

  /// Login with OAuth (Google, Apple, etc.)
  Future<AuthState> loginWithOAuth(
    String provider, {
    Map<String, dynamic>? parameters,
  });

  /// Create a guest session for offline use
  Future<AuthState> loginAsGuest();

  /// Logout and clear authentication state
  Future<void> logout();

  /// Refresh the access token
  Future<AuthState> refreshToken(String refreshToken);

  /// Get the current authentication state
  Future<AuthState> getCurrentAuthState();

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges;

  /// Upgrade guest account to full account
  Future<AuthState> upgradeGuestAccount({
    required String email,
    required String password,
    bool mergeGuestData = true,
  });

  /// Check if offline login is available (cached credentials)
  Future<bool> hasOfflineCredentials();

  /// Login with cached credentials when offline
  Future<AuthState> loginOffline();

  /// Validate current token without network call
  bool isTokenValid(String? token);

  /// Store authentication data securely
  Future<void> storeAuthData(AuthState authState);

  /// Clear stored authentication data
  Future<void> clearAuthData();

  /// Get stored guest ID
  Future<String?> getStoredGuestId();

  /// Clean up resources
  Future<void> dispose();
}
