import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/widgets/custom_text_field.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final _adminService = AdminService();
  List<ClassModel> _classes = [];
  bool _isLoading = true;

  final _classNameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _yearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    final classes = await _adminService.getAllClasses();
    setState(() {
      _classes = classes;
      _isLoading = false;
    });
  }

  void _showAddClassDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Class"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: _classNameController,
              label: "Class Name",
              hint: "CSE-A",
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _departmentController,
              label: "Department",
              hint: "Computer Science",
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _yearController,
              label: "Academic Year",
              hint: "2025-2026",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_classNameController.text.isNotEmpty &&
                  _departmentController.text.isNotEmpty) {
                await _adminService.createClass(
                  className: _classNameController.text.trim(),
                  department: _departmentController.text.trim(),
                  academicYear: _yearController.text.trim(),
                );
                _classNameController.clear();
                _departmentController.clear();
                _yearController.clear();
                if (mounted) Navigator.pop(ctx);
                _loadClasses();
              }
            },
            child: const Text("Create Class"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Classes"),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddClassDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? const Center(child: Text("No classes created yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final cls = _classes[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(Icons.class_, color: Colors.white),
                        ),
                        title: Text(cls.className, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${cls.department} • ${cls.academicYear}'),
                      ),
                    );
                  },
                ),
    );
  }
}
