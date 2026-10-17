import 'package:flutter/material.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/services/admin_service.dart';

class CoordinatorAssignmentScreen extends StatefulWidget {
  const CoordinatorAssignmentScreen({super.key});

  @override
  State<CoordinatorAssignmentScreen> createState() => _CoordinatorAssignmentScreenState();
}

class _CoordinatorAssignmentScreenState extends State<CoordinatorAssignmentScreen> {
  final _adminService = AdminService();
  List<ClassModel> _classes = [];
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final classes = await _adminService.getAllClasses();
    final users = await _adminService.getAllUsers();
    setState(() {
      _classes = classes;
      _users = users;
      _isLoading = false;
    });
  }

  void _assignCoordinator(ClassModel cls) {
    final coordinators = _users.where((u) => u.role == UserRole.coordinator).toList();
    if (coordinators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No coordinator users available.")),
      );
      return;
    }

    UserProfile selectedUser = coordinators.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Assign Coordinator to ${cls.className}"),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButton<UserProfile>(
              value: selectedUser,
              isExpanded: true,
              items: coordinators.map((user) {
                return DropdownMenuItem(
                  value: user,
                  child: Text(user.fullName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setModalState(() => selectedUser = val);
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _adminService.assignCoordinatorToClass(
                classId: cls.id,
                coordinatorId: selectedUser.id,
              );
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${selectedUser.fullName} assigned to ${cls.className}")),
              );
            },
            child: const Text("Assign Coordinator"),
          ),
        ],
      ),
    );
  }

  void _assignStaff(ClassModel cls) {
    final staffList = _users.where((u) => u.role == UserRole.staff).toList();
    if (staffList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No staff users available.")),
      );
      return;
    }

    UserProfile selectedUser = staffList.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Assign Staff Recipient to ${cls.className}"),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButton<UserProfile>(
              value: selectedUser,
              isExpanded: true,
              items: staffList.map((user) {
                return DropdownMenuItem(
                  value: user,
                  child: Text(user.fullName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setModalState(() => selectedUser = val);
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _adminService.assignStaffToClass(
                classId: cls.id,
                staffId: selectedUser.id,
              );
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${selectedUser.fullName} assigned to ${cls.className}")),
              );
            },
            child: const Text("Assign Staff"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coordinator & Staff Assignments"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cls.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text("Assign Coordinator", style: TextStyle(fontSize: 12)),
                                onPressed: () => _assignCoordinator(cls),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.badge, size: 16),
                                label: const Text("Assign Staff", style: TextStyle(fontSize: 12)),
                                onPressed: () => _assignStaff(cls),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
