import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/widgets/custom_text_field.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/screens/profile/user_profile_screen.dart';
import 'package:student_attendance_system/screens/auth/login_screen.dart';
import 'package:student_attendance_system/widgets/college_logo.dart';

class CoordinatorAssignmentScreen extends StatefulWidget {
  const CoordinatorAssignmentScreen({super.key});

  @override
  State<CoordinatorAssignmentScreen> createState() =>
      _CoordinatorAssignmentScreenState();
}

class _CoordinatorAssignmentScreenState
    extends State<CoordinatorAssignmentScreen> {
  final _adminService = AdminService();

  List<ClassModel> _classes = [];
  List<UserProfile> _allUsers = [];
  final Map<String, List<UserProfile>> _classCoordinators = {};
  final Map<String, List<UserProfile>> _classStaff = {};
  bool _isLoading = true;

  final _coordEmailController = TextEditingController();
  final _coordNameController = TextEditingController();
  final _staffEmailController = TextEditingController();
  final _staffNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _coordEmailController.dispose();
    _coordNameController.dispose();
    _staffEmailController.dispose();
    _staffNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      List<ClassModel> classes = await _adminService.getAllClasses();
      if (!mounted) return;

      if (classes.isEmpty) {
        await _adminService.seedSampleDataIfEmpty();
        classes = await _adminService.getAllClasses();
        if (!mounted) return;
      }

      final users = await _adminService.getAllUsers();

      final Map<String, List<UserProfile>> coords = {};
      final Map<String, List<UserProfile>> staff = {};

      for (final cls in classes) {
        coords[cls.id] = await _adminService.getAssignedCoordinators(cls.id);
        staff[cls.id] = await _adminService.getAssignedStaff(cls.id);
      }

      if (mounted) {
        setState(() {
          _classes = classes;
          _allUsers = users;
          _classCoordinators.clear();
          _classCoordinators.addAll(coords);
          _classStaff.clear();
          _classStaff.addAll(staff);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading assignments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAssignCoordinatorDialog(ClassModel cls) {
    _coordEmailController.clear();
    _coordNameController.clear();
    UserProfile? selectedExistingUser;

    final existingCoords = _allUsers
        .where((u) => u.role == UserRole.coordinator && u.active)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.assignment_ind_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Assign Coordinator to ${cls.className}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Only authorized coordinators can log in and mark attendance for students in this class.",
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Option A: Add Coordinator by Email",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _coordEmailController,
                      label: "Coordinator Email Address",
                      hint: "e.g. coordinator@college.edu",
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: _coordNameController,
                      label: "Coordinator Full Name (Optional)",
                      hint: "e.g. Prof. Priya Nair",
                    ),
                    if (existingCoords.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("OR",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Option B: Select Registered Coordinator",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserProfile?>(
                        initialValue: selectedExistingUser,
                        decoration: const InputDecoration(
                          labelText: "Select Coordinator",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<UserProfile?>(
                            value: null,
                            child: Text("Select an existing coordinator..."),
                          ),
                          ...existingCoords.map((u) {
                            return DropdownMenuItem<UserProfile?>(
                              value: u,
                              child: Text(
                                "${u.fullName} (${u.email ?? 'No email'})",
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedExistingUser = val;
                            if (val != null) {
                              _coordEmailController.text = val.email ?? '';
                              _coordNameController.text = val.fullName;
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text("Authorize & Assign"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () async {
                  final email = _coordEmailController.text.trim();
                  final name = _coordNameController.text.trim();

                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid email address."),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);

                  try {
                    await _adminService.assignCoordinatorByEmail(
                      classId: cls.id,
                      email: email,
                      fullName: name.isNotEmpty ? name : null,
                    );
                    await _loadData();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Coordinator access granted to '$email' for ${cls.className}!"),
                          backgroundColor: AppColors.present,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Error assigning coordinator: $e")),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignStaffDialog(ClassModel cls) {
    _staffEmailController.clear();
    _staffNameController.clear();
    UserProfile? selectedExistingUser;

    final existingStaff =
        _allUsers.where((u) => u.role == UserRole.staff && u.active).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Assign Staff to ${cls.className}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Assigned staff will receive attendance notifications, summaries, and can inspect reports.",
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Option A: Add Staff by Email",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _staffEmailController,
                      label: "Staff Member Email Address",
                      hint: "e.g. staff@college.edu",
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      controller: _staffNameController,
                      label: "Staff Full Name (Optional)",
                      hint: "e.g. Prof. Amit Patel (HOD)",
                    ),
                    if (existingStaff.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("OR",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Option B: Select Registered Staff",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<UserProfile?>(
                        initialValue: selectedExistingUser,
                        decoration: const InputDecoration(
                          labelText: "Select Staff Member",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<UserProfile?>(
                            value: null,
                            child: Text("Select an existing staff member..."),
                          ),
                          ...existingStaff.map((u) {
                            return DropdownMenuItem<UserProfile?>(
                              value: u,
                              child: Text(
                                "${u.fullName} (${u.email ?? 'No email'})",
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedExistingUser = val;
                            if (val != null) {
                              _staffEmailController.text = val.email ?? '';
                              _staffNameController.text = val.fullName;
                            }
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text("Authorize & Assign"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  final email = _staffEmailController.text.trim();
                  final name = _staffNameController.text.trim();

                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid email address."),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);

                  try {
                    await _adminService.assignStaffByEmail(
                      classId: cls.id,
                      email: email,
                      fullName: name.isNotEmpty ? name : null,
                    );
                    await _loadData();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "Staff access granted to '$email' for ${cls.className}!"),
                          backgroundColor: AppColors.present,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error assigning staff: $e")),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmRevokeCoordinator(ClassModel cls, UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revoke Coordinator Access"),
        content: Text(
            "Are you sure you want to remove coordinator access for '${user.fullName}' from ${cls.className}? They will no longer be authorized to mark attendance for this class."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              await _adminService.removeCoordinatorFromClass(
                classId: cls.id,
                coordinatorId: user.id,
              );
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Revoked coordinator access for ${user.fullName} from ${cls.className}"),
                  ),
                );
              }
            },
            child: const Text("Revoke Access"),
          ),
        ],
      ),
    );
  }

  void _confirmRevokeStaff(ClassModel cls, UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Revoke Staff Access"),
        content: Text(
            "Are you sure you want to remove staff access for '${user.fullName}' from ${cls.className}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.absent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              await _adminService.removeStaffFromClass(
                classId: cls.id,
                staffId: user.id,
              );
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        "Revoked staff access for ${user.fullName} from ${cls.className}"),
                  ),
                );
              }
            },
            child: const Text("Revoke Access"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CollegeLogo(height: 34),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                "Assign Coordinators & Staff",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Assignments",
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: "User Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(28),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_outlined, size: 48, color: AppColors.primary),
                        const SizedBox(height: 14),
                        const Text(
                          "No Classes Registered",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Classes must be created in Class & Student Management before assigning coordinators and staff.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text("Refresh Classes"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final cls = _classes[index];
                    final coords = _classCoordinators[cls.id] ?? [];
                    final staffList = _classStaff[cls.id] ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Class Title & Meta
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  child: const Icon(Icons.school,
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cls.className,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        "${cls.department} • Academic Year ${cls.academicYear}",
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 24),

                            // Coordinators Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified_user_outlined,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Authorized Coordinators (${coords.length})",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1,
                                      size: 14),
                                  label: const Text("Assign Coordinator",
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () =>
                                      _showAssignCoordinatorDialog(cls),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (coords.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "No coordinator assigned. Students cannot be marked for attendance until you assign a coordinator by email.",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: coords.map((u) {
                                  return Chip(
                                    avatar: const CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Icon(Icons.person,
                                          color: Colors.white, size: 12),
                                    ),
                                    label: Text(
                                      "${u.fullName}${u.email != null ? ' • ${u.email}' : ''}",
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    deleteIcon: const Icon(Icons.close,
                                        size: 14, color: AppColors.absent),
                                    onDeleted: () =>
                                        _confirmRevokeCoordinator(cls, u),
                                    backgroundColor: AppColors.primaryLight
                                        .withValues(alpha: 0.1),
                                    side: BorderSide(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.2)),
                                  );
                                }).toList(),
                              ),

                            const SizedBox(height: 16),

                            // Staff Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.badge_outlined,
                                        size: 16, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Report Recipient Staff (${staffList.length})",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.badge, size: 14),
                                  label: const Text("Assign Staff",
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.warning,
                                    side: const BorderSide(
                                        color: AppColors.warning),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _showAssignStaffDialog(cls),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (staffList.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "No staff member assigned to receive attendance reports for this class.",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: staffList.map((u) {
                                  return Chip(
                                    avatar: const CircleAvatar(
                                      backgroundColor: AppColors.warning,
                                      child: Icon(Icons.badge,
                                          color: Colors.white, size: 12),
                                    ),
                                    label: Text(
                                      "${u.fullName}${u.email != null ? ' • ${u.email}' : ''}",
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    deleteIcon: const Icon(Icons.close,
                                        size: 14, color: AppColors.absent),
                                    onDeleted: () =>
                                        _confirmRevokeStaff(cls, u),
                                    backgroundColor: AppColors.warning
                                        .withValues(alpha: 0.1),
                                    side: BorderSide(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.2)),
                                  );
                                }).toList(),
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
