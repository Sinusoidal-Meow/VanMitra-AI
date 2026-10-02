import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/local/hive_database.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_initialization_service.dart';
import '../services/cloud_sync_service.dart';

// ─── Auth State ────────────────────────────────────────────────────────────

/// Represents the complete authentication state of the app.
class AuthState {
  final User? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    User? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─── Auth Notifier ─────────────────────────────────────────────────────────

/// Manages authentication state using Firebase Email/Password & Demo Roles.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();

  // ─── Step 1: Check existing session on app start ──────────────────────

  /// Called from SplashScreen to restore session after app restart.
  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);

    try {
      // Try reading from Hive first (fast path, already persisted)
      final box = Hive.box<Map>(HiveDatabase.userBox);
      if (box.isNotEmpty) {
        final userData = box.getAt(0);
        if (userData != null) {
          final user = User.fromJson(Map<String, dynamic>.from(userData));
          state = AuthState(
            currentUser: user,
            isAuthenticated: true,
            isLoading: false,
          );
          return;
        }
      }

      final fbUser = _firebaseAuth.currentUser;
      if (fbUser == null) {
        state = const AuthState(isLoading: false);
        return;
      }

      // Hive empty → fetch fresh from Firestore
      var fsUser = await _firebaseAuth.getFirestoreUser(fbUser.uid);
      fsUser ??= await _firebaseAuth.ensureUserProfile(
        uid: fbUser.uid,
        email: fbUser.email ?? '',
      );

      final user = _buildUserFromFirestore(fbUser.uid, fsUser);
      await _persistToHive(user);
      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        isLoading: false,
        errorMessage: 'Session check failed: ${e.toString()}',
      );
    }
  }

  // ─── Step 2: Login ───────────────────────────────────────────────────

  /// Logs in a user. Returns role string on success for navigation.
  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final credential = await _firebaseAuth.loginWithEmail(email, password);
      final fbUser = credential.user;

      if (fbUser == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-in failed. Please try again.',
        );
        return null;
      }

      var fsUser = await _firebaseAuth.getFirestoreUser(fbUser.uid);
      fsUser ??= await _firebaseAuth.ensureUserProfile(
        uid: fbUser.uid,
        email: fbUser.email ?? email,
      );

      final user = _buildUserFromFirestore(fbUser.uid, fsUser);
      await _persistToHive(user);

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );

      _initializeAndSync(user);
      return user.role.name;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  // ─── Step 3: Demo Quick Login for any of the 12 roles ─────────────────

  /// Quick login for development/demo mode to switch between any of the 12 roles instantly.
  Future<String> loginAsDemoRole(UserRole role) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final demoUser = User(
      id: 'demo_${role.name}_user',
      email: role.demoEmail,
      name: '${role.displayNameEn} (Demo)',
      role: role,
      villageId: 'ozhar_jawhar_palghar',
      tehsil: 'Jawhar',
      district: 'Palghar',
      state: 'Maharashtra',
      createdAt: DateTime.now(),
    );

    await _persistToHive(demoUser);

    state = AuthState(
      currentUser: demoUser,
      isAuthenticated: true,
      isLoading: false,
    );

    return role.name;
  }

  // ─── Step 4: Register ────────────────────────────────────────────────

  /// Registers a new user. Returns role string on success for navigation.
  Future<String?> register(
    String email,
    String password,
    String name,
    String role,
    String villageId,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final credential = await _firebaseAuth.registerWithEmail(
        email: email,
        password: password,
        name: name,
        role: role,
        villageId: villageId,
      );

      final fbUser = credential.user;
      if (fbUser == null) throw Exception('Registration returned null user.');

      final fsUser = await _firebaseAuth.getFirestoreUser(fbUser.uid);
      if (fsUser == null) throw Exception('Profile creation failed.');

      final user = _buildUserFromFirestore(fbUser.uid, fsUser);
      await _persistToHive(user);

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );

      _initializeAndSync(user);
      return user.role.name;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> updateLanguage(String lang) async {
    if (state.currentUser == null) return;
    final updated = state.currentUser!.copyWith(preferredLanguage: lang);
    await _persistToHive(updated);
    state = state.copyWith(currentUser: updated);
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    final box = Hive.box<Map>(HiveDatabase.userBox);
    await box.clear();
    state = const AuthState();
  }

  // ─── Private Helpers ─────────────────────────────────────────────────

  User _buildUserFromFirestore(
    String uid,
    Map<String, dynamic> fsData,
  ) {
    final roleStr = fsData['role'] as String? ?? 'villager';
    final role = UserRoleExtension.parse(roleStr);

    return User(
      id: uid,
      email: fsData['email'] as String? ?? '',
      name: fsData['name'] as String? ?? '',
      role: role,
      villageId: fsData['villageId'] as String? ?? 'ozhar_jawhar_palghar',
      tehsil: fsData['tehsil'] as String? ?? 'Jawhar',
      district: fsData['district'] as String? ?? 'Palghar',
      state: fsData['state'] as String? ?? 'Maharashtra',
      preferredLanguage: fsData['preferredLanguage'] as String? ?? 'mr',
      createdAt: fsData['createdAt'] != null
          ? (fsData['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Future<void> _persistToHive(User user) async {
    final box = Hive.box<Map>(HiveDatabase.userBox);
    await box.clear();
    await box.add(user.toJson());
  }

  void _initializeAndSync(User user) {
    FirestoreInitializationService()
        .initializeForUser(user)
        .catchError((_) {});
    CloudSyncService().syncPendingItems().catchError((_) {});
  }
} // end AuthNotifier

// ─── Provider ──────────────────────────────────────────────────────────────

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
