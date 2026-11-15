import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/individual_student_dialog.dart';

/// Month-wise Bunk Analysis View.
///
/// Features:
/// - Descending ranking of students with the highest bunk counts.
/// - Monthly bunk distribution bar chart (Jan-Dec).
/// - Month-to-month bunk changes (Delta comparison).
/// - Class and department context.
/// - Search and filter by student name / register number.
/// - Clickable rows to drill down into individual student analytics.
class BunkAnalysisView extends StatefulWidget {
  final List<BunkRankingItem> bunkRankings;
  final List<StudentPerformanceMetric> allStudents;
  final AnalyticsFilterState filter;

  const BunkAnalysisView({
    super.key,
    required this.bunkRankings,
    required this.allStudents,
    required this.filter,
  });

  @override
  State<BunkAnalysisView> createState() => _BunkAnalysisViewState();
}

class _BunkAnalysisViewState extends State<BunkAnalysisView> {
  String _searchQuery = '';

  static const List<String> _monthNames = [
    'All Year',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRankings = widget.bunkRankings.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.fullName.toLowerCase().contains(q) ||
          item.registerNumber.toLowerCase().contains(q) ||
          item.className.toLowerCase().contains(q);
    }).toList();

    final totalBunks = widget.bunkRankings.fold<int>(0, (sum, i) => sum + i.totalBunkCount);
    final topBunker = widget.bunkRankings.isNotEmpty ? widget.bunkRankings.first : null;

    // Monthly bunk aggregates for the bar chart
    final Map<int, int> monthlyTotals = {};
    for (int m = 1; m <= 12; m++) {
      int sum = 0;
      for (final item in widget.bunkRankings) {
        sum += item.monthlyBunkBreakdown[m] ?? 0;
      }
      monthlyTotals[m] = sum;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Summary Cards
          _buildSummaryCards(totalBunks, topBunker),

          const SizedBox(height: 16),

          // 2. Monthly Bunk Comparison Distribution Bar Chart
          _buildMonthlyBunkDistributionChart(monthlyTotals),

          const SizedBox(height: 16),

          // 3. Leaderboard Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header & Search Input
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bunk.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.directions_run, color: AppColors.bunk, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Student Bunk Leaderboard (Highest to Lowest)",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            "Showing ${filteredRankings.length} bunking students in ${widget.filter.department == 'All' ? 'all departments' : widget.filter.department}",
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Search input
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

                const Divider(height: 1, color: AppColors.border),

                // Table Rows
                if (filteredRankings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, color: AppColors.present.withValues(alpha: 0.8), size: 42),
                          const SizedBox(height: 10),
                          const Text(
                            "Zero Bunks Recorded",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "No attendance bunk records match the selected scope and filters.",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredRankings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = filteredRankings[index];
                      return _buildBunkRow(context, item);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int totalBunks, BunkRankingItem? topBunker) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 750;

        return Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: "Total Scope Bunks",
                value: "$totalBunks",
                subtitle: "Recorded session bunks",
                icon: Icons.directions_run,
                color: AppColors.bunk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                title: "Highest Bunk Record",
                value: topBunker != null ? "${topBunker.totalBunkCount} bunks" : "0",
                subtitle: topBunker != null ? "${topBunker.fullName} (${topBunker.className})" : "None",
                icon: Icons.warning_amber_outlined,
                color: const Color(0xFFD32F2F),
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _summaryCard(
                  title: "Students with Bunks",
                  value: "${widget.bunkRankings.length}",
                  subtitle: "Out of ${widget.allStudents.length} total enrolled",
                  icon: Icons.person_search_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
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
              color: color.withValues(alpha: 0.12),
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
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBunkDistributionChart(Map<int, int> monthlyTotals) {
    final maxMonthly = monthlyTotals.values.fold<int>(1, (max, v) => v > max ? v : max);

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
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 18, color: AppColors.bunk),
              const SizedBox(width: 8),
              const Text(
                "Month-to-Month Institutional Bunk Distribution (Jan - Dec)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                "Scope: ${widget.filter.department == 'All' ? 'All Departments' : widget.filter.department}",
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                final monthNum = index + 1;
                final count = monthlyTotals[monthNum] ?? 0;
                final heightFactor = maxMonthly > 0 ? (count / maxMonthly).clamp(0.04, 1.0) : 0.04;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "$count",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? AppColors.bunk : AppColors.textSecondary,
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
                                  color: count > 0 ? AppColors.bunk : Colors.grey.shade300,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _monthNames[monthNum],
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBunkRow(BuildContext context, BunkRankingItem item) {
    // Delta comparison with previous month
    final delta = item.monthToMonthDelta;
    Widget deltaWidget;
    if (delta > 0) {
      deltaWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward, size: 12, color: AppColors.absent),
          Text("+$delta", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.absent)),
        ],
      );
    } else if (delta < 0) {
      deltaWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_downward, size: 12, color: AppColors.present),
          Text("$delta", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.present)),
        ],
      );
    } else {
      deltaWidget = const Text("0 Δ", style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
    }

    return InkWell(
      onTap: () {
        // Find matching StudentPerformanceMetric
        final matched = widget.allStudents.where((s) => s.studentId == item.studentId);
        if (matched.isNotEmpty) {
          IndividualStudentDialog.show(
            context,
            student: matched.first,
            filter: widget.filter,
          );
        }
      },
      hoverColor: AppColors.primaryLight.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.rank <= 3 ? AppColors.bunk.withValues(alpha: 0.15) : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.rank <= 3 ? AppColors.bunk : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "#${item.rank}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: item.rank <= 3 ? AppColors.bunk : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Student Info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fullName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${item.registerNumber}  •  ${item.className} (${item.department})",
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Attendance % Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (item.attendancePercentage >= 75 ? AppColors.present : AppColors.absent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "${item.attendancePercentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: item.attendancePercentage >= 75 ? AppColors.present : AppColors.absent,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // MoM Delta
            SizedBox(
              width: 50,
              child: deltaWidget,
            ),
            const SizedBox(width: 12),

            // Total Bunk Count Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bunk.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bunk.withValues(alpha: 0.4)),
              ),
              child: Text(
                "${item.totalBunkCount} Bunks",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.bunk),
              ),
            ),
            const SizedBox(width: 10),

            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
