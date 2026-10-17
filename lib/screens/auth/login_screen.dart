import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/widgets/custom_button.dart';
import 'package:student_attendance_system/widgets/custom_text_field.dart';
import 'package:student_attendance_system/screens/auth/forgot_password_screen.dart';
import 'package:student_attendance_system/screens/coordinator/coordinator_dashboard.dart';
import 'package:student_attendance_system/screens/staff/staff_report_inbox_screen.dart';
import 'package:student_attendance_system/screens/admin/admin_dashboard.dart';
import 'package:student_attendance_system/models/user_profile.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: "coordinator@college.edu");
  final _passwordController = TextEditingController(text: "password123");
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  UserRole _selectedRole = UserRole.coordinator;
  bool _isObscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _authService.signInWithRole(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        selectedRole: _selectedRole,
      );

      if (!mounted) return;

      // Navigate strictly according to authenticated and verified database role
      Widget nextScreen;
      switch (profile.role) {
        case UserRole.admin:
          nextScreen = const AdminDashboard();
          break;
        case UserRole.staff:
          nextScreen = const StaffReportInboxScreen();
          break;
        case UserRole.coordinator:
          nextScreen = const CoordinatorDashboard();
          break;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } on RoleMismatchAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Header
                    Center(
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Student Attendance Management System",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Sign in with your credentials and authorized role",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role Selection Component
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                "Select Account Role",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _roleOptionChip(
                                label: "Admin",
                                role: UserRole.admin,
                                icon: Icons.admin_panel_settings,
                              ),
                              const SizedBox(width: 8),
                              _roleOptionChip(
                                label: "Coordinator",
                                role: UserRole.coordinator,
                                icon: Icons.assignment_ind,
                              ),
                              const SizedBox(width: 8),
                              _roleOptionChip(
                                label: "Staff",
                                role: UserRole.staff,
                                icon: Icons.people_alt,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Error Message Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.absentLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.absent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.absent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.absent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    CustomTextField(
                      controller: _emailController,
                      label: "Email Address",
                      hint: "coordinator@college.edu",
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Email is required";
                        if (!val.contains("@")) return "Enter a valid email address";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      controller: _passwordController,
                      label: "Password",
                      hint: "••••••••",
                      obscureText: _isObscure,
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Password is required";
                        return null;
                      },
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    CustomButton(
                      text: "Sign In as ${_selectedRole.toNameString()}",
                      isLoading: _isLoading,
                      onPressed: _login,
                    ),

                    const SizedBox(height: 24),

                    // Quick Demo Accounts Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Quick Demo Sign-In (1-Click)",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Select a profile below to populate matching credentials:",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _demoQuickButton(
                                  label: "Admin",
                                  icon: Icons.admin_panel_settings_outlined,
                                  email: "admin@college.edu",
                                  role: UserRole.admin,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _demoQuickButton(
                                  label: "Coordinator",
                                  icon: Icons.assignment_turned_in_outlined,
                                  email: "coordinator@college.edu",
                                  role: UserRole.coordinator,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _demoQuickButton(
                                  label: "Staff",
                                  icon: Icons.people_outline,
                                  email: "staff@college.edu",
                                  role: UserRole.staff,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Role Mismatch Test Hint
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Tip: Try selecting 'Admin' with coordinator credentials to test role mismatch rejection.",
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleOptionChip({
    required String label,
    required UserRole role,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRole = role;
            _errorMessage = null;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoQuickButton({
    required String label,
    required IconData icon,
    required String email,
    required UserRole role,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.primary.withValues(alpha: 0.04),
      ),
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                _emailController.text = email;
                _passwordController.text = "password123";
                _selectedRole = role;
                _errorMessage = null;
              });
              _login();
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
