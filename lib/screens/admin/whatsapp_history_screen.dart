import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/widgets/send_whatsapp_report_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/widgets/college_logo.dart';

class WhatsAppHistoryScreen extends StatefulWidget {
  const WhatsAppHistoryScreen({super.key});

  @override
  State<WhatsAppHistoryScreen> createState() => _WhatsAppHistoryScreenState();
}

class _WhatsAppHistoryScreenState extends State<WhatsAppHistoryScreen> {
  final _service = WhatsAppNotificationService.instance;
  final _adminService = AdminService();

  List<WhatsAppNotificationLog> _logs = [];
  List<ClassModel> _classes = [];
  bool _isLoading = true;

  // Filters
  String _selectedStatus = 'All';
  String _selectedClassId = 'All';
  String _selectedReportType = 'All';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final classes = await _adminService.getAllClasses();
    _classes = classes;
    await _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    WhatsAppDeliveryStatus? statusFilter;
    if (_selectedStatus != 'All') {
      statusFilter = WhatsAppDeliveryStatus.fromString(_selectedStatus);
    }

    final logs = await _service.getNotificationLogs(
      classIdFilter: _selectedClassId,
      statusFilter: statusFilter,
      reportTypeFilter: _selectedReportType,
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
    );

    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  List<WhatsAppNotificationLog> get _filteredLogs {
    if (_searchQuery.trim().isEmpty) return _logs;
    final q = _searchQuery.toLowerCase();
    return _logs.where((l) {
      final name = l.recipientName.toLowerCase();
      final phone = l.recipientPhone.toLowerCase();
      final role = l.recipientRole.toLowerCase();
      final wamid = (l.providerMessageId ?? '').toLowerCase();
      final cls = (l.className ?? '').toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          role.contains(q) ||
          wamid.contains(q) ||
          cls.contains(q);
    }).toList();
  }

