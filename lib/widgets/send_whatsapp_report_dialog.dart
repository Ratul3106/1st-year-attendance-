import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';

class SendWhatsAppReportDialog extends StatefulWidget {
  final ClassModel? initialClass;
  final DateTime? initialDate;
  final VoidCallback? onReportSent;

  const SendWhatsAppReportDialog({
    super.key,
    this.initialClass,
    this.initialDate,
    this.onReportSent,
  });

  static Future<void> show(
    BuildContext context, {
    ClassModel? initialClass,
    DateTime? initialDate,
    VoidCallback? onReportSent,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SendWhatsAppReportDialog(
        initialClass: initialClass,
        initialDate: initialDate,
        onReportSent: onReportSent,
      ),
    );
  }

  @override
  State<SendWhatsAppReportDialog> createState() =>
      _SendWhatsAppReportDialogState();
}

class _SendWhatsAppReportDialogState extends State<SendWhatsAppReportDialog> {
  final _adminService = AdminService();
  final _whatsappService = WhatsAppNotificationService.instance;

  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  late DateTime _selectedDate;
  String _selectedReportType = 'combined'; // 'combined', 'morning', 'afternoon'
  bool _isPreliminary = false;

  List<AuthorizedRecipient> _allRecipients = [];
  final Set<String> _selectedRecipientIds = {};

  bool _isLoading = true;
  bool _isSending = false;
  AttendanceReportModel? _previewReport;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final classes = await _adminService.getAllClasses();
    final recipients = await _whatsappService.getAuthorizedRecipients();

    ClassModel? selClass = widget.initialClass;
    if (selClass == null && classes.isNotEmpty) {
      selClass = classes.first;
    } else if (selClass != null && classes.isNotEmpty) {
      selClass = classes.firstWhere((c) => c.id == selClass!.id,
          orElse: () => classes.first);
    }

    // Default select active recipients
    final selRecs = recipients.where((r) => r.active).map((r) => r.id).toSet();

