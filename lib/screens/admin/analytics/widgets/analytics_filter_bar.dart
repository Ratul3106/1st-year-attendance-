import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/class_model.dart';

/// Interactive, responsive analytics filter bar.
///
/// Features dynamic cascading:
/// - Selecting a Department automatically updates the available Classes.
/// - Selecting an Academic Year filters the classes and reset orphan selection.
/// - Allows choosing Month, Year, Session (Morning/Afternoon/Both), Status, and Custom Date Range.
/// - Provides 1-click Reset Filters and Refresh Analytics triggers.
class AnalyticsFilterBar extends StatelessWidget {
  final AnalyticsFilterState filterState;
  final List<ClassModel> allClasses;
  final ValueChanged<AnalyticsFilterState> onFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onReset;
  final bool isLoading;

  const AnalyticsFilterBar({
    super.key,
    required this.filterState,
    required this.allClasses,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onReset,
    this.isLoading = false,
  });

  List<String> get _academicYears {
    final set = allClasses.map((c) => c.academicYear).where((y) => y.isNotEmpty).toSet().toList()..sort();
    return ['All', ...set];
  }

  List<String> get _departments {
    final set = allClasses.map((c) => c.department).where((d) => d.isNotEmpty).toSet().toList()..sort();
    return ['All', ...set];
  }

  /// Classes filtered dynamically based on current Academic Year and Department selections
  List<ClassModel> get _filteredClasses {
    return allClasses.where((c) {
      if (filterState.academicYear != 'All' && c.academicYear != filterState.academicYear) {
        return false;
      }
      if (filterState.department != 'All' && c.department != filterState.department) {
        return false;
      }
      return true;
    }).toList();
  }

