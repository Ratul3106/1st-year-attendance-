import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/services/attendance_report_generator_service.dart';
import 'package:student_attendance_system/widgets/college_logo.dart';

class AttendanceReportPreviewDialog extends StatefulWidget {
  final AttendanceReportData reportData;

  const AttendanceReportPreviewDialog({
    super.key,
    required this.reportData,
  });

  static Future<void> show(
    BuildContext context, {
    required AttendanceReportData data,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AttendanceReportPreviewDialog(reportData: data),
    );
  }

  @override
  State<AttendanceReportPreviewDialog> createState() =>
      _AttendanceReportPreviewDialogState();
}

class _AttendanceReportPreviewDialogState
    extends State<AttendanceReportPreviewDialog>
    with SingleTickerProviderStateMixin {
  final _reportService = AttendanceReportGeneratorService();
  late TabController _tabController;
  bool _isDownloadingPdf = false;
  bool _isDownloadingExcel = false;
  String? _downloadMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _download(String format) async {
    setState(() {
      if (format == 'pdf') {
        _isDownloadingPdf = true;
      } else {
        _isDownloadingExcel = true;
      }
      _downloadMessage = null;
    });

    try {
      final filename = await _reportService.exportReportDataAsFile(
        widget.reportData,
        format,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${format.toUpperCase()} report successfully downloaded:\n$filename',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.present,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadMessage = "Export failed: ${e.toString().replaceAll('Exception: ', '')}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
          _isDownloadingExcel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.reportData;
    final a = data.analytics;
    final config = data.config;
    final startStr = DateFormat('dd MMM yyyy').format(config.startDate);
    final endStr = DateFormat('dd MMM yyyy').format(config.endDate);
    final dateRangeStr = startStr == endStr ? startStr : "$startStr - $endStr";

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 880),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const CollegeLogo(height: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Attendance Report Preview",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                config.classNameDisplay,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Date: $dateRangeStr  •  Session: ${config.sessionFilter}  •  Generated: ${DateFormat('hh:mm a').format(data.generatedAt)}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
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
            ),

            // Error / Notice banner if any
            if (_downloadMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.absentLight,
                child: Text(
                  _downloadMessage!,
                  style: const TextStyle(
                      color: AppColors.absent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary KPI Cards Grid
                    _buildKpiMetrics(a),
                    const SizedBox(height: 14),

                    // Shifts & Breakdown Details
                    _buildShiftBreakdown(a),
                    const SizedBox(height: 18),

                    // Categorized Tabs Title
                    Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text(
                          "Categorized Student Attendance Lists",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "Click tabs below to filter categories",
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: AppColors.primary,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                        tabs: [
                          Tab(text: "All (${data.allItems.length})"),
                          Tab(text: "Present (${data.presentList.length})"),
                          Tab(text: "Absent (${data.absentList.length})"),
                          Tab(text: "On Duty (${data.odList.length})"),
                          Tab(text: "Bunked (${data.bunkList.length})"),
                          Tab(text: "Unmarked (${data.unmarkedList.length})"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab View Content (Fixed Height Scrollable Table)
                    SizedBox(
                      height: 380,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStudentTable(data.allItems),
                          _buildStudentTable(data.presentList),
                          _buildStudentTable(data.absentList),
                          _buildStudentTable(data.odList),
                          _buildStudentTable(data.bunkList),
                          _buildStudentTable(data.unmarkedList),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar with PDF & Excel Downloads
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Text(
                    "Ready to export report file?",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close"),
                  ),
                  const SizedBox(width: 12),

                  // Download Excel Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isDownloadingExcel
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.table_chart, size: 16),
                    label: Text(_isDownloadingExcel ? "Generating..." : "Download Excel"),
                    onPressed: (_isDownloadingPdf || _isDownloadingExcel)
                        ? null
                        : () => _download('excel'),
                  ),
                  const SizedBox(width: 10),

                  // Download PDF Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(_isDownloadingPdf ? "Generating..." : "Download PDF"),
                    onPressed: (_isDownloadingPdf || _isDownloadingExcel)
                        ? null
                        : () => _download('pdf'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiMetrics(AttendanceReportAnalytics a) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800
            ? 7
            : constraints.maxWidth > 500
                ? 4
                : 2;

        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            _kpiCard(
              "Attendance %",
              "${a.overallPercentage.toStringAsFixed(1)}%",
              a.overallPercentage >= 75.0
                  ? AppColors.present
                  : a.overallPercentage >= 65.0
                      ? AppColors.warning
                      : AppColors.absent,
              Icons.pie_chart,
            ),
            _kpiCard("Total Enrolled", "${a.totalEnrolledStudents}",
                AppColors.primary, Icons.school),
            _kpiCard("Present", "${a.totalPresent}", AppColors.present,
                Icons.check_circle_outline),
            _kpiCard("Absent", "${a.totalAbsent}", AppColors.absent,
                Icons.highlight_off),
            _kpiCard("On Duty (OD)", "${a.totalOd}", AppColors.od,
                Icons.badge_outlined),
            _kpiCard("Bunked", "${a.totalBunk}", AppColors.bunk,
                Icons.directions_run),
            _kpiCard("Unmarked", "${a.totalUnmarked}", AppColors.unmarked,
                Icons.help_outline),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftBreakdown(AttendanceReportAnalytics a) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Morning Summary
          Expanded(
            child: _shiftItem(
              title: "Morning Session",
              present: a.morningPresent,
              absent: a.morningAbsent,
              od: a.morningOd,
              pct: a.morningPercentage,
              icon: Icons.wb_sunny_outlined,
            ),
          ),
          Container(height: 38, width: 1, color: AppColors.border),
          // Afternoon Summary
          Expanded(
            child: _shiftItem(
              title: "Afternoon Session",
              present: a.afternoonPresent,
              absent: a.afternoonAbsent,
              od: a.afternoonOd,
              pct: a.afternoonPercentage,
              icon: Icons.brightness_6_outlined,
            ),
          ),
          Container(height: 38, width: 1, color: AppColors.border),
          // Comparison Shifts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text("Shift Comparison",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    _chip("Both Pres: ${a.presentBothSessions}", AppColors.present),
                    _chip("M. Pres → A. Abs: ${a.presentMorningAbsentAfternoon}", AppColors.warning),
                    _chip("Both Abs: ${a.absentBothSessions}", AppColors.absent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftItem({
    required String title,
    required int present,
    required int absent,
    required int od,
    required double pct,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 6),
            Text("${pct.toStringAsFixed(1)}%",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "P: $present  •  A: $absent  •  OD: $od",
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildStudentTable(List<StudentReportItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 36, color: AppColors.unmarked),
            const SizedBox(height: 8),
            const Text(
              "No students in this category for the selected parameters.",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 38,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            columns: const [
              DataColumn(label: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text("Reg No", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text("Class", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text("Session", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ],
            rows: items.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text("${item.sNo}", style: const TextStyle(fontSize: 11))),
                  DataCell(Text(item.registerNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                  DataCell(Text(item.studentName, style: const TextStyle(fontSize: 11))),
                  DataCell(Text(item.className, style: const TextStyle(fontSize: 11))),
                  DataCell(Text(item.date, style: const TextStyle(fontSize: 11))),
                  DataCell(Text(item.session, style: const TextStyle(fontSize: 11))),
                  DataCell(_statusBadge(item.status)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(AttendanceStatus? status) {
    if (status == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.unmarkedLight,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text("Unmarked",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.unmarked)),
      );
    }

    Color bg;
    Color fg;
    switch (status) {
      case AttendanceStatus.present:
        bg = AppColors.presentLight;
        fg = AppColors.present;
        break;
      case AttendanceStatus.absent:
        bg = AppColors.absentLight;
        fg = AppColors.absent;
        break;
      case AttendanceStatus.od:
        bg = AppColors.odLight;
        fg = AppColors.od;
        break;
      case AttendanceStatus.bunk:
        bg = AppColors.bunkLight;
        fg = AppColors.bunk;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