    if (mounted) {
      setState(() {
        _classes = classes;
        _selectedClass = selClass;
        _allRecipients = recipients;
        _selectedRecipientIds.addAll(selRecs);
        _isLoading = false;
      });
      _generatePreview();
    }
  }

  Future<void> _generatePreview() async {
    if (_selectedClass == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final report = await _whatsappService.generateAttendanceReport(
      classModel: _selectedClass!,
      date: dateStr,
      isPreliminary: _isPreliminary,
    );
    if (mounted) {
      setState(() {
        _previewReport = report;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _generatePreview();
    }
  }

  List<AuthorizedRecipient> get _filteredRecipients {
    if (_selectedClass == null) return _allRecipients;
    return _allRecipients
        .where((r) => r.active && r.isAuthorizedForClass(_selectedClass!.id))
        .toList();
  }

  Future<void> _sendReport() async {
    if (_previewReport == null) return;

    final targetRecipients = _allRecipients
        .where((r) => _selectedRecipientIds.contains(r.id))
        .toList();

    if (targetRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one authorized recipient."),
          backgroundColor: AppColors.absent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final result = await _whatsappService.sendWhatsAppReport(
      report: _previewReport!,
      recipients: targetRecipients,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    Navigator.pop(context); // Close send dialog

    // Show delivery summary
    final delivered = result['delivered_count'] ?? 0;
    final failed = result['failed_count'] ?? 0;
    final details = (result['details'] as List? ?? []);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              failed == 0 ? Icons.check_circle : Icons.warning_amber,
              color: failed == 0 ? AppColors.present : AppColors.warning,
            ),
            const SizedBox(width: 8),
            const Text("Report Delivery Summary"),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "WhatsApp Attendance Report dispatched to $delivered recipient(s)${failed > 0 ? ', $failed failed' : ''}.",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Divider(),
              ...details.map((d) {
                final isSent = d['status'] == 'Sent' || d['status'] == 'sent';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSent ? Icons.check_circle_outline : Icons.error_outline,
                    color: isSent ? AppColors.present : AppColors.absent,
                    size: 20,
                  ),
                  title: Text(
                      d['recipient'] ?? d['recipient_name'] ?? 'Recipient',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                      "${d['phone'] ?? d['recipient_phone'] ?? ''} • Status: ${d['status']}"),
                  trailing: d['wamid'] != null
                      ? Text(
                          "ID: ${d['wamid'].toString().substring(0, 14)}...",
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        )
                      : Text(
                          d['error'] ?? 'Error',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.absent),
                        ),
                );
              }),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onReportSent?.call();
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: _isLoading
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator()))
            : Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF075E54),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Send WhatsApp Attendance Report",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Dispatch verified attendance summary to authorized faculty & administrators",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Body with Controls & Live Preview
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel: Configuration Parameters
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Date Selection
                                  const Text("Reporting Date:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        border:
                                            Border.all(color: AppColors.border),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 16,
                                              color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Text(
                                            DateFormat('EEEE, dd MMMM yyyy')
                                                .format(_selectedDate),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.arrow_drop_down,
                                              color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // 2. Class Selection
                                  const Text("Target Class:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<ClassModel>(
                                        value: _selectedClass,
                                        isExpanded: true,
                                        items: _classes.map((c) {
                                          return DropdownMenuItem(
                                            value: c,
                                            child: Text(c.className,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(
                                                () => _selectedClass = val);
                                            _generatePreview();
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // 3. Report Scope & Preliminary/Final Toggle
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text("Report Scope:",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: AppColors.border),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: _selectedReportType,
                                                  isExpanded: true,
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: 'combined',
                                                        child: Text(
                                                            "Combined Daily",
                                                            style: TextStyle(
                                                                fontSize: 12))),
                                                    DropdownMenuItem(
                                                        value: 'morning',
                                                        child: Text(
                                                            "Morning Session",
                                                            style: TextStyle(
                                                                fontSize: 12))),
                                                    DropdownMenuItem(
                                                        value: 'afternoon',
                                                        child: Text(
                                                            "Afternoon Session",
                                                            style: TextStyle(
                                                                fontSize: 12))),
                                                  ],
                                                  onChanged: (v) {
                                                    if (v != null)
                                                      setState(() =>
                                                          _selectedReportType =
                                                              v);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text("Status Type:",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: AppColors.border),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton<bool>(
                                                  value: _isPreliminary,
                                                  isExpanded: true,
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: false,
                                                        child: Text(
                                                            "Final / Auto-Detect",
                                                            style: TextStyle(
                                                                fontSize: 12))),
                                                    DropdownMenuItem(
                                                        value: true,
                                                        child: Text(
                                                            "Preliminary (2 PM)",
                                                            style: TextStyle(
                                                                fontSize: 12))),
                                                  ],
                                                  onChanged: (v) {
                                                    if (v != null) {
                                                      setState(() =>
                                                          _isPreliminary = v);
                                                      _generatePreview();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),

                                  // 4. Authorized Recipients Selection
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Authorized Recipients:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            if (_selectedRecipientIds.length ==
                                                _filteredRecipients.length) {
                                              _selectedRecipientIds.clear();
                                            } else {
                                              _selectedRecipientIds.addAll(
                                                  _filteredRecipients
                                                      .map((r) => r.id));
                                            }
                                          });
                                        },
                                        child: Text(
                                          _selectedRecipientIds.length ==
                                                  _filteredRecipients.length
                                              ? "Deselect All"
                                              : "Select All",
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _filteredRecipients.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                              "No authorized recipients configured for this class.",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          )
                                        : Column(
                                            children:
                                                _filteredRecipients.map((rec) {
                                              final isChecked =
                                                  _selectedRecipientIds
                                                      .contains(rec.id);
                                              return CheckboxListTile(
                                                dense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                title: Text(rec.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12)),
                                                subtitle: Text(
                                                    "${rec.designation} • ${rec.maskedPhoneNumber}",
                                                    style: const TextStyle(
                                                        fontSize: 11)),
                                                value: isChecked,
                                                activeColor:
                                                    const Color(0xFF075E54),
                                                onChanged: (bool? val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedRecipientIds
                                                          .add(rec.id);
                                                    } else {
                                                      _selectedRecipientIds
                                                          .remove(rec.id);
                                                    }
                                                  });
                                                },
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Right Panel: Live WhatsApp Chat Preview (Section 5 Message Specification)
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.visibility_outlined,
                                        size: 16, color: Color(0xFF075E54)),
                                    SizedBox(width: 6),
                                    Text("WhatsApp Message Preview",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                          0xFFECE5DD), // WhatsApp chat wallpaper background
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _previewReport?.formattedMessage ??
                                              "Generating report preview...",
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11.5,
                                            height: 1.35,
                                            color: Color(0xFF111B21),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed:
                              _isSending ? null : () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF075E54),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSending ? null : _sendReport,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send, size: 16),
                          label: Text(
                            _isSending
                                ? "Sending Report..."
                                : "Confirm & Send (${_selectedRecipientIds.length} Recipient${_selectedRecipientIds.length == 1 ? '' : 's'})",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
