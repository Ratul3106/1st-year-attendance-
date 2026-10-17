import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/core/theme/app_theme.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/screens/auth/login_screen.dart';
import 'package:student_attendance_system/screens/coordinator/coordinator_dashboard.dart';
import 'package:student_attendance_system/screens/staff/staff_report_inbox_screen.dart';
import 'package:student_attendance_system/screens/admin/admin_dashboard.dart';
import 'package:student_attendance_system/models/user_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase safely
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint("Supabase initialization note: $e");
  }

  // Initialize Firebase safely if configuration exists
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization note: $e");
  }

  runApp(const StudentAttendanceApp());
}

class StudentAttendanceApp extends StatelessWidget {
  const StudentAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;
  Widget _homeScreen = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _homeScreen = const LoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      final profile = await _authService.fetchCurrentUserProfile();
      if (profile != null && profile.active) {
        switch (profile.role) {
          case UserRole.admin:
            _homeScreen = const AdminDashboard();
            break;
          case UserRole.staff:
            _homeScreen = const StaffReportInboxScreen();
            break;
          case UserRole.coordinator:
            _homeScreen = const CoordinatorDashboard();
            break;
        }
      } else {
        await _authService.signOut();
        _homeScreen = const LoginScreen();
      }
    } catch (e) {
      _homeScreen = const LoginScreen();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _homeScreen;
  }
}
