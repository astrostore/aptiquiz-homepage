import 'dart:async';
import 'dart:math';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/services/storage_service.dart';

class AuthResult {
  final bool success;
  final String? error;
  final User? user;
  final String? verificationCode;

  AuthResult({
    required this.success,
    this.error,
    this.user,
    this.verificationCode,
  });
}

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  UserSession? _currentSession;
  final Map<String, String> _verificationCodes = {};
  final Map<String, User> _pendingRegistrations = {};

  UserSession? get currentSession => _currentSession;
  User? get currentUser => _currentSession?.user;
  bool get isAuthenticated => _currentSession != null && !_currentSession!.isExpired;

  // Stream controller for auth state changes
  final StreamController<UserSession?> _authStateController = StreamController<UserSession?>.broadcast();
  Stream<UserSession?> get authStateChanges => _authStateController.stream;

  Future<void> initialize() async {
    // Try to load saved session
    final sessionData = await StorageService.getCurrentUserSession();
    if (sessionData != null) {
      final session = UserSession.fromJson(sessionData);
      if (!session.isExpired) {
        _currentSession = session.updateActivity();
        _authStateController.add(_currentSession);
      }
    }

    // Create default super admin if no users exist
    await _createDefaultSuperAdmin();
  }

  Future<void> _createDefaultSuperAdmin() async {
    final users = await StorageService.getAllUsers();
    if (users.isEmpty) {
      final superAdmin = User(
        id: 'super_admin_1',
        name: 'Super Admin',
        email: 'admin@cognispark.com',
        mobile: '+1234567890',
        role: UserRole.superAdmin,
        createdAt: DateTime.now(),
        isEmailVerified: true,
      );
      await StorageService.saveUser(superAdmin);
      
      // Store password (in a real app, this would be hashed)
      await StorageService.saveUserCredentials(superAdmin.email, 'admin123');
    }
  }

  Future<AuthResult> registerUser({
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await StorageService.getUserByEmail(email);
      if (existingUser != null) {
        return AuthResult(
          success: false,
          error: 'User with this email already exists',
        );
      }

      // Generate verification code
      final verificationCode = _generateVerificationCode();
      
      // Create pending user (not saved until email verification)
      final user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        mobile: mobile,
        role: UserRole.regularUser, // All new users start as regular users
        createdAt: DateTime.now(),
        isEmailVerified: false,
      );

      // Store pending registration and verification code
      _pendingRegistrations[email] = user;
      _verificationCodes[email] = verificationCode;

      // Store password temporarily (in a real app, this would be hashed)
      await StorageService.saveUserCredentials(email, password);

      // In a real app, you would send email here
      print('Verification code for $email: $verificationCode');

      return AuthResult(
        success: true,
        verificationCode: verificationCode, // For demo purposes only
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Registration failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String verificationCode,
  }) async {
    try {
      final storedCode = _verificationCodes[email];
      if (storedCode == null || storedCode != verificationCode) {
        return AuthResult(
          success: false,
          error: 'Invalid verification code',
        );
      }

      final pendingUser = _pendingRegistrations[email];
      if (pendingUser == null) {
        return AuthResult(
          success: false,
          error: 'Registration not found',
        );
      }

      // Verify user and save to storage
      final verifiedUser = pendingUser.copyWith(isEmailVerified: true);
      await StorageService.saveUser(verifiedUser);

      // Clean up pending registration
      _pendingRegistrations.remove(email);
      _verificationCodes.remove(email);

      return AuthResult(
        success: true,
        user: verifiedUser,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Email verification failed: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await StorageService.getUserByEmail(email);
      if (user == null) {
        return AuthResult(
          success: false,
          error: 'User not found',
        );
      }

      if (!user.isEmailVerified) {
        return AuthResult(
          success: false,
          error: 'Please verify your email before signing in',
        );
      }

      if (!user.isActive) {
        return AuthResult(
          success: false,
          error: 'Account is deactivated',
        );
      }

      // Verify password (in a real app, this would be hashed comparison)
      final storedPassword = await StorageService.getUserPassword(email);
      if (storedPassword != password) {
        return AuthResult(
          success: false,
          error: 'Invalid password',
        );
      }

      // Create session
      final session = UserSession(
        sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
        user: user.copyWith(lastLoginAt: DateTime.now()),
        loginTime: DateTime.now(),
        lastActivity: DateTime.now(),
      );

      _currentSession = session;
      await StorageService.saveCurrentUserSession(session.toJson());
      await StorageService.saveUser(session.user);

      _authStateController.add(_currentSession);

      return AuthResult(
        success: true,
        user: session.user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Sign in failed: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    _currentSession = null;
    await StorageService.clearCurrentUserSession();
    _authStateController.add(null);
  }

  Future<AuthResult> updateUserRole({
    required String userId,
    required UserRole newRole,
  }) async {
    try {
      if (!_canManageUsers()) {
        return AuthResult(
          success: false,
          error: 'Insufficient permissions to manage users',
        );
      }

      final user = await StorageService.getUserById(userId);
      if (user == null) {
        return AuthResult(
          success: false,
          error: 'User not found',
        );
      }

      final updatedUser = user.copyWith(role: newRole);
      await StorageService.saveUser(updatedUser);

      // Update current session if it's the same user
      if (_currentSession?.user.id == userId) {
        _currentSession = _currentSession!.copyWith(user: updatedUser);
        await StorageService.saveCurrentUserSession(_currentSession!.toJson());
        _authStateController.add(_currentSession);
      }

      return AuthResult(
        success: true,
        user: updatedUser,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: 'Failed to update user role: ${e.toString()}',
      );
    }
  }

  bool _canManageUsers() {
    return currentUser?.role == UserRole.superAdmin;
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void dispose() {
    _authStateController.close();
  }
}

// Extension to add copyWith method to UserSession
extension UserSessionCopyWith on UserSession {
  UserSession copyWith({
    String? sessionId,
    User? user,
    DateTime? loginTime,
    DateTime? lastActivity,
    Map<String, dynamic>? sessionData,
  }) => UserSession(
        sessionId: sessionId ?? this.sessionId,
        user: user ?? this.user,
        loginTime: loginTime ?? this.loginTime,
        lastActivity: lastActivity ?? this.lastActivity,
        sessionData: sessionData ?? this.sessionData,
      );
}