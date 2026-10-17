import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsAppHistoryScreen extends StatefulWidget {
  const WhatsAppHistoryScreen({super.key});

  @override
  State<WhatsAppHistoryScreen> createState() => _WhatsAppHistoryScreenState();
}

class _WhatsAppHistoryScreenState extends State<WhatsAppHistoryScreen> {
  final _service = WhatsAppNotificationService.instance;

  List<WhatsAppNotificationLog> _logs = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    WhatsAppDeliveryStatus? statusFilter;
    if (_selectedStatus != 'All') {
      statusFilter = WhatsAppDeliveryStatus.fromString(_selectedStatus);
    }
    final logs = await _service.getNotificationLogs(statusFilter: statusFilter);
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerQueueProcessing() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Processing WhatsApp outbox queue..."), duration: Duration(seconds: 1)),
    );
    await _service.processQueue();
    await _loadLogs();
  }

  Future<void> _triggerRepeatedAbsenceEvaluation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<WhatsAppAbsenceSummaryResult> results = [];
    if (SupabaseConfig.isDemoMode) {
      results = await DemoDataService.instance.evaluateRepeatedAbsences();
    } else {
      try {
        final client = Supabase.instance.client;
        await client.functions.invoke('repeated-absence-job');
        await _loadLogs();
      } catch (e) {
        debugPrint('[WhatsAppHistory] Error invoking repeated-absence-job: $e');
      }
    }
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assessment_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text("Repeated-Absence Summary"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? const Text("No students currently meet the configured absence threshold in the reporting window.")
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, idx) {
                    final r = results[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.className, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("${r.qualifyingCount} student(s) met threshold (${r.periodStart} to ${r.periodEnd})",
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        ...r.qualifyingStudents.map((s) => Text(
                              "• ${s['full_name']} (${s['register_number']}) — ${s['absences']} absences",
                              style: const TextStyle(fontSize: 12, color: AppColors.absent),
                            )),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              r.deanNotified ? Icons.check_circle : Icons.schedule,
                              size: 14,
                              color: r.deanNotified ? AppColors.present : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r.deanNotified ? "Summary alert queued for Dean" : "Idempotent / Already sent for period",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: r.deanNotified ? AppColors.present : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadLogs();
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Color _statusColor(WhatsAppDeliveryStatus status) {
    switch (status) {
      case WhatsAppDeliveryStatus.queued:
        return AppColors.warning;
      case WhatsAppDeliveryStatus.processing:
        return AppColors.info;
      case WhatsAppDeliveryStatus.sent:
        return AppColors.primaryLight;
      case WhatsAppDeliveryStatus.delivered:
        return AppColors.present;
      case WhatsAppDeliveryStatus.read:
        return const Color(0xFF059669);
      case WhatsAppDeliveryStatus.failed:
        return AppColors.absent;
    }
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    final start = phone.substring(0, 5);
    final end = phone.substring(phone.length - 2);
    return "$start****$end";
  }

  void _showLogDetails(WhatsAppNotificationLog log) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.notificationType.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(log.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      log.status.displayName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _statusColor(log.status)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _detailRow("Recipient:", "${log.recipientName} (${log.recipientRole})"),
              _detailRow("Phone Number:", _maskPhone(log.recipientPhone)),
              if (log.studentName != null) ...[
                _detailRow("Student:", "${log.studentName} (${log.registerNumber})"),
                _detailRow("Class:", log.className ?? 'N/A'),
              ],
              if (log.providerMessageId != null)
                _detailRow("Meta WhatsApp ID (wamid):", log.providerMessageId!),
              _detailRow("Logged At:", DateFormat('dd MMM yyyy, HH:mm:ss').format(log.createdAt)),
              if (log.sentAt != null)
                _detailRow("Accepted by Meta:", DateFormat('dd MMM yyyy, HH:mm:ss').format(log.sentAt!)),
              if (log.deliveredAt != null)
                _detailRow("Delivered to Recipient:", DateFormat('dd MMM yyyy, HH:mm:ss').format(log.deliveredAt!)),
              if (log.readAt != null)
                _detailRow("Read by Recipient:", DateFormat('dd MMM yyyy, HH:mm:ss').format(log.readAt!)),
              if (log.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.absentLight, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.absent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Error: ${log.errorMessage}",
                          style: const TextStyle(color: AppColors.absent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (log.status == WhatsAppDeliveryStatus.failed && log.outboxId != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _service.updateOutboxStatus(
                        id: log.outboxId!,
                        status: WhatsAppDeliveryStatus.queued,
                        retryCount: 0,
                        nextRetryAt: DateTime.now(),
                      );
                      await _triggerQueueProcessing();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry Notification Now"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WhatsApp Delivery History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Delivery Logs",
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Quick Operations Toolbar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text("Delivery Status Filter:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isDense: true,
                        isExpanded: true,
                        items: ['All', 'Queued', 'Processing', 'Sent', 'Delivered', 'Read', 'Failed']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedStatus = v);
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _triggerRepeatedAbsenceEvaluation,
                        icon: const Icon(Icons.schedule_send, size: 16),
                        label: const Text("Run Absence Summary", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: _triggerQueueProcessing,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text("Flush Outbox", style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Log List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.mark_chat_read_outlined, size: 48, color: AppColors.unmarked),
                            const SizedBox(height: 10),
                            const Text("No WhatsApp Notifications Found", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _selectedStatus == 'All'
                                  ? "Notifications trigger when faculty saves students as Absent."
                                  : "No records found matching status '$_selectedStatus'.",
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final color = _statusColor(log.status);

                          return InkWell(
                            onTap: () => _showLogDetails(log),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    child: Icon(
                                      log.status == WhatsAppDeliveryStatus.delivered || log.status == WhatsAppDeliveryStatus.read
                                          ? Icons.done_all
                                          : log.status == WhatsAppDeliveryStatus.failed
                                              ? Icons.error_outline
                                              : Icons.send,
                                      color: color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              log.notificationType.displayName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              DateFormat('dd MMM, HH:mm').format(log.createdAt),
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        if (log.studentName != null)
                                          Text(
                                            "Student: ${log.studentName} (${log.registerNumber})",
                                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                          ),
                                        Text(
                                          "Recipient: ${log.recipientName} • ${_maskPhone(log.recipientPhone)}",
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                log.status.displayName,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                                              ),
                                            ),
                                            if (log.providerMessageId != null) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  log.providerMessageId!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.unmarked),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 18, color: AppColors.unmarked),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
