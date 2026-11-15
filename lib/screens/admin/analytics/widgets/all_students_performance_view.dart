import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/individual_student_dialog.dart';

enum StudentSortColumn {
  attendancePercentage,
  name,
  bunkCount,
  absentCount,
}

/// All Students Performance Roster with Search, Multi-column Sorting, and Pagination.
class AllStudentsPerformanceView extends StatefulWidget {
  final List<StudentPerformanceMetric> students;
  final AnalyticsFilterState filter;

  const AllStudentsPerformanceView({
    super.key,
    required this.students,
    required this.filter,
  });

  @override
  State<AllStudentsPerformanceView> createState() => _AllStudentsPerformanceViewState();
}

class _AllStudentsPerformanceViewState extends State<AllStudentsPerformanceView> {
  String _searchQuery = '';
  StudentSortColumn _sortColumn = StudentSortColumn.attendancePercentage;
  bool _sortAscending = false;
  AttendanceRiskLevel? _riskFilter; // null means All

  int _currentPage = 1;
  int _pageSize = 15;

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

  List<StudentPerformanceMetric> _getFilteredAndSortedStudents() {
    var list = widget.students.where((s) {
      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = s.fullName.toLowerCase().contains(q) ||
            s.registerNumber.toLowerCase().contains(q) ||
            s.className.toLowerCase().contains(q);
        if (!matches) return false;
      }

      // Risk level filter
      if (_riskFilter != null && s.riskLevel != _riskFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case StudentSortColumn.name:
          cmp = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          break;
        case StudentSortColumn.attendancePercentage:
          cmp = a.attendancePercentage.compareTo(b.attendancePercentage);
          break;
        case StudentSortColumn.bunkCount:
          cmp = a.bunkCount.compareTo(b.bunkCount);
          break;
        case StudentSortColumn.absentCount:
          cmp = a.absentCount.compareTo(b.absentCount);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final processedList = _getFilteredAndSortedStudents();
    final totalCount = processedList.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 9999);

    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalCount);
    final pageStudents = totalCount > 0 ? processedList.sublist(startIndex, endIndex) : <StudentPerformanceMetric>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Controls Header: Search, Risk Filter Chips, Sort Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.people_outline, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "All Students Attendance Performance Roster",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          "Total Enrolled in Scope: ${widget.students.length} students  •  Displaying $totalCount matching",
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Search bar
                    SizedBox(
                      width: 240,
                      height: 36,
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                            _currentPage = 1;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Search name, register no...",
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
                const SizedBox(height: 12),
                // Risk filter chips & Sort dropdown row
                Row(
                  children: [
                    const Text("Filter Risk: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(width: 4),
                    _riskChip(label: "All", level: null),
                    const SizedBox(width: 6),
                    _riskChip(label: "Good (≥75%)", level: AttendanceRiskLevel.good),
                    const SizedBox(width: 6),
                    _riskChip(label: "Warning (65-75%)", level: AttendanceRiskLevel.warning),
                    const SizedBox(width: 6),
                    _riskChip(label: "High Risk (50-65%)", level: AttendanceRiskLevel.highRisk),
                    const SizedBox(width: 6),
                    _riskChip(label: "Critical (<50%)", level: AttendanceRiskLevel.critical),
                    const Spacer(),
                    // Sort options
                    const Text("Sort By: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    _buildSortDropdown(),
                    IconButton(
                      icon: Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      tooltip: _sortAscending ? "Ascending" : "Descending",
                      onPressed: () => setState(() => _sortAscending = !_sortAscending),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // 2. Data Table
          if (pageStudents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      "No students match the criteria",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                horizontalMargin: 16,
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text("Rank", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Student Name", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Register No", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Class / Sec", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Dept", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Conducted", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Present", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Absent", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("OD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Bunk", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Unmarked", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Attendance %", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Risk Tier", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                ],
                rows: pageStudents.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  final rankNum = startIndex + idx + 1;
                  final riskColor = _getRiskColor(s.riskLevel);

                  return DataRow(
                    onSelectChanged: (_) {
                      IndividualStudentDialog.show(
                        context,
                        student: s,
                        filter: widget.filter,
                      );
                    },
                    cells: [
                      DataCell(Text("#$rankNum", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(s.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      DataCell(Text(s.registerNumber, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(s.className, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(s.department, style: const TextStyle(fontSize: 12))),
                      DataCell(Text("${s.totalConductedSessions}", style: const TextStyle(fontSize: 12))),
                      DataCell(Text("${s.presentCount}", style: const TextStyle(fontSize: 12, color: AppColors.present, fontWeight: FontWeight.w600))),
                      DataCell(Text("${s.absentCount}", style: const TextStyle(fontSize: 12, color: AppColors.absent, fontWeight: FontWeight.w600))),
                      DataCell(Text("${s.odCount}", style: const TextStyle(fontSize: 12, color: AppColors.od))),
                      DataCell(Text("${s.bunkCount}", style: const TextStyle(fontSize: 12, color: AppColors.bunk, fontWeight: FontWeight.w600))),
                      DataCell(Text("${s.unmarkedCount}", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                      DataCell(
                        Text(
                          "${s.attendancePercentage.toStringAsFixed(1)}%",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: riskColor),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            s.riskLevel.label,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: riskColor),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

          const Divider(height: 1, color: AppColors.border),

          // 3. Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  "Showing ${totalCount == 0 ? 0 : startIndex + 1} to $endIndex of $totalCount students",
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                const Text("Page Size: ", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                DropdownButton<int>(
                  value: _pageSize,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  items: const [10, 15, 25, 50].map((sz) {
                    return DropdownMenuItem<int>(value: sz, child: Text("$sz"));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                Text(
                  "$_currentPage / $totalPages",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskChip({required String label, required AttendanceRiskLevel? level}) {
    final isSelected = _riskFilter == level;
    final color = level != null ? _getRiskColor(level) : AppColors.primary;

    return InkWell(
      onTap: () {
        setState(() {
          _riskFilter = level;
          _currentPage = 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StudentSortColumn>(
          value: _sortColumn,
          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: StudentSortColumn.attendancePercentage, child: Text("Attendance %")),
            DropdownMenuItem(value: StudentSortColumn.name, child: Text("Student Name")),
            DropdownMenuItem(value: StudentSortColumn.bunkCount, child: Text("Bunk Count")),
            DropdownMenuItem(value: StudentSortColumn.absentCount, child: Text("Absence Count")),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _sortColumn = val;
                // If sorting by Attendance %, default ascending = false (highest first)
                if (val == StudentSortColumn.attendancePercentage ||
                    val == StudentSortColumn.bunkCount ||
                    val == StudentSortColumn.absentCount) {
                  _sortAscending = false;
                } else {
                  _sortAscending = true;
                }
              });
            }
          },
        ),
      ),
    );
  }
}
