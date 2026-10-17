import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/app_notification.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/services/report_service.dart';
import 'package:student_attendance_system/screens/staff/daily_report_detail_screen.dart';

class NotificationDetailScreen extends StatefulWidget {
  final AppNotification notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final _reportService = ReportService();
  DailyReport? _report;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.notification.reportId != null) {
      _loadReport(widget.notification.reportId!);
    }
  }

  Future<void> _loadReport(String reportId) async {
    setState(() => _isLoading = true);
    final report = await _reportService.getReportById(reportId);
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.notification.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('EEEE, dd MMMM yyyy - hh:mm a').format(widget.notification.createdAt),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Divider(height: 32),

            Text(
              widget.notification.message,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 32),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_report != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics),
                  label: const Text("Open Full Daily Report"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DailyReportDetailScreen(report: _report!),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
