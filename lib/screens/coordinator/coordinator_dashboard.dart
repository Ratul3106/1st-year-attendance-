import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/services/attendance_service.dart';
import 'package:student_attendance_system/services/report_service.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/screens/coordinator/morning_attendance_screen.dart';
import 'package:student_attendance_system/screens/coordinator/afternoon_attendance_screen.dart';
import 'package:student_attendance_system/screens/coordinator/attendance_summary_screen.dart';
import 'package:student_attendance_system/screens/auth/login_screen.dart';
import 'package:student_attendance_system/screens/profile/user_profile_screen.dart';

class CoordinatorDashboard extends StatefulWidget {
  const CoordinatorDashboard({super.key});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  final _attendanceService = AttendanceService();
  final _reportService = ReportService();
  final _authService = AuthService();

  List<ClassModel> _assignedClasses = [];
  ClassModel? _selectedClass;
  List<Student> _enrolledStudents = [];
  DailyReport? _todayReport;

  int _morningMarked = 0;
  int _afternoonMarked = 0;

  bool _isLoading = true;
  final String _todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadAssignedClasses();
  }

  Future<void> _loadAssignedClasses() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final classes = await _attendanceService.getAssignedClassesForCoordinator(user.id);
        setState(() {
          _assignedClasses = classes;
          if (classes.isNotEmpty) {
            _selectedClass = classes.first;
          }
        });

        if (_selectedClass != null) {
          await _loadClassSessionData(_selectedClass!);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClassSessionData(ClassModel cls) async {
    try {
      final students = await _attendanceService.getEnrolledStudents(cls.id);

      final mSess = await _attendanceService.getOrCreateSession(
        classId: cls.id,
        date: _todayDate,
        sessionType: SessionType.morning,
      );
      final mRecords = await _attendanceService.getSessionRecords(mSess.id);

      final aSess = await _attendanceService.getOrCreateSession(
        classId: cls.id,
        date: _todayDate,
        sessionType: SessionType.afternoon,
      );
      final aRecords = await _attendanceService.getSessionRecords(aSess.id);

      final report = await _reportService.getDailyReport(
        classId: cls.id,
        date: _todayDate,
      );

      setState(() {
        _enrolledStudents = students;
        _morningMarked = mRecords.length;
        _afternoonMarked = aRecords.length;
        _todayReport = report;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _getSessionStatus(int marked, int total) {
    if (total == 0 || marked == 0) return "Not Started";
    if (marked < total) return "In Progress ($marked/$total)";
    return "Completed ($marked/$total)";
  }

  Color _getSessionStatusColor(int marked, int total) {
    if (total == 0 || marked == 0) return AppColors.unmarked;
    if (marked < total) return AppColors.warning;
    return AppColors.present;
  }

  @override
  Widget build(BuildContext context) {
    final total = _enrolledStudents.length;
    final mUnmarked = total - _morningMarked;
    final aUnmarked = total - _afternoonMarked;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Coordinator Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Session Data",
            onPressed: () {
              if (_selectedClass != null) {
                _loadClassSessionData(_selectedClass!);
              }
            },
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
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Selection Dropdown Header
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
                        const Text(
                          "Select Active Assigned Class",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _assignedClasses.isEmpty
                            ? const Text(
                                "No classes assigned yet. Contact Administrator.",
                                style: TextStyle(color: AppColors.absent),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<ClassModel>(
                                  value: _selectedClass,
                                  isExpanded: true,
                                  items: _assignedClasses.map((cls) {
                                    return DropdownMenuItem(
                                      value: cls,
                                      child: Text(
                                        cls.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newCls) {
                                    if (newCls != null) {
                                      setState(() {
                                        _selectedClass = newCls;
                                        _isLoading = true;
                                      });
                                      _loadClassSessionData(newCls);
                                    }
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Today's Date & Class Status Banner
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
                            const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Date: ${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (_todayReport?.reportType == 'final')
                                    ? AppColors.presentLight
                                    : AppColors.warningLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _todayReport != null
                                    ? "${_todayReport!.reportType.toUpperCase()} REPORT"
                                    : "REPORT PENDING",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (_todayReport?.reportType == 'final')
                                      ? AppColors.present
                                      : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppColors.border),
                        // Class Information Detail Strip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _infoSubColumn("Total Enrolled", "$total Students"),
                            _infoSubColumn("Department", _selectedClass?.department ?? 'N/A'),
                            _infoSubColumn("Academic Year", _selectedClass?.academicYear ?? 'N/A'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "Attendance Sessions & Status",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Morning Session Button Card
                  _buildSessionCard(
                    title: "Morning Attendance",
                    subtitle: "Allowed Statuses: Present, Absent, OD",
                    statusLabel: _getSessionStatus(_morningMarked, total),
                    statusColor: _getSessionStatusColor(_morningMarked, total),
                    markedCount: _morningMarked,
                    unmarkedCount: mUnmarked > 0 ? mUnmarked : 0,
                    icon: Icons.wb_sunny_outlined,
                    color: Colors.amber.shade700,
                    onTap: _selectedClass == null
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MorningAttendanceScreen(
                                  selectedClass: _selectedClass!,
                                  date: _todayDate,
                                ),
                              ),
                            );
                            if (mounted && _selectedClass != null) {
                              _loadClassSessionData(_selectedClass!);
                            }
                          },
                  ),

                  const SizedBox(height: 12),

                  // Afternoon Session Button Card
                  _buildSessionCard(
                    title: "Afternoon Attendance",
                    subtitle: "Allowed Statuses: Present, Absent, OD, Bunk",
                    statusLabel: _getSessionStatus(_afternoonMarked, total),
                    statusColor: _getSessionStatusColor(_afternoonMarked, total),
                    markedCount: _afternoonMarked,
                    unmarkedCount: aUnmarked > 0 ? aUnmarked : 0,
                    icon: Icons.brightness_6_outlined,
                    color: Colors.purple.shade700,
                    onTap: _selectedClass == null
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AfternoonAttendanceScreen(
                                  selectedClass: _selectedClass!,
                                  date: _todayDate,
                                ),
                              ),
                            );
                            if (mounted && _selectedClass != null) {
                              _loadClassSessionData(_selectedClass!);
                            }
                          },
                  ),

                  const SizedBox(height: 12),

                  // Attendance Summary Card
                  _buildSummaryCard(
                    title: "Today's Attendance Summary",
                    subtitle: "Session comparisons, discrepancy alerts & final report",
                    icon: Icons.analytics_outlined,
                    color: AppColors.primary,
                    report: _todayReport,
                    onTap: _selectedClass == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AttendanceSummaryScreen(
                                  selectedClass: _selectedClass!,
                                  date: _todayDate,
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoSubColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildSessionCard({
    required String title,
    required String subtitle,
    required String statusLabel,
    required Color statusColor,
    required int markedCount,
    required int unmarkedCount,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Marked Students: $markedCount",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      unmarkedCount > 0 ? "Unmarked: $unmarkedCount" : "All Marked",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: unmarkedCount > 0 ? AppColors.warning : AppColors.present,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required DailyReport? report,
    VoidCallback? onTap,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (report != null) ...[
              const SizedBox(height: 6),
              Text(
                "Both Present: ${report.bothPresent} | Both Absent: ${report.bothAbsent} | Discrepancies: ${report.discrepancies.length}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
