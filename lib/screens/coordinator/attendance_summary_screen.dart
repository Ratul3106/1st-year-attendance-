import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/services/report_service.dart';
import 'package:student_attendance_system/widgets/discrepancy_badge.dart';

class AttendanceSummaryScreen extends StatefulWidget {
  final ClassModel selectedClass;
  final String date;

  const AttendanceSummaryScreen({
    super.key,
    required this.selectedClass,
    required this.date,
  });

  @override
  State<AttendanceSummaryScreen> createState() => _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {
  final _reportService = ReportService();
  DailyReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final report = await _reportService.getDailyReport(
      classId: widget.selectedClass.id,
      date: widget.date,
    );
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Attendance Summary"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Report",
            onPressed: _fetchReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assessment_outlined, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        const Text(
                          "No attendance records saved for today yet.",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Please mark and save morning or afternoon attendance first.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _fetchReport,
                          child: const Text("Refresh Status"),
                        )
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Info Card
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.selectedClass.displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _report!.reportType == 'final'
                                        ? AppColors.presentLight
                                        : AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _report!.reportType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _report!.reportType == 'final'
                                          ? AppColors.present
                                          : AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Date: ${widget.date}",
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            Text(
                              "Report Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(_report!.generatedAt)}",
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        "Attendance Breakdown & Percentages",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Metric Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _statTile("Total Active Enrolled", _report!.totalEnrolled.toString(), AppColors.textPrimary),
                          _statTile("Both Present", _report!.bothPresent.toString(), AppColors.present),
                          _statTile("Morning %", "${_report!.morningPercentage.toStringAsFixed(1)}%", AppColors.primary),
                          _statTile("Afternoon %", "${_report!.afternoonPercentage.toStringAsFixed(1)}%", AppColors.primaryLight),
                          _statTile("Morning Present / Absent", "${_report!.morningPresent} / ${_report!.morningAbsent}", AppColors.textPrimary),
                          _statTile("Morning OD", _report!.morningOd.toString(), AppColors.od),
                          _statTile("Afternoon Present / Absent", "${_report!.afternoonPresent} / ${_report!.afternoonAbsent}", AppColors.textPrimary),
                          _statTile("Afternoon OD / Bunk", "${_report!.afternoonOd} / ${_report!.afternoonBunk}", AppColors.bunk),
                          _statTile("Morning Pres → Aft Abs", _report!.morningPresentAfternoonAbsent.toString(), AppColors.warning),
                          _statTile("Morning Pres → Aft Bunk", _report!.morningPresentAfternoonBunk.toString(), AppColors.bunk),
                          _statTile("Both Sessions Absent", _report!.bothAbsent.toString(), AppColors.absent),
                          _statTile("Incomplete Records", _report!.incompleteCount.toString(), AppColors.unmarked),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Text(
                        "Attendance Discrepancies & Shifts (${_report!.discrepancies.length})",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      if (_report!.discrepancies.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppColors.present),
                              SizedBox(width: 10),
                              Text("No attendance discrepancies found for today!"),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _report!.discrepancies.length,
                          itemBuilder: (context, index) {
                            final disc = _report!.discrepancies[index];
                            return Card(
                              child: ListTile(
                                title: Text(disc.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Reg: ${disc.registerNumber} | M: ${disc.morningStatus ?? "—"} → A: ${disc.afternoonStatus ?? "—"}'),
                                trailing: DiscrepancyBadge(discrepancyType: disc.discrepancyType),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
