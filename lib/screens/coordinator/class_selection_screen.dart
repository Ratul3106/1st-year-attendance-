import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/attendance_service.dart';
import 'package:student_attendance_system/services/auth_service.dart';

class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  final _attendanceService = AttendanceService();
  final _authService = AuthService();
  List<ClassModel> _assignedClasses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    if (user != null) {
      final classes = await _attendanceService.getAssignedClassesForCoordinator(user.id);
      setState(() {
        _assignedClasses = classes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assigned Classes"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedClasses.isEmpty
              ? const Center(child: Text("No classes assigned."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignedClasses.length,
                  itemBuilder: (context, index) {
                    final cls = _assignedClasses[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(Icons.class_, color: Colors.white),
                        ),
                        title: Text(cls.className, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${cls.department} • ${cls.academicYear}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context, cls);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
