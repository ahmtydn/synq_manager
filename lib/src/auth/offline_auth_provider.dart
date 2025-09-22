import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synq_manager/src/core/auth_provider.dart';
import 'package:synq_manager/src/domain/auth_state.dart';
import 'package:uuid/uuid.dart';

/// Offline-first authentication provider
/// Supports guest mode, cached credentials, and offline login
class OfflineAuthProvider implements AuthProvider {
  OfflineAuthProvider({
    FlutterSecureStorage? secureStorage,
    Uuid? uuid,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  final FlutterSecureStorage _secureStorage;
  final Uuid _uuid;

  static const String _authStateKey = 'synq_auth_state';
  static const String _guestIdKey = 'synq_guest_id';
  static const String _credentialsKey = 'synq_cached_credentials';

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  AuthState _currentState = AuthState.unauthenticated();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    // Try to restore previous auth state
    await _restoreAuthState();

    _initialized = true;
  }

  @override
  Future<AuthState> login(String email, String password) async {
    _ensureInitialized();

    try {
      // In a real implementation, this would call your authentication service
      // For demo purposes, we'll simulate successful login
      final user = SyncUser(
        id: _uuid.v4(),
        email: email,
        name: email.split('@').first,
      );

      final authState = AuthState.authenticated(
        user: user,
        accessToken: 'demo_token_${_uuid.v4()}',
        refreshToken: 'refresh_${_uuid.v4()}',
      );

      // Cache credentials for offline use
      await _cacheCredentials(email, password);

      // Store auth state
      await _storeAuthState(authState);

      _currentState = authState;
      _authStateController.add(_currentState);

      return authState;
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  @override
  Future<AuthState> loginWithOAuth(
    String provider, {
    Map<String, dynamic>? parameters,
  }) async {
    _ensureInitialized();

    try {
      // OAuth implementation would go here
      // For demo purposes, we'll create a mock authenticated state
      final user = SyncUser(
        id: _uuid.v4(),
        email: 'oauth@example.com',
        name: 'OAuth User',
      );

      final authState = AuthState.authenticated(
        user: user,
        accessToken: 'oauth_token_${_uuid.v4()}',
        refreshToken: 'oauth_refresh_${_uuid.v4()}',
      );

      await _storeAuthState(authState);

      _currentState = authState;
      _authStateController.add(_currentState);

      return authState;
    } catch (e) {
      throw AuthException('OAuth login failed: $e');
    }
  }

  @override
  Future<AuthState> loginAsGuest() async {
    _ensureInitialized();

    try {
      var guestId = await getStoredGuestId();
      guestId ??= _uuid.v4();

      await _secureStorage.write(key: _guestIdKey, value: guestId);

      final authState = AuthState.guest(guestId);

      await _storeAuthState(authState);

      _currentState = authState;
      _authStateController.add(_currentState);

      return authState;
    } catch (e) {
      throw AuthException('Guest login failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    _ensureInitialized();

    await clearAuthData();

    _currentState = AuthState.unauthenticated();
    _authStateController.add(_currentState);
  }

  @override
  Future<AuthState> refreshToken(String refreshToken) async {
    _ensureInitialized();

    try {
      // In a real implementation, this would call your token refresh endpoint
      // For demo purposes, we'll generate new tokens
      final newAccessToken = 'refreshed_token_${_uuid.v4()}';
      final newRefreshToken = 'new_refresh_${_uuid.v4()}';

      final updatedState = _currentState.copyWith(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      await _storeAuthState(updatedState);

      _currentState = updatedState;
      _authStateController.add(_currentState);

      return updatedState;
    } catch (e) {
      throw AuthException('Token refresh failed: $e');
    }
  }

  @override
  Future<AuthState> getCurrentAuthState() async {
    _ensureInitialized();
    return _currentState;
  }

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthState> upgradeGuestAccount({
    required String email,
    required String password,
    bool mergeGuestData = true,
  }) async {
    _ensureInitialized();

    if (!_currentState.isGuest) {
      throw const AuthException('Current user is not a guest');
    }

    try {
      // Perform login
      final authState = await login(email, password);

      // If mergeGuestData is true, the caller should handle merging guest data
      // This is typically done by the SyncManager based on the SyncPolicy

      return authState;
    } catch (e) {
      throw AuthException('Guest account upgrade failed: $e');
    }
  }

  @override
  Future<bool> hasOfflineCredentials() async {
    _ensureInitialized();

    try {
      final credentials = await _secureStorage.read(key: _credentialsKey);
      return credentials != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthState> loginOffline() async {
    _ensureInitialized();

    try {
      final credentialsJson = await _secureStorage.read(key: _credentialsKey);
      if (credentialsJson == null) {
        throw const AuthException('No cached credentials available');
      }

      final credentials = jsonDecode(credentialsJson) as Map<String, dynamic>;
      final email = credentials['email'] as String;

      // Create offline auth state with cached user info
      final user = SyncUser(
        id: credentials['userId'] as String,
        email: email,
        name: credentials['name'] as String?,
      );

      final authState = AuthState.authenticated(
        user: user,
        accessToken: 'offline_token',
        refreshToken: 'offline_refresh',
      );

      _currentState = authState;
      _authStateController.add(_currentState);

      return authState;
    } catch (e) {
      throw AuthException('Offline login failed: $e');
    }
  }

  @override
  bool isTokenValid(String? token) {
    if (token == null) return false;

    // In a real implementation, you would validate the token
    // For demo purposes, we'll consider non-empty tokens as valid
    return token.isNotEmpty && token != 'offline_token';
  }

  @override
  Future<void> storeAuthData(AuthState authState) async {
    _ensureInitialized();
    await _storeAuthState(authState);
  }

  @override
  Future<void> clearAuthData() async {
    _ensureInitialized();

    await Future.wait([
      _secureStorage.delete(key: _authStateKey),
      _secureStorage.delete(key: _credentialsKey),
      // Note: We keep the guest ID for potential future use
    ]);
  }

  @override
  Future<String?> getStoredGuestId() async {
    _ensureInitialized();

    try {
      return await _secureStorage.read(key: _guestIdKey);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _authStateController.close();
  }

  /// Cache user credentials for offline use
  Future<void> _cacheCredentials(String email, String password) async {
    final credentials = {
      'email': email,
      'password':
          password, // In production, store hashed password or use tokens
      'userId': _currentState.user?.id,
      'name': _currentState.user?.name,
      'cachedAt': DateTime.now().toIso8601String(),
    };

    await _secureStorage.write(
      key: _credentialsKey,
      value: jsonEncode(credentials),
    );
  }

  /// Store authentication state securely
  Future<void> _storeAuthState(AuthState authState) async {
    final authData = {
      'isAuthenticated': authState.isAuthenticated,
      'isGuest': authState.isGuest,
      'guestId': authState.guestId,
      'accessToken': authState.accessToken,
      'refreshToken': authState.refreshToken,
      'user': authState.user?.toJson(),
    };

    await _secureStorage.write(
      key: _authStateKey,
      value: jsonEncode(authData),
    );
  }

  /// Restore authentication state from secure storage
  Future<void> _restoreAuthState() async {
    try {
      final authDataJson = await _secureStorage.read(key: _authStateKey);
      if (authDataJson == null) {
        _currentState = AuthState.unauthenticated();
        return;
      }

      final authData = jsonDecode(authDataJson) as Map<String, dynamic>;

      SyncUser? user;
      if (authData['user'] != null) {
        user = SyncUser.fromJson(authData['user'] as Map<String, dynamic>);
      }

      _currentState = AuthState(
        isAuthenticated: authData['isAuthenticated'] as bool,
        user: user,
        isGuest: authData['isGuest'] as bool? ?? false,
        guestId: authData['guestId'] as String?,
        accessToken: authData['accessToken'] as String?,
        refreshToken: authData['refreshToken'] as String?,
      );

      _authStateController.add(_currentState);
    } catch (e) {
      // If restoration fails, start with unauthenticated state
      _currentState = AuthState.unauthenticated();
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('OfflineAuthProvider must be initialized before use');
    }
  }
}

/// Exception thrown by OfflineAuthProvider
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
