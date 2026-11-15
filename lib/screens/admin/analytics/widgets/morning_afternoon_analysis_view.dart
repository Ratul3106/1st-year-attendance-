import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/individual_student_dialog.dart';

/// Morning vs. Afternoon Session Discrepancy Analysis View.
///
/// Identifies students who regularly attend Morning sessions (8:15 - 8:45 AM)
/// but skip, bunk, or are absent during Afternoon sessions (12:20 - 12:50 PM).
class MorningAfternoonAnalysisView extends StatefulWidget {
  final List<SessionShiftDiscrepancy> discrepancies;
  final List<StudentPerformanceMetric> allStudents;
  final AnalyticsFilterState filter;

  const MorningAfternoonAnalysisView({
    super.key,
    required this.discrepancies,
    required this.allStudents,
    required this.filter,
  });

  @override
  State<MorningAfternoonAnalysisView> createState() =>
      _MorningAfternoonAnalysisViewState();
}

class _MorningAfternoonAnalysisViewState
    extends State<MorningAfternoonAnalysisView> {
  String _searchQuery = '';
  int _activeView = 0; // 0 = Students with shift gaps, 1 = Detailed incident log

  @override
  Widget build(BuildContext context) {
    // Filter students with shift discrepancies (morning attended but afternoon missed)
    final discrepantStudents = widget.allStudents
        .where((s) => s.afternoonShiftDiscrepancyCount > 0)
        .where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          s.registerNumber.toLowerCase().contains(q) ||
          s.className.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.afternoonShiftDiscrepancyCount.compareTo(a.afternoonShiftDiscrepancyCount));

    final totalIncidents = widget.discrepancies.length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Methodology Banner
          _buildMethodologyBanner(),

          const SizedBox(height: 16),

          // 2. Shift Discrepancy KPI Cards
          _buildKpiCards(discrepantStudents.length, totalIncidents),

          const SizedBox(height: 16),

          // 3. Tab/Switch between Aggregated Student Gap Roster and Incident Log
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_twilight, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                const Text(
                  "Session Shift Dropoff Analytics",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text("Student Discrepancy Roster", style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 1, label: Text("Incident Log", style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_activeView},
                  onSelectionChanged: (set) => setState(() => _activeView = set.first),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _activeView == 0
                        ? "Showing ${discrepantStudents.length} students with flagged afternoon attendance dropoffs"
                        : "Showing $totalIncidents recorded session shift discrepancy incidents",
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                SizedBox(
                  width: 240,
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search student...",
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. View Content
          if (_activeView == 0)
            _buildStudentDiscrepancyList(discrepantStudents)
          else
            _buildIncidentLogList(),
        ],
      ),
    );
  }

  Widget _buildMethodologyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.insights, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Session Shift Analysis compares same-day Morning (8:15 AM) and Afternoon (12:20 PM) attendance. "
              "Dates where either session was unconducted or open are strictly omitted to guarantee integrity.",
              style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(int studentCount, int totalIncidents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 700;

        return Row(
          children: [
            Expanded(
              child: _kpiCard(
                title: "Impacted Students",
                value: "$studentCount",
                subtitle: "Students with shift attendance gaps",
                color: Colors.orange.shade800,
                icon: Icons.people_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpiCard(
                title: "Total Shift Incidents",
                value: "$totalIncidents",
                subtitle: "Morning present / Afternoon missed",
                color: AppColors.bunk,
                icon: Icons.directions_run,
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  title: "Shift Discrepancy Rate",
                  value: widget.allStudents.isNotEmpty
                      ? "${((studentCount / widget.allStudents.length) * 100).toStringAsFixed(1)}%"
                      : "0%",
                  subtitle: "Percentage of enrolled scope",
                  color: AppColors.primary,
                  icon: Icons.pie_chart_outline,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDiscrepancyList(List<StudentPerformanceMetric> students) {
    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.present.withValues(alpha: 0.8), size: 40),
              const SizedBox(height: 10),
              const Text(
                "Zero Shift Discrepancies Flagged",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                "All students maintain consistent attendance between Morning and Afternoon shifts.",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final s = students[index];
          final gap = s.morningPercentage - s.afternoonPercentage;

          return InkWell(
            onTap: () {
              IndividualStudentDialog.show(
                context,
                student: s,
                filter: widget.filter,
              );
            },
            hoverColor: AppColors.primaryLight.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.orange.withValues(alpha: 0.12),
                    child: const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),

                  // Student Info
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.fullName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${s.registerNumber}  •  ${s.className} (${s.department})",
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Morning vs Afternoon Percentages
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Morning: ", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            "${s.morningPercentage.toStringAsFixed(1)}%",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.present),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Afternoon: ", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(
                            "${s.afternoonPercentage.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: s.afternoonPercentage >= 75 ? AppColors.present : AppColors.absent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Shift Gap Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.absent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "-${gap.toStringAsFixed(1)}% Gap",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.absent),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Discrepancy Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "${s.afternoonShiftDiscrepancyCount} Missed",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIncidentLogList() {
    final filteredIncidents = widget.discrepancies.where((d) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.studentName.toLowerCase().contains(q) ||
          d.registerNumber.toLowerCase().contains(q) ||
          d.className.toLowerCase().contains(q);
    }).toList();

    if (filteredIncidents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text("No incident records found.", style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredIncidents.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final inc = filteredIncidents[index];
          final formattedDate = DateFormat('dd MMM yyyy').format(inc.date);

          return ListTile(
            dense: true,
            leading: const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
            title: Text(
              "${inc.studentName} (${inc.registerNumber})",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "$formattedDate  •  ${inc.className} (${inc.department})  •  ${inc.discrepancyReason}",
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: inc.afternoonStatus == AttendanceStatus.bunk
                    ? AppColors.bunk.withValues(alpha: 0.12)
                    : AppColors.absent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                inc.afternoonStatus == AttendanceStatus.bunk ? "Bunked Afternoon" : "Absent Afternoon",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: inc.afternoonStatus == AttendanceStatus.bunk ? AppColors.bunk : AppColors.absent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
