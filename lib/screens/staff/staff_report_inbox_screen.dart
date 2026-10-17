import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/app_notification.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/services/notification_service.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/screens/staff/notification_detail_screen.dart';
import 'package:student_attendance_system/screens/staff/daily_report_detail_screen.dart';
import 'package:student_attendance_system/screens/profile/user_profile_screen.dart';
import 'package:student_attendance_system/screens/auth/login_screen.dart';

class StaffReportInboxScreen extends StatefulWidget {
  const StaffReportInboxScreen({super.key});

  @override
  State<StaffReportInboxScreen> createState() => _StaffReportInboxScreenState();
}

class _StaffReportInboxScreenState extends State<StaffReportInboxScreen> with SingleTickerProviderStateMixin {
  final _notificationService = NotificationService();
  final _authService = AuthService();

  late TabController _tabController;
  List<AppNotification> _notifications = [];
  List<DailyReport> _reports = [];
  List<ClassModel> _assignedClasses = [];
  bool _isLoading = true;

  String _searchClassQuery = '';
  DateTime _filterDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
    _notificationService.initializeFCM();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    final staffId = user?.id ?? 'demo-staff-id';

    final notifs = await _notificationService.getNotifications();
    final assigned = DemoDataService.instance.getAssignedClassesForStaff(staffId);
    final allReports = DemoDataService.instance.getAllReports();

    setState(() {
      _notifications = notifs;
      _assignedClasses = assigned;
      _reports = allReports;
      _isLoading = false;
    });
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _filterDate) {
      setState(() => _filterDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(
              icon: Icon(Icons.analytics_outlined),
              text: "Class Reports",
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text("$_unreadCount"),
                child: const Icon(Icons.notifications_outlined),
              ),
              text: "Report Inbox",
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _loadAllData,
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildClassReportsTab(),
                _buildNotificationsTab(),
              ],
            ),
    );
  }

  // --- Tab 1: Assigned Class Reports ---
  Widget _buildClassReportsTab() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_filterDate);

    // Filter reports for assigned classes and date
    final filtered = _reports.where((r) {
      final isAssigned = _assignedClasses.any((c) => c.id == r.classId);
      final matchesDate = r.attendanceDate == dateStr;
      final classObj = _assignedClasses.where((c) => c.id == r.classId).firstOrNull;
      final matchesName = classObj == null ||
          classObj.className.toLowerCase().contains(_searchClassQuery.toLowerCase()) ||
          classObj.department.toLowerCase().contains(_searchClassQuery.toLowerCase());

      return isAssigned && matchesDate && matchesName;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "Search class or department...",
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchClassQuery = v),
                    ),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(_filterDate),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Read-Only Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.infoLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Staff Role: Authorized to view reports, attendance statistics, and session shifts. Read-only access enforced.",
                      style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reports List
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined, size: 48, color: AppColors.unmarked),
                    const SizedBox(height: 12),
                    const Text(
                      "No Reports For Selected Date",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "No attendance reports recorded for ${DateFormat('dd MMMM yyyy').format(_filterDate)}.",
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map((report) {
                final cls = _assignedClasses.where((c) => c.id == report.classId).firstOrNull;
                final isFinal = report.reportType == 'final';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                cls?.displayName ?? 'Class Report',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFinal ? AppColors.presentLight : AppColors.warningLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isFinal ? "FINAL REPORT" : "PRELIMINARY (2:00 PM)",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isFinal ? AppColors.present : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(report.generatedAt)}",
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const Divider(height: 20),

                        // Stats Summary Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statMini("Enrolled", "${report.totalEnrolled}", AppColors.textPrimary),
                            _statMini("M. Present", "${report.morningPresent}", AppColors.present),
                            _statMini("M. %", "${report.morningPercentage.toStringAsFixed(0)}%", AppColors.primary),
                            _statMini("A. Present", "${report.afternoonPresent}", AppColors.present),
                            _statMini("A. %", "${report.afternoonPercentage.toStringAsFixed(0)}%", AppColors.primary),
                            _statMini("Shifts", "${report.discrepancies.length}", report.discrepancies.isNotEmpty ? AppColors.warning : AppColors.present),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text("View Full Report"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DailyReportDetailScreen(report: report),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statMini(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  // --- Tab 2: Notifications Tab ---
  Widget _buildNotificationsTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  "$_unreadCount unread report notification(s)",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: _notifications.isEmpty
                ? const Center(
                    child: Text(
                      "No notifications received yet.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return Card(
                        color: item.isRead ? Colors.white : AppColors.infoLight.withValues(alpha: 0.25),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.isRead ? Colors.grey.shade300 : AppColors.primary,
                            child: Icon(
                              Icons.assignment,
                              color: item.isRead ? Colors.grey.shade700 : Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () async {
                            if (!item.isRead) {
                              await _notificationService.markAsRead(item.id);
                            }
                            if (!mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationDetailScreen(notification: item),
                              ),
                            );
                            _loadAllData();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
