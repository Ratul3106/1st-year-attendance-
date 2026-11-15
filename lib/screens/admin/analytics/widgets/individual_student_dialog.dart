import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/services/advanced_analytics_service.dart';

/// Modal dialog displaying comprehensive individual student attendance analytics.
class IndividualStudentDialog extends StatefulWidget {
  final StudentPerformanceMetric student;
  final AnalyticsFilterState filter;

  const IndividualStudentDialog({
    super.key,
    required this.student,
    required this.filter,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentPerformanceMetric student,
    required AnalyticsFilterState filter,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => IndividualStudentDialog(
        student: student,
        filter: filter,
      ),
    );
  }

  @override
  State<IndividualStudentDialog> createState() => _IndividualStudentDialogState();
}

class _IndividualStudentDialogState extends State<IndividualStudentDialog> {
  IndividualStudentAnalytics? _analytics;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentDrilldown();
  }

  Future<void> _loadStudentDrilldown() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AdvancedAnalyticsService.instance.fetchIndividualStudentAnalytics(
        studentId: widget.student.studentId,
        filter: widget.filter,
        studentMetric: widget.student,
      );

      if (mounted) {
        setState(() {
          _analytics = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("[IndividualStudentDialog] Error loading drilldown: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load individual monthly trends: $e";
          _isLoading = false;
        });
      }
    }
  }

  Color _getRiskColor(AttendanceRiskLevel level) {
    switch (level) {
      case AttendanceRiskLevel.good:
        return AppColors.present;
      case AttendanceRiskLevel.warning:
        return AppColors.warning;
      case AttendanceRiskLevel.highRisk:
        return const Color(0xFFE65100);
      case AttendanceRiskLevel.critical:
        return AppColors.absent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Dialog Header with student identity & risk chip
            _buildDialogHeader(s),

            const Divider(height: 1, color: AppColors.border),

            // 2. Dialog Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text("Aggregating historical monthly trends...",
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.absent, size: 36),
                                const SizedBox(height: 12),
                                Text(_errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.absent, fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadStudentDrilldown,
                                  child: const Text("Retry"),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 3. Primary KPI Summary Cards
                              _buildKpiSummary(s),

                              const SizedBox(height: 18),

                              // 4. Trend Direction & Highlight Banner
                              if (_analytics != null) ...[
                                _buildTrendBanner(_analytics!),
                                const SizedBox(height: 18),
                              ],

                              // 5. Monthly Attendance Percentage Bar Chart
                              if (_analytics != null && _analytics!.monthlyTrends.isNotEmpty) ...[
                                _buildMonthlyAttendanceChart(_analytics!.monthlyTrends),
                                const SizedBox(height: 18),
                                _buildMonthlyBunkTrendChart(_analytics!.monthlyTrends),
                                const SizedBox(height: 18),
                              ],

                              // 6. Morning vs Afternoon Breakdown
                              _buildMorningAfternoonBreakdown(s),
                            ],
                          ),
                        ),
            ),

            // 7. Dialog Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(StudentPerformanceMetric s) {
    final riskColor = _getRiskColor(s.riskLevel);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        s.riskLevel.label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: riskColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Reg No: ${s.registerNumber}  •  Class: ${s.className} (${s.department})",
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummary(StudentPerformanceMetric s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return GridView.count(
          crossAxisCount: isNarrow ? 3 : 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isNarrow ? 1.4 : 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _miniKpi(
              title: "Overall %",
              value: "${s.attendancePercentage.toStringAsFixed(1)}%",
              color: s.attendancePercentage >= 75 ? AppColors.present : AppColors.absent,
              icon: Icons.percent,
            ),
            _miniKpi(
              title: "Strict % (No OD)",
              value: "${s.strictAttendancePercentage.toStringAsFixed(1)}%",
              color: s.strictAttendancePercentage >= 75 ? AppColors.present : AppColors.warning,
              icon: Icons.security,
            ),
            _miniKpi(
              title: "Conducted",
              value: "${s.totalConductedSessions}",
              color: AppColors.primary,
              icon: Icons.calendar_today,
            ),
            _miniKpi(
              title: "Present",
              value: "${s.presentCount}",
              color: AppColors.present,
              icon: Icons.check_circle_outline,
            ),
            _miniKpi(
              title: "Absent",
              value: "${s.absentCount}",
              color: AppColors.absent,
              icon: Icons.cancel_outlined,
            ),
            _miniKpi(
              title: "Bunks",
              value: "${s.bunkCount}",
              color: AppColors.bunk,
              icon: Icons.directions_run,
            ),
          ],
        );
      },
    );
  }

  Widget _miniKpi({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBanner(IndividualStudentAnalytics analytics) {
    IconData trendIcon;
    Color trendColor;
    String trendText;

    if (analytics.trendDirection == AttendanceTrendDirection.improving) {
      trendIcon = Icons.trending_up;
      trendColor = AppColors.present;
      trendText = "Attendance is Improving across recent months";
    } else if (analytics.trendDirection == AttendanceTrendDirection.declining) {
      trendIcon = Icons.trending_down;
      trendColor = AppColors.absent;
      trendText = "Attendance is Declining — Intervention Recommended";
    } else {
      trendIcon = Icons.trending_flat;
      trendColor = AppColors.primary;
      trendText = "Attendance is Stable across recorded months";
    }

    final highestStr = analytics.highestAttendanceMonth != null
        ? "${analytics.highestAttendanceMonth!.monthLabel} (${analytics.highestAttendanceMonth!.attendancePercentage.toStringAsFixed(1)}%)"
        : "N/A";
    final lowestStr = analytics.lowestAttendanceMonth != null
        ? "${analytics.lowestAttendanceMonth!.monthLabel} (${analytics.lowestAttendanceMonth!.attendancePercentage.toStringAsFixed(1)}%)"
        : "N/A";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: trendColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(trendIcon, color: trendColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trendText,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: trendColor),
                ),
                const SizedBox(height: 2),
                Text(
                  "Highest: $highestStr  •  Lowest: $lowestStr",
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAttendanceChart(List<MonthlyStudentTrend> trends) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.bar_chart, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                "Monthly Attendance Percentage (Annual Trajectory)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Spacer(),
              Text(
                "75% Benchmark Target",
                style: TextStyle(fontSize: 11, color: AppColors.present, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart Graphic
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trends.map((t) {
                final pct = t.attendancePercentage;
                final heightFactor = (pct / 100.0).clamp(0.05, 1.0);
                final barColor = pct >= 75.0
                    ? AppColors.present
                    : (pct >= 65.0 ? AppColors.warning : AppColors.absent);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "${pct.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.monthLabel.substring(0, t.monthLabel.length >= 3 ? 3 : t.monthLabel.length),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBunkTrendChart(List<MonthlyStudentTrend> trends) {
    final maxBunks = trends.fold<int>(1, (max, t) => t.bunkCount > max ? t.bunkCount : max);

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.directions_run, size: 18, color: AppColors.bunk),
              SizedBox(width: 8),
              Text(
                "Month-wise Bunk Count Distribution",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trends.map((t) {
                final heightFactor = maxBunks > 0 ? (t.bunkCount / maxBunks).clamp(0.04, 1.0) : 0.04;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "${t.bunkCount}",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: t.bunkCount > 0 ? AppColors.bunk : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: t.bunkCount > 0 ? AppColors.bunk : Colors.grey.shade300,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.monthLabel.substring(0, t.monthLabel.length >= 3 ? 3 : t.monthLabel.length),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMorningAfternoonBreakdown(StudentPerformanceMetric s) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.schedule, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                "Morning vs. Afternoon Session Performance",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _sessionComparisonCard(
                  sessionName: "Morning Shift (8:15 - 8:45)",
                  percentage: s.morningPercentage,
                  conducted: s.morningConducted,
                  present: s.morningPresent,
                  absent: s.morningAbsent,
                  od: s.morningOd,
                  bunks: s.morningBunk,
                  icon: Icons.wb_sunny_outlined,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _sessionComparisonCard(
                  sessionName: "Afternoon Shift (12:20 - 12:50)",
                  percentage: s.afternoonPercentage,
                  conducted: s.afternoonConducted,
                  present: s.afternoonPresent,
                  absent: s.afternoonAbsent,
                  od: s.afternoonOd,
                  bunks: s.afternoonBunk,
                  icon: Icons.nightlight_round_outlined,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          if (s.afternoonShiftDiscrepancyCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bunk.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.bunk.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: AppColors.bunk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Shift Discrepancy Alert: Student attended morning session but missed/bunked afternoon session ${s.afternoonShiftDiscrepancyCount} time(s).",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.bunk),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionComparisonCard({
    required String sessionName,
    required double percentage,
    required int conducted,
    required int present,
    required int absent,
    required int od,
    required int bunks,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sessionName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Text(
                "${percentage.toStringAsFixed(1)}%",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Conducted: $conducted  •  Present: $present  •  Absent: $absent  •  OD: $od  •  Bunks: $bunks",
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
