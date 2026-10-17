import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/admin_analytics_service.dart';
import 'package:student_attendance_system/screens/admin/class_management_screen.dart';
import 'package:student_attendance_system/screens/admin/student_management_screen.dart';
import 'package:student_attendance_system/screens/admin/coordinator_assignment_screen.dart';
import 'package:student_attendance_system/screens/admin/whatsapp_settings_screen.dart';
import 'package:student_attendance_system/screens/admin/whatsapp_history_screen.dart';
import 'package:student_attendance_system/screens/auth/login_screen.dart';
import 'package:student_attendance_system/screens/profile/user_profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = AuthService();
  final _adminService = AdminService();
  final _analyticsService = AdminAnalyticsService();

  List<ClassModel> _allClasses = [];
  AdminAnalyticsData? _analytics;
  bool _isLoading = true;
  bool _isAnalyticsLoading = false;

  // Filters
  String _selectedAcademicYear = 'All';
  String _selectedDepartment = 'All';
  String _selectedClassId = 'All';
  String _selectedSession = 'All'; // 'All', 'Morning', 'Afternoon'
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final classes = await _adminService.getAllClasses();
    setState(() {
      _allClasses = classes;
      _isLoading = false;
    });
    await _refreshAnalytics();
  }

  Future<void> _refreshAnalytics() async {
    setState(() => _isAnalyticsLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final data = await _analyticsService.fetchAnalytics(
      academicYear: _selectedAcademicYear,
      department: _selectedDepartment,
      classId: _selectedClassId,
      date: dateStr,
      sessionFilter: _selectedSession,
    );
    if (mounted) {
      setState(() {
        _analytics = data;
        _isAnalyticsLoading = false;
      });
    }
  }

  List<String> get _academicYears {
    final set = _allClasses.map((c) => c.academicYear).toSet().toList();
    set.sort();
    return ['All', ...set];
  }

  List<String> get _departments {
    final set = _allClasses.map((c) => c.department).toSet().toList();
    set.sort();
    return ['All', ...set];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _refreshAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Administrator Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Analytics",
            onPressed: _refreshAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System Control Panel Header Card (Preserved from existing UI)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "System Control Panel",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Manage classes, students, coordinators, analytics & overall reports",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Analytics Filter Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text(
                              "Analytics Filters",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            // Date Picker Chip
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('dd MMM yyyy').format(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Dropdown Filters Row 1
                        Row(
                          children: [
                            Expanded(
                              child: _filterDropdown(
                                label: "Academic Year",
                                value: _selectedAcademicYear,
                                items: _academicYears,
                                onChanged: (v) {
                                  setState(() => _selectedAcademicYear = v!);
                                  _refreshAnalytics();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _filterDropdown(
                                label: "Department",
                                value: _selectedDepartment,
                                items: _departments,
                                onChanged: (v) {
                                  setState(() => _selectedDepartment = v!);
                                  _refreshAnalytics();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Dropdown Filters Row 2: Class & Session
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _filterDropdown(
                                label: "Class / Section",
                                value: _selectedClassId,
                                items: ['All', ..._allClasses.map((c) => c.id)],
                                itemLabel: (id) {
                                  if (id == 'All') return 'All College Classes';
                                  final match = _allClasses.firstWhere((c) => c.id == id, orElse: () => _allClasses.first);
                                  return match.className;
                                },
                                onChanged: (v) {
                                  setState(() => _selectedClassId = v!);
                                  _refreshAnalytics();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _filterDropdown(
                                label: "Session",
                                value: _selectedSession,
                                items: const ['All', 'Morning', 'Afternoon'],
                                onChanged: (v) {
                                  setState(() => _selectedSession = v!);
                                  _refreshAnalytics();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Analytics Metric Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Attendance Analytics",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_isAnalyticsLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 12 Metric Cards Responsive Grid
                  if (_analytics == null || (!_analytics!.hasRecords && _analytics!.totalStudents == 0))
                    _buildEmptyState()
                  else
                    _buildMetricsGrid(_analytics!),

                  const SizedBox(height: 28),
                  const Text(
                    "Administrative Operations",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Class-wise Student Management & Reporting
                  _adminOptionCard(
                    title: "Class & Student Management",
                    subtitle: "Class selection, student enrollment, daily status & Overall Report Generation",
                    icon: Icons.people_outline,
                    color: AppColors.present,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentManagementScreen()),
                      );
                      _refreshAnalytics();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Class Management
                  _adminOptionCard(
                    title: "Manage Classes",
                    subtitle: "Create, view, and configure department classes and academic years",
                    icon: Icons.class_outlined,
                    color: AppColors.primary,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClassManagementScreen()),
                      );
                      _loadInitialData();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Coordinator & Staff Assignment
                  _adminOptionCard(
                    title: "Assign Coordinators & Staff",
                    subtitle: "Link coordinators and report recipient staff to classes",
                    icon: Icons.assignment_ind_outlined,
                    color: AppColors.warning,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CoordinatorAssignmentScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // WhatsApp Notification Configuration
                  _adminOptionCard(
                    title: "WhatsApp Attendance Alerts Configuration",
                    subtitle: "Configure Meta Cloud API triggers, thresholds, window & recipients",
                    icon: Icons.chat_outlined,
                    color: const Color(0xFF075E54),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WhatsAppSettingsScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // WhatsApp Delivery Logs & History Monitor
                  _adminOptionCard(
                    title: "WhatsApp Delivery Logs & History",
                    subtitle: "Track queued, sent, delivered, and failed notifications & trigger summaries",
                    icon: Icons.mark_chat_read_outlined,
                    color: AppColors.primaryLight,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WhatsAppHistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.unmarked),
          const SizedBox(height: 12),
          const Text(
            "No Attendance Records Found",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            "No sessions or attendance records match the selected date (${DateFormat('dd MMM yyyy').format(_selectedDate)}) and filters.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(AdminAnalyticsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapt columns based on screen width
        final int crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            // 1. Total Students
            _metricCard(
              title: "Total Students",
              value: "${data.totalStudents}",
              icon: Icons.school_outlined,
              color: AppColors.primary,
            ),
            // 2. Morning Present
            _metricCard(
              title: "Morning Present",
              value: "${data.morningPresent}",
              icon: Icons.wb_sunny_outlined,
              color: AppColors.present,
            ),
            // 3. Morning Absent
            _metricCard(
              title: "Morning Absent",
              value: "${data.morningAbsent}",
              icon: Icons.close_outlined,
              color: AppColors.absent,
            ),
            // 4. Morning OD
            _metricCard(
              title: "Morning OD",
              value: "${data.morningOd}",
              icon: Icons.badge_outlined,
              color: AppColors.od,
            ),
            // 5. Afternoon Present
            _metricCard(
              title: "Afternoon Present",
              value: "${data.afternoonPresent}",
              icon: Icons.brightness_6_outlined,
              color: AppColors.present,
            ),
            // 6. Afternoon Absent
            _metricCard(
              title: "Afternoon Absent",
              value: "${data.afternoonAbsent}",
              icon: Icons.highlight_off_outlined,
              color: AppColors.absent,
            ),
            // 7. Afternoon OD
            _metricCard(
              title: "Afternoon OD",
              value: "${data.afternoonOd}",
              icon: Icons.verified_user_outlined,
              color: AppColors.od,
            ),
            // 8. Afternoon Bunk
            _metricCard(
              title: "Afternoon Bunk",
              value: "${data.afternoonBunk}",
              icon: Icons.directions_run_outlined,
              color: AppColors.bunk,
            ),
            // 9. Morning Attendance Percentage
            _metricCard(
              title: "Morning %",
              value: "${data.morningPercentage.toStringAsFixed(1)}%",
              icon: Icons.pie_chart_outline,
              color: AppColors.primaryLight,
            ),
            // 10. Afternoon Attendance Percentage
            _metricCard(
              title: "Afternoon %",
              value: "${data.afternoonPercentage.toStringAsFixed(1)}%",
              icon: Icons.donut_large_outlined,
              color: AppColors.primary,
            ),
            // 11. Students Present in Both Sessions
            _metricCard(
              title: "Present Both Sessions",
              value: "${data.studentsPresentBoth}",
              icon: Icons.check_circle_outline,
              color: AppColors.present,
            ),
            // 12. Students Present Morning but Absent Afternoon
            _metricCard(
              title: "Pres M. → Abs A.",
              value: "${data.studentsPresentMorningAbsentAfternoon}",
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    itemLabel != null ? itemLabel(item) : item,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _adminOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
