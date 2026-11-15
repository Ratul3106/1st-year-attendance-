import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';

/// Calendar-style Monthly Attendance Heatmap View.
///
/// Each calendar day tile displays:
/// - Conducted sessions count
/// - Present, Absent, OD, Bunk counts
/// - Attendance %
/// - Color-coded intensity level (0-4)
/// - Tap to view complete single-day breakdown.
class CalendarHeatmapView extends StatefulWidget {
  final List<DayHeatmapData> heatmapData;
  final AnalyticsFilterState filter;
  final ValueChanged<int>? onMonthChanged;

  const CalendarHeatmapView({
    super.key,
    required this.heatmapData,
    required this.filter,
    this.onMonthChanged,
  });

  @override
  State<CalendarHeatmapView> createState() => _CalendarHeatmapViewState();
}

class _CalendarHeatmapViewState extends State<CalendarHeatmapView> {
  DayHeatmapData? _selectedDay;

  Color _getIntensityColor(int level, {bool isSelected = false}) {
    switch (level) {
      case 4:
        return isSelected ? AppColors.present : AppColors.present.withValues(alpha: 0.18);
      case 3:
        return isSelected ? AppColors.warning : AppColors.warning.withValues(alpha: 0.22);
      case 2:
        return isSelected ? const Color(0xFFE65100) : const Color(0xFFE65100).withValues(alpha: 0.22);
      case 1:
        return isSelected ? AppColors.absent : AppColors.absent.withValues(alpha: 0.22);
      default:
        return AppColors.background;
    }
  }

  Color _getTextColor(int level, {bool isSelected = false}) {
    if (isSelected && level > 0) return Colors.white;
    switch (level) {
      case 4:
        return const Color(0xFF1B5E20);
      case 3:
        return const Color(0xFFB78103);
      case 2:
        return const Color(0xFFBF360C);
      case 1:
        return const Color(0xFFB71C1C);
      default:
        return AppColors.textSecondary;
    }
  }

  void _showDayDetailsDialog(DayHeatmapData day) {
    showDialog(
      context: context,
      builder: (ctx) {
        final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(day.date);
        final hasSessions = day.isConducted;
        final conductedSessionsCount = (day.morningConducted ? 1 : 0) + (day.afternoonConducted ? 1 : 0);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.event, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasSessions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            "No Conducted Sessions",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Weekend, institutional holiday, or unconducted attendance date.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Primary KPI banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: day.attendancePercentage >= 75
                          ? AppColors.present.withValues(alpha: 0.1)
                          : AppColors.absent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "${day.attendancePercentage.toStringAsFixed(1)}%",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: day.attendancePercentage >= 75 ? AppColors.present : AppColors.absent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.attendancePercentage >= 75 ? "Target Met (≥ 75%)" : "Below Institutional Target",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: day.attendancePercentage >= 75 ? AppColors.present : AppColors.absent,
                                ),
                              ),
                              Text(
                                "Conducted Shifts: $conductedSessionsCount (${day.morningConducted ? 'Morning' : ''}${day.morningConducted && day.afternoonConducted ? ' & ' : ''}${day.afternoonConducted ? 'Afternoon' : ''})",
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Counts grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _detailStat("Present Records", "${day.presentCount}", AppColors.present, Icons.check_circle_outline),
                      _detailStat("Absent Records", "${day.absentCount}", AppColors.absent, Icons.cancel_outlined),
                      _detailStat("On Duty (OD)", "${day.odCount}", AppColors.od, Icons.badge_outlined),
                      _detailStat("Bunk Records", "${day.bunkCount}", AppColors.bunk, Icons.directions_run),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _detailStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthNumber = widget.filter.month ?? DateTime.now().month;
    final year = widget.filter.year;
    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, monthNumber));

    // Calculate leading blanks in calendar based on 1st day of month
    final firstDayOfMonth = DateTime(year, monthNumber, 1);
    // weekday in Dart is 1 = Monday, 7 = Sunday
    final leadingBlanks = (firstDayOfMonth.weekday - 1);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Calendar Header with Month Selector and Legend
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Monthly Attendance Calendar Heatmap: $monthName",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Text(
                          "Visual intensity reflects actual conducted session attendance percentages",
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Month navigation (if callback provided)
                    if (widget.onMonthChanged != null) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: "Previous Month",
                        onPressed: monthNumber > 1 ? () => widget.onMonthChanged!(monthNumber - 1) : null,
                      ),
                      Text(
                        DateFormat('MMM').format(DateTime(year, monthNumber)),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: "Next Month",
                        onPressed: monthNumber < 12 ? () => widget.onMonthChanged!(monthNumber + 1) : null,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),

                // Heatmap Legend
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _legendItem(level: 4, label: "Good (≥ 75%)"),
                    _legendItem(level: 3, label: "Warning (65-75%)"),
                    _legendItem(level: 2, label: "High Risk (50-65%)"),
                    _legendItem(level: 1, label: "Critical (< 50%)"),
                    _legendItem(level: 0, label: "No Sessions / Weekend"),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Calendar Matrix Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day-of-week Headers
                const Row(
                  children: [
                    Expanded(child: _WeekdayHeader("Mon")),
                    Expanded(child: _WeekdayHeader("Tue")),
                    Expanded(child: _WeekdayHeader("Wed")),
                    Expanded(child: _WeekdayHeader("Thu")),
                    Expanded(child: _WeekdayHeader("Fri")),
                    Expanded(child: _WeekdayHeader("Sat")),
                    Expanded(child: _WeekdayHeader("Sun")),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),

                // Grid Days
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: leadingBlanks + widget.heatmapData.length,
                  itemBuilder: (context, index) {
                    if (index < leadingBlanks) {
                      // Blank slot before 1st of month
                      return const SizedBox.shrink();
                    }

                    final dayIndex = index - leadingBlanks;
                    if (dayIndex >= widget.heatmapData.length) {
                      return const SizedBox.shrink();
                    }

                    final day = widget.heatmapData[dayIndex];
                    final isSelected = _selectedDay?.dayOfMonth == day.dayOfMonth;
                    final bgColor = _getIntensityColor(day.intensityLevel, isSelected: isSelected);
                    final textColor = _getTextColor(day.intensityLevel, isSelected: isSelected);
                    final sessionCount = (day.morningConducted ? 1 : 0) + (day.afternoonConducted ? 1 : 0);

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedDay = day);
                        _showDayDetailsDialog(day);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (day.intensityLevel > 0
                                    ? textColor.withValues(alpha: 0.3)
                                    : AppColors.border),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${day.dayOfMonth}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                if (day.isConducted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: textColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "${sessionCount}s",
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                  ),
                              ],
                            ),
                            if (day.isConducted)
                              Center(
                                child: Text(
                                  "${day.attendancePercentage.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              )
                            else
                              const Center(
                                child: Text(
                                  "—",
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required int level, required String label}) {
    final color = _getIntensityColor(level);
    final textColor = _getTextColor(level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: textColor.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String title;

  const _WeekdayHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
