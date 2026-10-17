import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/widgets/discrepancy_badge.dart';

class DailyReportDetailScreen extends StatelessWidget {
  final DailyReport report;

  const DailyReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Report Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class & Report Status Card
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
                      Text(
                        "Attendance Date: ${report.attendanceDate}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: report.reportType == 'final'
                              ? AppColors.presentLight
                              : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          report.reportType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: report.reportType == 'final' ? AppColors.present : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(report.generatedAt)}",
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "Attendance Breakdown & Metrics",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _statTile("Total Active Enrolled", report.totalEnrolled.toString(), AppColors.textPrimary),
                _statTile("Both Sessions Present", report.bothPresent.toString(), AppColors.present),
                _statTile("Morning %", "${report.morningPercentage.toStringAsFixed(1)}%", AppColors.primary),
                _statTile("Afternoon %", "${report.afternoonPercentage.toStringAsFixed(1)}%", AppColors.primaryLight),
                _statTile("Morning Present / Absent", "${report.morningPresent} / ${report.morningAbsent}", AppColors.textPrimary),
                _statTile("Morning OD", report.morningOd.toString(), AppColors.od),
                _statTile("Afternoon Present / Absent", "${report.afternoonPresent} / ${report.afternoonAbsent}", AppColors.textPrimary),
                _statTile("Afternoon OD / Bunk", "${report.afternoonOd} / ${report.afternoonBunk}", AppColors.bunk),
                _statTile("Morning Pres → Aft Abs", report.morningPresentAfternoonAbsent.toString(), AppColors.warning),
                _statTile("Morning Pres → Aft Bunk", report.morningPresentAfternoonBunk.toString(), AppColors.bunk),
                _statTile("Both Sessions Absent", report.bothAbsent.toString(), AppColors.absent),
                _statTile("Incomplete Records", report.incompleteCount.toString(), AppColors.unmarked),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              "Attendance Discrepancies & Session Changes (${report.discrepancies.length})",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (report.discrepancies.isEmpty)
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
                    Text("No attendance discrepancies for this class."),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: report.discrepancies.length,
                itemBuilder: (context, index) {
                  final disc = report.discrepancies[index];
                  return Card(
                    child: ListTile(
                      title: Text(disc.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Register No: ${disc.registerNumber} | M: ${disc.morningStatus ?? "—"} → A: ${disc.afternoonStatus ?? "—"}'),
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
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