  Future<void> _triggerQueueProcessing() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Processing WhatsApp outbox queue..."),
          duration: Duration(seconds: 1)),
    );
    await _service.processQueue();
    await _loadLogs();
  }

  Future<void> _retryMessage(String logId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Requeuing message for delivery retry..."),
          duration: Duration(seconds: 1)),
    );
    final ok = await _service.retryDelivery(logId);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Message successfully requeued and retried."),
              backgroundColor: AppColors.present),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Failed to retry message or maximum retries reached."),
              backgroundColor: AppColors.absent),
        );
      }
      await _loadLogs();
    }
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
              ? const Text(
                  "No students currently meet the configured absence threshold in the reporting window.")
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, idx) {
                    final r = results[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.className,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                            "${r.qualifyingCount} student(s) met threshold (${r.periodStart} to ${r.periodEnd})",
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        ...r.qualifyingStudents.map((s) => Text(
                              "• ${s['full_name']} (${s['register_number']}) — ${s['absences']} absences",
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.absent),
                            )),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              r.deanNotified
                                  ? Icons.check_circle
                                  : Icons.schedule,
                              size: 14,
                              color: r.deanNotified
                                  ? AppColors.present
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r.deanNotified
                                  ? "Summary alert queued for Dean"
                                  : "Idempotent / Already sent for period",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: r.deanNotified
                                    ? AppColors.present
                                    : AppColors.warning,
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
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _openManualSendDialog() {
    SendWhatsAppReportDialog.show(
      context,
      onReportSent: _loadLogs,
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      await _loadLogs();
    }
  }

  Color _statusColor(WhatsAppDeliveryStatus st) {
    switch (st) {
      case WhatsAppDeliveryStatus.queued:
        return Colors.blueGrey;
      case WhatsAppDeliveryStatus.processing:
        return Colors.orange;
      case WhatsAppDeliveryStatus.sent:
        return Colors.blue;
      case WhatsAppDeliveryStatus.delivered:
        return Colors.teal;
      case WhatsAppDeliveryStatus.read:
        return AppColors.present;
      case WhatsAppDeliveryStatus.failed:
        return AppColors.absent;
    }
  }

  IconData _statusIcon(WhatsAppDeliveryStatus st) {
    switch (st) {
      case WhatsAppDeliveryStatus.queued:
        return Icons.hourglass_top;
      case WhatsAppDeliveryStatus.processing:
        return Icons.sync;
      case WhatsAppDeliveryStatus.sent:
        return Icons.check;
      case WhatsAppDeliveryStatus.delivered:
        return Icons.done_all;
      case WhatsAppDeliveryStatus.read:
        return Icons.done_all;
      case WhatsAppDeliveryStatus.failed:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CollegeLogo(height: 32),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                "WhatsApp Delivery Logs & History",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Delivery Logs",
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.outbox_outlined),
            tooltip: "Flush Outbox Queue",
            onPressed: _triggerQueueProcessing,
          ),
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: "Evaluate Repeated Absences",
            onPressed: _triggerRepeatedAbsenceEvaluation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header & Action Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF075E54),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _openManualSendDialog,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text("Send WhatsApp Report",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.filter_alt_outlined, size: 16),
                        label: Text(
                          _selectedDateRange == null
                              ? "Date Range: All"
                              : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: _pickDateRange,
                      ),
                      if (_selectedDateRange != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            setState(() => _selectedDateRange = null);
                            _loadLogs();
                          },
                        ),
                      const Spacer(),
                      Text(
                        "${_filteredLogs.length} Delivery Attempt${_filteredLogs.length == 1 ? '' : 's'}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Filters Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F9FC),
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      // Status Filter
                      const Text("Status:",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _selectedStatus,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(
                              value: 'All', child: Text("All Statuses")),
                          DropdownMenuItem(
                              value: 'Queued', child: Text("Queued")),
                          DropdownMenuItem(
                              value: 'Processing', child: Text("Processing")),
                          DropdownMenuItem(value: 'Sent', child: Text("Sent")),
                          DropdownMenuItem(
                              value: 'Delivered', child: Text("Delivered")),
                          DropdownMenuItem(value: 'Read', child: Text("Read")),
                          DropdownMenuItem(
                              value: 'Failed', child: Text("Failed")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _loadLogs();
                          }
                        },
                      ),
                      const SizedBox(width: 16),

                      // Class Filter
                      const Text("Class:",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _selectedClassId,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        items: [
                          const DropdownMenuItem(
                              value: 'All', child: Text("All Classes")),
                          ..._classes.map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.className))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedClassId = val);
                            _loadLogs();
                          }
                        },
                      ),
                      const SizedBox(width: 16),

                      // Report Type Filter
                      const Text("Type:",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _selectedReportType,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(
                              value: 'All', child: Text("All Types")),
                          DropdownMenuItem(
                              value: 'report',
                              child: Text("Attendance Reports")),
                          DropdownMenuItem(
                              value: 'absence', child: Text("Absence Alerts")),
                          DropdownMenuItem(
                              value: 'summary',
                              child: Text("Absence Summaries")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedReportType = val);
                            _loadLogs();
                          }
                        },
                      ),
                      const Spacer(),

                      // Search text
                      SizedBox(
                        width: 200,
                        height: 34,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search recipient/phone...",
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon: const Icon(Icons.search, size: 16),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delivery Logs Table / List
                Expanded(
                  child: _filteredLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox_outlined,
                                  size: 48, color: AppColors.unmarked),
                              const SizedBox(height: 12),
                              const Text("No Delivery Logs Match Filters",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              const Text(
                                  "Logs will appear here when WhatsApp notifications are triggered.",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF075E54),
                                    foregroundColor: Colors.white),
                                onPressed: _openManualSendDialog,
                                icon: const Icon(Icons.send, size: 16),
                                label:
                                    const Text("Send Manual Attendance Report"),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLogs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final log = _filteredLogs[idx];
                            final stColor = _statusColor(log.status);

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Status chip, Recipient, Time
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Status Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                stColor.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: stColor.withValues(
                                                    alpha: 0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_statusIcon(log.status),
                                                  size: 14, color: stColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                log.status.displayName
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: stColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    log.recipientName,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "(${log.recipientRole})",
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Phone: ${log.maskedPhone}${log.className != null ? ' • Class: ${log.className}' : ''}",
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors
                                                        .textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Timestamp
                                        Text(
                                          DateFormat('dd MMM, hh:mm a')
                                              .format(log.attemptTimestamp),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Row 2: Type, Delivery/Read Timestamps, Provider ID
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        _badge(
                                            Icons.label_outline,
                                            log.reportTypeLabel ??
                                                log.notificationType
                                                    .displayName),
                                        if (log.providerMessageId != null)
                                          _badge(Icons.vpn_key_outlined,
                                              "ID: ${log.providerMessageId!.length > 16 ? '${log.providerMessageId!.substring(0, 16)}...' : log.providerMessageId!}"),
                                        if (log.deliveredAt != null)
                                          _badge(
                                              Icons.done_all,
                                              "Delivered: ${DateFormat('hh:mm:ss a').format(log.deliveredAt!)}",
                                              AppColors.present),
                                        if (log.readAt != null)
                                          _badge(
                                              Icons.visibility,
                                              "Read: ${DateFormat('hh:mm:ss a').format(log.readAt!)}",
                                              Colors.purple),
                                      ],
                                    ),

                                    // Failure reason & Retry button if failed
                                    if (log.status ==
                                            WhatsAppDeliveryStatus.failed ||
                                        log.errorMessage != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.absent
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: AppColors.absent
                                                  .withValues(alpha: 0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline,
                                                size: 14,
                                                color: AppColors.absent),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                "Failure Reason: ${log.errorMessage ?? 'Meta API communication failure'}",
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.absent),
                                              ),
                                            ),
                                            if (log.canRetry)
                                              TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                ),
                                                icon: const Icon(Icons.replay,
                                                    size: 14,
                                                    color: Color(0xFF075E54)),
                                                label: const Text("Retry Now",
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF075E54))),
                                                onPressed: () =>
                                                    _retryMessage(log.id),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
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

  Widget _badge(IconData icon, String text, [Color? color]) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}
