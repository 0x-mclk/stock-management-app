import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_mode.dart';

class AuthResult {
  final bool success;
  final String? message;

  AuthResult({required this.success, this.message});
}

class LogoutResult {
  final bool success;
  final String? error;

  LogoutResult({required this.success, this.error});
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  // Keys for SharedPreferences
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserName = 'user_name';
  static const String _keyStoreName = 'store_name';
  static const String _keyStoreId = 'store_id';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyUserSession = 'user_session';
  static const String _keyRememberMe = 'remember_me';
  static const String _keySavedEmail = 'saved_email';
  static const String _keySavedPassword = 'saved_password';

  // Current user session
  UserSession? _currentUserSession;

  /// Get current user session
  UserSession? get currentUserSession => _currentUserSession;

  /// Get current user session (alias for compatibility)
  UserSession? get currentSession => _currentUserSession;

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  /// Check if onboarding is completed (alias for compatibility)
  Future<bool> hasCompletedOnboarding() async {
    return await isOnboardingCompleted();
  }

  /// Check if there's a previous user session
  Future<bool> hasPreviousSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_keyUserSession);
    return sessionJson != null && sessionJson.isNotEmpty;
  }

  /// Restore previous session
  Future<UserSession?> restoreSession() async {
    await loadUserSession();
    return _currentUserSession;
  }

  /// Debug method to list all users (placeholder for development)
  Future<void> debugListAllUsers() async {
    // This is a debug method, could log current session info
    // // Debug print removed // Removed for production
  }

  /// Complete onboarding process
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  /// Start guest session with local store ID
  Future<void> startGuestSession({
    required String userName,
    required String storeName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Generate a unique store ID for guest session
    final storeId = 'guest_${DateTime.now().millisecondsSinceEpoch}';

    // Create user session using factory method
    _currentUserSession = UserSession.guest(
      userName: userName,
      storeName: storeName,
      storeId: storeId,
    );

    // Save to SharedPreferences
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyStoreName, storeName);
    await prefs.setString(_keyStoreId, storeId);
    await prefs.setString(
        _keyUserSession, jsonEncode(_currentUserSession!.toJson()));
  }

  /// Login user with Firebase authentication
  Future<void> loginUser({
    required String userId,
    required String userName,
    required String email,
    required String storeName,
    required String storeId,
    UserMode mode = UserMode.basic,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Create user session using factory method
    _currentUserSession = UserSession.registered(
      userId: userId,
      userName: userName,
      userEmail: email,
      storeName: storeName,
      storeId: storeId,
      mode: mode,
    );

    // Save to SharedPreferences
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyStoreName, storeName);
    await prefs.setString(_keyStoreId, storeId);
    await prefs.setString(
        _keyUserSession, jsonEncode(_currentUserSession!.toJson()));
  }

  /// Login method (alias for compatibility)
  Future<AuthResult> login({
    required String email,
    required String password,
    String? userName,
    String? storeName,
    String? storeId,
    bool rememberMe = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save credentials if remember me is checked
      if (rememberMe) {
        await prefs.setBool(_keyRememberMe, true);
        await prefs.setString(_keySavedEmail, email);
        await prefs.setString(_keySavedPassword, password);
        // // Debug print removed // Removed for production
      } else {
        // Clear saved credentials
        await prefs.remove(_keyRememberMe);
        await prefs.remove(_keySavedEmail);
        await prefs.remove(_keySavedPassword);
        // // Debug print removed // Removed for production
      }

      // For now, just do local login until Firebase integration is complete
      await loginUser(
        userId: email,
        userName: userName ?? 'User',
        email: email,
        storeName: storeName ?? 'Store',
        storeId: storeId ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
        mode: UserMode.basic,
      );
      return AuthResult(success: true, message: 'Login successful');
    } catch (e) {
      // // Debug print removed // Removed for production
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// Register method (alias for compatibility)
  Future<AuthResult> register({
    required String email,
    required String password,
    String? name,
    String? userName,
    required String storeName,
  }) async {
    try {
      await loginUser(
        userId: email,
        userName: name ?? userName ?? 'User',
        email: email,
        storeName: storeName,
        storeId: 'registered_${DateTime.now().millisecondsSinceEpoch}',
        mode: UserMode.basic,
      );
      return AuthResult(success: true, message: 'Registration successful');
    } catch (e) {
      // // Debug print removed // Removed for production
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// Send password reset (placeholder for Firebase integration)
  Future<AuthResult> sendPasswordReset({required String email}) async {
    try {
      // This would integrate with Firebase Auth
      // // Debug print removed // Removed for production
      return AuthResult(success: true, message: 'Password reset email sent');
    } catch (e) {
      // // Debug print removed // Removed for production
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// Update store information
  Future<void> updateStoreInfo({
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? ownerName,
  }) async {
    if (_currentUserSession != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStoreName, storeName);

      // Save additional info if provided
      if (storeAddress != null) {
        await prefs.setString('store_address', storeAddress);
      }
      if (storePhone != null) {
        await prefs.setString('store_phone', storePhone);
      }
      if (ownerName != null) {
        await prefs.setString('owner_name', ownerName);
      }

      // Update current session with new store name
      // Note: We'd need to create a new UserSession with updated info
      // // Debug print removed // Removed for production
    }
  }

  /// Get user name
  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  /// Get store name
  Future<String?> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreName);
  }

  /// Get store ID
  Future<String?> getStoreId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStoreId);
  }

  /// Get user email
  Future<String?> getUserEmail() async {
    return _currentUserSession?.userEmail;
  }

  /// Check if user has a specific permission
  bool hasPermission(String permission) {
    return _currentUserSession?.hasPermission(permission) ?? false;
  }

  /// Check if user is in guest mode
  bool isGuestMode() {
    return _currentUserSession?.mode == UserMode.guest;
  }

  /// Load user session from SharedPreferences
  Future<void> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_keyUserSession);

    if (sessionJson != null) {
      try {
        final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
        _currentUserSession = UserSession.fromJson(sessionMap);
      } catch (e) {
        // If parsing fails, clear the session but keep Remember Me
        await logout(clearRemembered: false);
      }
    }
  }

  /// Update user session
  Future<void> updateUserSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserSession = session;
    await prefs.setString(_keyUserSession, jsonEncode(session.toJson()));
    await prefs.setString(_keyUserName, session.userName);
    await prefs.setString(_keyStoreName, session.storeName);
    await prefs.setString(_keyStoreId, session.storeId ?? '');
  }

  /// Logout user
  Future<LogoutResult> logout({bool clearRemembered = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // // Debug print removed // Removed for production

      // Clear all user data
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyStoreName);
      await prefs.remove(_keyStoreId);
      await prefs.remove(_keyUserSession);
      // // Debug print removed // Removed for production

      // Clear remembered credentials if requested
      if (clearRemembered) {
        await prefs.remove(_keyRememberMe);
        await prefs.remove(_keySavedEmail);
        await prefs.remove(_keySavedPassword);
        // // Debug print removed // Removed for production
      } else {
        // // Debug print removed // Removed for production
      }

      // Clear current session
      _currentUserSession = null;

      // // Debug print removed // Removed for production

      return LogoutResult(success: true);
    } catch (e) {
      // // Debug print removed // Removed for production
      return LogoutResult(success: false, error: e.toString());
    }
  }

  /// Check if auto-login is available and attempt it
  Future<AuthResult> checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      // // Debug print removed // Removed for production

      if (!rememberMe) {
        // // Debug print removed // Removed for production
        return AuthResult(success: false, message: 'Auto-login not enabled');
      }

      final savedEmail = prefs.getString(_keySavedEmail);
      final savedPassword = prefs.getString(_keySavedPassword);

      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production

      if (savedEmail == null || savedPassword == null) {
        // // Debug print removed // Removed for production
        return AuthResult(success: false, message: 'No saved credentials');
      }

      // // Debug print removed // Removed for production

      // Attempt auto-login with saved credentials
      return await login(
        email: savedEmail,
        password: savedPassword,
        rememberMe: true, // Keep remember me active
      );
    } catch (e) {
      // // Debug print removed // Removed for production
      return AuthResult(success: false, message: e.toString());
    }
  }

  /// Clear saved credentials
  Future<void> clearRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRememberMe);
      await prefs.remove(_keySavedEmail);
      await prefs.remove(_keySavedPassword);
      // // Debug print removed // Removed for production
    } catch (e) {
      // // Debug print removed // Removed for production
    }
  }

  /// Check if user has saved credentials
  Future<bool> hasRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      final savedEmail = prefs.getString(_keySavedEmail);

      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production
      // // Debug print removed // Removed for production

      return rememberMe && savedEmail != null;
    } catch (e) {
      // // Debug print removed // Removed for production
      return false;
    }
  }

  /// Get saved email for display
  Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keySavedEmail);
    } catch (e) {
      // // Debug print removed // Removed for production
      return null;
    }
  }

  /// Initialize AuthService (call this at app startup)
  Future<void> initialize() async {
    await loadUserSession();
  }
}