  static const List<String> _months = [
    'All Months',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<int> _years = [2024, 2025, 2026, 2027, 2028];

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: (filterState.customStartDate != null && filterState.customEndDate != null)
          ? DateTimeRange(start: filterState.customStartDate!, end: filterState.customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onFilterChanged(filterState.copyWith(
        customStartDate: picked.start,
        customEndDate: picked.end,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableClasses = _filteredClasses;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Header with Reset & Refresh
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Analytics & Filter Engine",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    "Filter historical and live attendance records across multiple institutional dimensions",
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              // Reset Filters Button
              TextButton.icon(
                onPressed: isLoading ? null : onReset,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text("Reset Filters", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 6),
              // Refresh Analytics Button
              ElevatedButton.icon(
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: const Text("Refresh Analytics", style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Row 1: Academic Year, Department, Class/Section
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(child: _buildAcademicYearDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDepartmentDropdown()),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildClassDropdown(availableClasses)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildAcademicYearDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: _buildDepartmentDropdown()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildClassDropdown(availableClasses),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 12),

          // Row 2: Month, Year, Session, Status, and Date Range Chip
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              if (isDesktop) {
                return Row(
                  children: [
                    Expanded(child: _buildMonthDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: _buildYearDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSessionDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatusDropdown()),
                    const SizedBox(width: 10),
                    _buildDateRangeButton(context),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMonthDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: _buildYearDropdown()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildSessionDropdown()),
                        const SizedBox(width: 10),
                        Expanded(child: _buildStatusDropdown()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDateRangeButton(context),
                  ],
                );
              }
            },
          ),

          // Active Custom Date Range Indicator (if applied)
          if (filterState.customStartDate != null && filterState.customEndDate != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    "Custom Range Active: ${DateFormat('dd MMM yyyy').format(filterState.customStartDate!)} - ${DateFormat('dd MMM yyyy').format(filterState.customEndDate!)}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => onFilterChanged(filterState.copyWith(clearDateRange: true)),
                    child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcademicYearDropdown() {
    return _filterField(
      label: "Academic Year",
      value: filterState.academicYear,
      items: _academicYears,
      itemLabel: (y) => y == 'All' ? 'All Academic Years' : y,
      onChanged: (val) {
        if (val != null) {
          onFilterChanged(filterState.copyWith(
            academicYear: val,
            // Reset classId if not valid in the selected academic year
            classId: 'All',
          ));
        }
      },
    );
  }

  Widget _buildDepartmentDropdown() {
    return _filterField(
      label: "Department",
      value: filterState.department,
      items: _departments,
      itemLabel: (d) => d == 'All' ? 'All Departments' : d,
      onChanged: (val) {
        if (val != null) {
          onFilterChanged(filterState.copyWith(
            department: val,
            // Dynamic Cascading: Reset classId to 'All' when department switches
            classId: 'All',
          ));
        }
      },
    );
  }

  Widget _buildClassDropdown(List<ClassModel> availableClasses) {
    final items = ['All', ...availableClasses.map((c) => c.id)];
    final currentVal = items.contains(filterState.classId) ? filterState.classId : 'All';

    return _filterField(
      label: "Class / Section",
      value: currentVal,
      items: items,
      itemLabel: (id) {
        if (id == 'All') {
          return filterState.department == 'All'
              ? 'All Classes (All Departments)'
              : 'All ${filterState.department} Classes';
        }
        final match = availableClasses.where((c) => c.id == id);
        return match.isNotEmpty ? match.first.className : id;
      },
      onChanged: (val) {
        if (val != null) {
          onFilterChanged(filterState.copyWith(classId: val));
        }
      },
    );
  }

  Widget _buildMonthDropdown() {
    final currentMonthStr = filterState.month == null
        ? 'All Months'
        : _months[filterState.month!];

    return _filterField(
      label: "Month",
      value: currentMonthStr,
      items: _months,
      onChanged: (val) {
        if (val != null) {
          if (val == 'All Months') {
            onFilterChanged(filterState.copyWith(clearMonth: true));
          } else {
            final idx = _months.indexOf(val);
            if (idx > 0) {
              onFilterChanged(filterState.copyWith(month: idx));
            }
          }
        }
      },
    );
  }

  Widget _buildYearDropdown() {
    return _filterField(
      label: "Year",
      value: filterState.year.toString(),
      items: _years.map((y) => y.toString()).toList(),
      onChanged: (val) {
        if (val != null) {
          final parsed = int.tryParse(val);
          if (parsed != null) {
            onFilterChanged(filterState.copyWith(year: parsed));
          }
        }
      },
    );
  }

  Widget _buildSessionDropdown() {
    return _filterField(
      label: "Session",
      value: filterState.sessionFilter,
      items: const ['Both', 'Morning', 'Afternoon'],
      itemLabel: (s) => s == 'Both' ? 'Both Sessions' : '$s Only',
      onChanged: (val) {
        if (val != null) {
          onFilterChanged(filterState.copyWith(sessionFilter: val));
        }
      },
    );
  }

  Widget _buildStatusDropdown() {
    return _filterField(
      label: "Attendance Status",
      value: filterState.statusFilter,
      items: const ['All', 'Present', 'Absent', 'OD', 'Bunk'],
      itemLabel: (s) => s == 'All' ? 'All Statuses' : s,
      onChanged: (val) {
        if (val != null) {
          onFilterChanged(filterState.copyWith(statusFilter: val));
        }
      },
    );
  }

  Widget _buildDateRangeButton(BuildContext context) {
    final isCustomActive = filterState.customStartDate != null && filterState.customEndDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Custom Range",
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _pickDateRange(context),
          icon: Icon(
            Icons.date_range,
            size: 14,
            color: isCustomActive ? AppColors.primary : AppColors.textSecondary,
          ),
          label: Text(
            isCustomActive
                ? "${DateFormat('dd/MM').format(filterState.customStartDate!)} - ${DateFormat('dd/MM').format(filterState.customEndDate!)}"
                : "Pick Dates",
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCustomActive ? FontWeight.bold : FontWeight.normal,
              color: isCustomActive ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: isCustomActive ? AppColors.primaryLight.withValues(alpha: 0.08) : AppColors.background,
            side: BorderSide(
              color: isCustomActive ? AppColors.primary : AppColors.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _filterField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemLabel,
  }) {
    final safeValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
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
}
