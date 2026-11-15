import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';

/// Department & Class Attendance Comparison View.
///
/// Compares:
/// - Cross-departmental averages (CSE vs ECE vs MECH, etc.)
/// - Class / Section performance within selected departments
/// - Total Bunks per department / class
/// - At-Risk students below 75%, High Risk, and Critical counts
class DepartmentClassComparisonView extends StatefulWidget {
  final List<DepartmentComparisonMetric> departmentComparisons;
  final List<ClassComparisonMetric> classComparisons;
  final AnalyticsFilterState filter;

  const DepartmentClassComparisonView({
    super.key,
    required this.departmentComparisons,
    required this.classComparisons,
    required this.filter,
  });

  @override
  State<DepartmentClassComparisonView> createState() =>
      _DepartmentClassComparisonViewState();
}

class _DepartmentClassComparisonViewState
    extends State<DepartmentClassComparisonView> {
  int _activeViewIndex = 0; // 0 = Department Comparison, 1 = Class Comparison

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. View Switcher Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  "Institutional Benchmark Comparison",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                // Toggle Button
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text("Department View", style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 1, label: Text("Class / Section View", style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_activeViewIndex},
                  onSelectionChanged: (set) {
                    setState(() => _activeViewIndex = set.first);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_activeViewIndex == 0)
            _buildDepartmentComparisonSection()
          else
            _buildClassComparisonSection(),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // DEPARTMENT COMPARISON SECTION
  // ----------------------------------------------------
  Widget _buildDepartmentComparisonSection() {
    if (widget.departmentComparisons.isEmpty) {
      return _emptyComparisonCard("No department comparison data available for current filters.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Visual Comparison Bars: Attendance %
        _buildAttendanceComparisonBars(
          title: "Department-wise Average Attendance %",
          subtitle: "Target Benchmark: 75% Minimum Mandatory Institutional Attendance",
          items: widget.departmentComparisons.map((d) {
            return _ComparisonBarItem(
              label: d.departmentName,
              value: d.averageAttendancePercentage,
              displayValue: "${d.averageAttendancePercentage.toStringAsFixed(1)}%",
              isPercentage: true,
              color: d.averageAttendancePercentage >= 75 ? AppColors.present : AppColors.absent,
              subtext: "${d.totalEnrolledStudents} students",
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Visual Comparison Bars: Bunks
        _buildAttendanceComparisonBars(
          title: "Department-wise Total Bunk Records",
          subtitle: "Recorded session bunks per academic department",
          items: widget.departmentComparisons.map((d) {
            return _ComparisonBarItem(
              label: d.departmentName,
              value: d.totalBunk.toDouble(),
              displayValue: "${d.totalBunk} bunks",
              isPercentage: false,
              color: AppColors.bunk,
              subtext: "${d.studentsBelow75} below 75%",
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Breakdown Table
        _buildDepartmentTable(),
      ],
    );
  }

  Widget _buildDepartmentTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Department Comparative Metrics Summary",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Total Students", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Avg Attendance %", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Total Bunks", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("< 75% Warning", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("< 65% High Risk", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("< 50% Critical", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: widget.departmentComparisons.map((d) {
                return DataRow(cells: [
                  DataCell(Text(d.departmentName, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text("${d.totalEnrolledStudents}")),
                  DataCell(Text(
                    "${d.averageAttendancePercentage.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: d.averageAttendancePercentage >= 75 ? AppColors.present : AppColors.absent,
                    ),
                  )),
                  DataCell(Text("${d.totalBunk}", style: const TextStyle(color: AppColors.bunk, fontWeight: FontWeight.w600))),
                  DataCell(Text("${d.studentsBelow75}", style: const TextStyle(color: AppColors.warning))),
                  DataCell(Text("${d.studentsBelow65}", style: const TextStyle(color: Color(0xFFE65100)))),
                  DataCell(Text("${d.studentsBelow50}", style: const TextStyle(color: AppColors.absent, fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CLASS COMPARISON SECTION
  // ----------------------------------------------------
  Widget _buildClassComparisonSection() {
    if (widget.classComparisons.isEmpty) {
      return _emptyComparisonCard("No class comparison data available for current filters.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Class Attendance Comparison Bars
        _buildAttendanceComparisonBars(
          title: "Class / Section Average Attendance %",
          subtitle: "Comparing class sections in selected scope",
          items: widget.classComparisons.map((c) {
            return _ComparisonBarItem(
              label: c.className,
              value: c.averageAttendancePercentage,
              displayValue: "${c.averageAttendancePercentage.toStringAsFixed(1)}%",
              isPercentage: true,
              color: c.averageAttendancePercentage >= 75 ? AppColors.present : AppColors.absent,
              subtext: "${c.totalEnrolledStudents} students (${c.department})",
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Class Bunk & Risk Breakdown Table
        _buildClassTable(),
      ],
    );
  }

  Widget _buildClassTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Class / Section Performance Breakdown",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text("Class Name", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Enrolled", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Avg %", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Bunk Count", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("< 75% Warning", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("< 65% High Risk", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("< 50% Critical", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: widget.classComparisons.map((c) {
                return DataRow(cells: [
                  DataCell(Text(c.className, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(c.department)),
                  DataCell(Text("${c.totalEnrolledStudents}")),
                  DataCell(Text(
                    "${c.averageAttendancePercentage.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: c.averageAttendancePercentage >= 75 ? AppColors.present : AppColors.absent,
                    ),
                  )),
                  DataCell(Text("${c.totalBunk}", style: const TextStyle(color: AppColors.bunk, fontWeight: FontWeight.w600))),
                  DataCell(Text("${c.studentsBelow75}", style: const TextStyle(color: AppColors.warning))),
                  DataCell(Text("${c.studentsBelow65}", style: const TextStyle(color: Color(0xFFE65100)))),
                  DataCell(Text("${c.studentsBelow50}", style: const TextStyle(color: AppColors.absent, fontWeight: FontWeight.bold))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget: Visual Comparison Horizontal Bars
  Widget _buildAttendanceComparisonBars({
    required String title,
    required String subtitle,
    required List<_ComparisonBarItem> items,
  }) {
    final maxValue = items.fold<double>(
      100.0,
      (max, i) => i.value > max ? i.value : max,
    );

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
              const Icon(Icons.bar_chart, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final widthFactor = maxValue > 0 ? (item.value / maxValue).clamp(0.02, 1.0) : 0.02;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.subtext,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        item.displayValue,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      // Base track
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                      ),
                      // Progress fill
                      FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyComparisonCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ComparisonBarItem {
  final String label;
  final double value;
  final String displayValue;
  final bool isPercentage;
  final Color color;
  final String subtext;

  _ComparisonBarItem({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.isPercentage,
    required this.color,
    required this.subtext,
  });
}
