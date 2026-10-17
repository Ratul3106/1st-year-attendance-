import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/widgets/custom_button.dart';
import 'package:student_attendance_system/widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      setState(() {
        _isError = true;
        _message = "Please enter a valid email address";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);
      setState(() {
        _isLoading = false;
        _isError = false;
        _message = "Password reset link sent! Check your email inbox.";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _message = "Failed to send reset link. Ensure the email is registered.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Forgot Your Password?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter your registered college email address and we'll send you a password reset link.",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            if (_message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? AppColors.absentLight : AppColors.presentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isError ? AppColors.absent : AppColors.present,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            CustomTextField(
              controller: _emailController,
              label: "Email Address",
              hint: "user@college.edu",
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            const SizedBox(height: 24),

            CustomButton(
              text: "Send Reset Link",
              isLoading: _isLoading,
              onPressed: _resetPassword,
            ),
          ],
        ),
      ),
    );
  }
}
