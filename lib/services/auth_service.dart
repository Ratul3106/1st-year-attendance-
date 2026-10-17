import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';

class RoleMismatchAuthException implements Exception {
  final String message;
  final UserRole selectedRole;
  final UserRole actualRole;

  RoleMismatchAuthException({
    required this.message,
    required this.selectedRole,
    required this.actualRole,
  });

  @override
  String toString() => message;
}

class AuthService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser {
    if (DemoDataService.instance.currentDemoUser != null) {
      return DemoDataService.instance.currentDemoUser;
    }
    return _supabase?.auth.currentUser;
  }

  /// Authenticates user and validates that selected role strictly matches authorized database role.
  Future<UserProfile> signInWithRole({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      final success = DemoDataService.instance.loginAsDemo(
        email,
        requestedRole: selectedRole,
      );

      final profile = DemoDataService.instance.currentDemoProfile;
      if (!success && profile != null) {
        DemoDataService.instance.signOut();
        throw RoleMismatchAuthException(
          message: "Role mismatch: Your authorized role is '${profile.role.toNameString()}', but you selected '${selectedRole.toNameString()}'.",
          selectedRole: selectedRole,
          actualRole: profile.role,
        );
      }

      if (profile == null) {
        throw Exception("Invalid credentials. Please verify your email and password.");
      }
      return profile;
    }

    // Supabase Authentication
    final authResponse = await _supabase!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception("Authentication failed. Invalid email or password.");
    }

    // Retrieve the user's actual profile and role from trusted database
    final profileResponse = await _supabase!
        .from('profiles')
        .select()
        .eq('id', authResponse.user!.id)
        .maybeSingle();

    if (profileResponse == null) {
      await signOut();
      throw Exception("User profile not found in system records.");
    }

    final userProfile = UserProfile.fromJson(profileResponse);

    if (!userProfile.active) {
      await signOut();
      throw Exception("Account has been deactivated. Please contact an Administrator.");
    }

    // Compare selected role with the authorized role
    if (userProfile.role != selectedRole) {
      await signOut();
      throw RoleMismatchAuthException(
        message: "Access Denied: Your account is registered as '${userProfile.role.toNameString()}', but you tried signing in as '${selectedRole.toNameString()}'.",
        selectedRole: selectedRole,
        actualRole: userProfile.role,
      );
    }

    return userProfile;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (SupabaseConfig.isDemoMode) return;
    await _supabase?.auth.resetPasswordForEmail(email.trim());
  }

  Future<UserProfile?> fetchCurrentUserProfile() async {
    if (DemoDataService.instance.currentDemoProfile != null) {
      return DemoDataService.instance.currentDemoProfile;
    }

    final user = currentUser;
    if (user == null || _supabase == null) return null;

    final response = await _supabase!
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<void> signOut() async {
    DemoDataService.instance.signOut();
    try {
      await _supabase?.auth.signOut();
    } catch (_) {}
  }
}
