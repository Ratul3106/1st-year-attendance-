import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/advanced_analytics_service.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/analytics_filter_bar.dart';
import 'package:student_attendance_system/widgets/college_logo.dart';
import 'package:student_attendance_system/screens/auth/login_screen.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/screens/profile/user_profile_screen.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/bunk_analysis_view.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/all_students_performance_view.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/department_class_comparison_view.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/morning_afternoon_analysis_view.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/calendar_heatmap_view.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/analytics_export_dialog.dart';

/// Comprehensive Advanced Attendance Analytics & Reports Dashboard Screen.
///
/// Provides deep monthly, department-wise, class-wise, session-wise and individual student
/// analytical insights with interactive filters, KPI metrics cards, and sub-view navigations.
class AdvancedAnalyticsDashboardScreen extends StatefulWidget {
  const AdvancedAnalyticsDashboardScreen({super.key});

  @override
  State<AdvancedAnalyticsDashboardScreen> createState() =>
      _AdvancedAnalyticsDashboardScreenState();
}

class _AdvancedAnalyticsDashboardScreenState
    extends State<AdvancedAnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  final _analyticsService = AdvancedAnalyticsService.instance;
  final _authService = AuthService();

  late TabController _tabController;

  AnalyticsFilterState _filterState = AnalyticsFilterState.initial();
  List<ClassModel> _allClasses = [];
  AdvancedAnalyticsResult? _analyticsResult;

  bool _isInitialLoading = true;
  bool _isDataLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadInitialMetadataAndAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMetadataAndAnalytics() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
    });

    try {
      final classes = await _adminService.getAllClasses();
      _allClasses = classes;

      // Determine initial academic year from classes if available
      String initialYear = _filterState.academicYear;
      if (classes.isNotEmpty && initialYear == 'All') {
        initialYear = classes.first.academicYear;
      }

      _filterState = _filterState.copyWith(academicYear: initialYear);

      await _executeAnalyticsQuery(forceRefresh: false);
    } catch (e) {
      debugPrint("[AdvancedAnalytics] Initialization error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load classes or initial analytics: $e";
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _executeAnalyticsQuery({bool forceRefresh = false}) async {
    setState(() {
      _isDataLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _analyticsService.fetchAnalytics(
        _filterState,
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _analyticsResult = result;
          _isInitialLoading = false;
          _isDataLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[AdvancedAnalytics] Query execution error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error querying analytics: $e";
          _isInitialLoading = false;
          _isDataLoading = false;
        });
      }
    }
  }

  void _onFilterChanged(AnalyticsFilterState newFilter) {
    setState(() => _filterState = newFilter);
    _executeAnalyticsQuery(forceRefresh: false);
  }

  void _onResetFilters() {
    setState(() {
      _filterState = AnalyticsFilterState.initial();
    });
    _executeAnalyticsQuery(forceRefresh: true);
  }

  void _onRefreshAnalytics() {
    _analyticsService.invalidateCache();
    _executeAnalyticsQuery(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CollegeLogo(height: 36),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                "Advanced Attendance Analytics & Reports",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: (_analyticsResult == null || _isDataLoading)
                ? null
                : () {
                    AnalyticsExportDialog.show(
                      context,
                      data: _analyticsResult!,
                      filter: _filterState,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text("Export Reports", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Analytics",
            onPressed: _isDataLoading ? null : _onRefreshAnalytics,
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
              await _authService.signOut();
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
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Interactive Analytics Filter Bar
                  AnalyticsFilterBar(
                    filterState: _filterState,
                    allClasses: _allClasses,
                    onFilterChanged: _onFilterChanged,
                    onRefresh: _onRefreshAnalytics,
                    onReset: _onResetFilters,
                    isLoading: _isDataLoading,
                  ),

                  const SizedBox(height: 16),

                  // 2. Error Banner (if any)
                  if (_errorMessage != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 16),
                  ],

                  // 3. Calculation Methodology & Guardrail Banner
                  _buildMethodologyBanner(),

                  const SizedBox(height: 16),

                  // 4. Primary Monthly Attendance Overview KPI Cards
                  if (_analyticsResult != null) ...[
                    _buildOverviewCardsSection(_analyticsResult!.overview),
                    const SizedBox(height: 20),
                    _buildBenchmarkCardsSection(_analyticsResult!.overview),
                  ],

                  const SizedBox(height: 24),

                  // 5. Module Navigation Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: "Overview & Health"),
                        Tab(icon: Icon(Icons.warning_amber_outlined, size: 18), text: "Bunk Analysis"),
                        Tab(icon: Icon(Icons.people_outline, size: 18), text: "Students Performance"),
                        Tab(icon: Icon(Icons.compare_arrows_outlined, size: 18), text: "Dept & Class Comparison"),
                        Tab(icon: Icon(Icons.wb_sunny_outlined, size: 18), text: "Morning vs Afternoon"),
                        Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: "Calendar Heatmap"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. Tab Content Container
                  SizedBox(
                    height: 680,
                    child: _analyticsResult == null
                        ? _buildEmptyState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTabContent(),
                              BunkAnalysisView(
                                bunkRankings: _analyticsResult!.bunkRankings,
                                allStudents: _analyticsResult!.studentPerformanceList,
                                filter: _filterState,
                              ),
                              AllStudentsPerformanceView(
                                students: _analyticsResult!.studentPerformanceList,
                                filter: _filterState,
                              ),
                              DepartmentClassComparisonView(
                                departmentComparisons: _analyticsResult!.departmentComparisons,
                                classComparisons: _analyticsResult!.classComparisons,
                                filter: _filterState,
                              ),
                              MorningAfternoonAnalysisView(
                                discrepancies: _analyticsResult!.shiftDiscrepancies,
                                allStudents: _analyticsResult!.studentPerformanceList,
                                filter: _filterState,
                              ),
                              CalendarHeatmapView(
                                heatmapData: _analyticsResult!.calendarHeatmap,
                                filter: _filterState,
                                onMonthChanged: (m) => _onFilterChanged(_filterState.copyWith(month: m)),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.absentLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.absent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.absent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.absent, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: _onRefreshAnalytics,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.absent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text("Retry", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodologyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, color: AppColors.primary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Institutional Calculation Methodology: Attendance % = ((Present + OD) / Conducted Sessions) × 100. "
              "Only finalized/closed sessions are evaluated. Missing student records in conducted sessions are counted as unmarked, strictly penalizing the percentage.",
              style: TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCardsSection(MonthlyAttendanceOverviewData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 950;
        final isTablet = constraints.maxWidth > 650;
        final crossAxisCount = isDesktop ? 5 : (isTablet ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _kpiCard(
              title: "Enrolled Students",
              value: "${data.totalEnrolledStudents}",
              icon: Icons.school_outlined,
              color: AppColors.primary,
              subtitle: "In selected scope",
            ),
            _kpiCard(
              title: "Average Attendance",
              value: "${data.averageAttendancePercentage.toStringAsFixed(1)}%",
              icon: Icons.pie_chart_outline,
              color: data.averageAttendancePercentage >= 75.0 ? AppColors.present : AppColors.warning,
              subtitle: "Conducted: ${data.totalConductedSessions} sess",
            ),
            _kpiCard(
              title: "Total Present",
              value: "${data.totalPresentRecords}",
              icon: Icons.check_circle_outline,
              color: AppColors.present,
              subtitle: "Attended sessions",
            ),
            _kpiCard(
              title: "Total Absent",
              value: "${data.totalAbsentRecords}",
              icon: Icons.close_outlined,
              color: AppColors.absent,
              subtitle: "Unauthorized absence",
            ),
            _kpiCard(
              title: "Total OD (On Duty)",
              value: "${data.totalOdRecords}",
              icon: Icons.badge_outlined,
              color: AppColors.od,
              subtitle: "Institutional leave",
            ),
            _kpiCard(
              title: "Total Bunks",
              value: "${data.totalBunkRecords}",
              icon: Icons.directions_run_outlined,
              color: AppColors.bunk,
              subtitle: "Recorded session bunks",
            ),
            _kpiCard(
              title: "Good Standing (≥75%)",
              value: "${data.studentsGoodStandingCount}",
              icon: Icons.verified_user_outlined,
              color: AppColors.present,
              subtitle: "Safe attendance",
            ),
            _kpiCard(
              title: "Warning (65-75%)",
              value: "${data.studentsBelow75Count}",
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              subtitle: "Below threshold",
            ),
            _kpiCard(
              title: "High Risk (50-65%)",
              value: "${data.studentsBelow65Count}",
              icon: Icons.error_outline,
              color: const Color(0xFFE65100),
              subtitle: "Intervention needed",
            ),
            _kpiCard(
              title: "Critical (<50%)",
              value: "${data.studentsBelow50Count}",
              icon: Icons.dangerous_outlined,
              color: AppColors.absent,
              subtitle: "Severe attendance risk",
            ),
          ],
        );
      },
    );
  }

  Widget _buildBenchmarkCardsSection(MonthlyAttendanceOverviewData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 850;

        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                child: _benchmarkCard(
                  title: "Highest Attendance Class",
                  mainText: data.highestAttendanceClassName,
                  badgeText: "${data.highestAttendanceClassPercentage.toStringAsFixed(1)}%",
                  icon: Icons.emoji_events_outlined,
                  color: AppColors.present,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _benchmarkCard(
                  title: "Lowest Attendance Class",
                  mainText: data.lowestAttendanceClassName,
                  badgeText: "${data.lowestAttendanceClassPercentage.toStringAsFixed(1)}%",
                  icon: Icons.trending_down_outlined,
                  color: AppColors.absent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _benchmarkCard(
                  title: "Highest Bunk Count Class",
                  mainText: data.highestBunkClassName,
                  badgeText: "${data.highestBunkCount} bunks",
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.bunk,
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _benchmarkCard(
                title: "Highest Attendance Class",
                mainText: data.highestAttendanceClassName,
                badgeText: "${data.highestAttendanceClassPercentage.toStringAsFixed(1)}%",
                icon: Icons.emoji_events_outlined,
                color: AppColors.present,
              ),
              const SizedBox(height: 10),
              _benchmarkCard(
                title: "Lowest Attendance Class",
                mainText: data.lowestAttendanceClassName,
                badgeText: "${data.lowestAttendanceClassPercentage.toStringAsFixed(1)}%",
                icon: Icons.trending_down_outlined,
                color: AppColors.absent,
              ),
              const SizedBox(height: 10),
              _benchmarkCard(
                title: "Highest Bunk Count Class",
                mainText: data.highestBunkClassName,
                badgeText: "${data.highestBunkCount} bunks",
                icon: Icons.warning_amber_rounded,
                color: AppColors.bunk,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _benchmarkCard({
    required String title,
    required String mainText,
    required String badgeText,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  mainText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              badgeText,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTabContent() {
    final ov = _analyticsResult?.overview;
    if (ov == null || ov.totalEnrolledStudents == 0) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Attendance Risk Distribution & Health Summary",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            "Categorization of students across official accreditation compliance thresholds",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Visual Progress Distribution Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  if (ov.studentsGoodStandingCount > 0)
                    Expanded(
                      flex: ov.studentsGoodStandingCount,
                      child: Container(
                        color: AppColors.present,
                        alignment: Alignment.center,
                        child: Text(
                          "${ov.studentsGoodStandingCount}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (ov.studentsBelow75Count > 0)
                    Expanded(
                      flex: ov.studentsBelow75Count,
                      child: Container(
                        color: AppColors.warning,
                        alignment: Alignment.center,
                        child: Text(
                          "${ov.studentsBelow75Count}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (ov.studentsBelow65Count > 0)
                    Expanded(
                      flex: ov.studentsBelow65Count,
                      child: Container(
                        color: const Color(0xFFE65100),
                        alignment: Alignment.center,
                        child: Text(
                          "${ov.studentsBelow65Count}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (ov.studentsBelow50Count > 0)
                    Expanded(
                      flex: ov.studentsBelow50Count,
                      child: Container(
                        color: AppColors.absent,
                        alignment: Alignment.center,
                        child: Text(
                          "${ov.studentsBelow50Count}",
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem("Good Standing (≥75%)", AppColors.present, ov.studentsGoodStandingCount),
              _legendItem("Warning (65-75%)", AppColors.warning, ov.studentsBelow75Count),
              _legendItem("High Risk (50-65%)", const Color(0xFFE65100), ov.studentsBelow65Count),
              _legendItem("Critical (<50%)", AppColors.absent, ov.studentsBelow50Count),
            ],
          ),

          const Spacer(),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Filter Applied: ${_filterState.department} • ${_filterState.academicYear} • ${_filterState.month != null ? DateFormat('MMMM').format(DateTime(2026, _filterState.month!)) : 'All Months'} ${_filterState.year}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Text(
                "Last Refreshed: ${DateFormat('hh:mm a').format(_analyticsResult?.computedAt ?? DateTime.now())}",
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        Text(
          "$count students",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 54, color: AppColors.unmarked),
          const SizedBox(height: 12),
          const Text(
            "No Conducted Attendance Sessions Found",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            "No closed attendance sessions match the selected academic year, department, class, or month filter.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _onResetFilters,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text("Reset All Filters"),
          ),
        ],
      ),
    );
  }
}
