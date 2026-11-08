import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';
import 'package:student_attendance_system/widgets/college_logo.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = WhatsAppNotificationService.instance;
  final _adminService = AdminService();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isSendingAdminReport = false;

  // Configuration Fields
  late bool _reportsEnabled;
  late bool _immediateEnabled;
  late bool _summaryEnabled;
  late String _reportTime;
  late String _timezone;
  late String _reportFrequency;
  late String _targetClasses;
  late bool _includeMorning;
  late bool _includeAfternoon;
  late bool _includeCombined;
  late bool _sendPreliminary;
  late bool _sendFinalOnCompletion;
  late int _threshold;
  late int _windowDays;

  // Controllers
  late TextEditingController _phoneIdCtrl;
  late TextEditingController _businessAccountCtrl;
  late TextEditingController _apiVersionCtrl;
  late TextEditingController _reportTemplateCtrl;
  late TextEditingController _absenceTemplateCtrl;
  late TextEditingController _summaryTemplateCtrl;
  late TextEditingController _deanNameCtrl;
  late TextEditingController _deanPhoneCtrl;
  late TextEditingController _adminNameCtrl;
  late TextEditingController _adminPhoneCtrl;
  final TextEditingController _testPhoneCtrl =
      TextEditingController(text: '+919876543200');

  List<ClassModel> _allClasses = [];
  List<AuthorizedRecipient> _authorizedRecipients = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final s = await _service.getSettings();
    final classes = await _adminService.getAllClasses();
    final recs = await _service.getAuthorizedRecipients();

    _reportsEnabled = s.reportsEnabled;
    _immediateEnabled = s.immediateAlertsEnabled;
    _summaryEnabled = s.summaryAlertsEnabled;
    _reportTime = s.reportTime;
    _timezone = s.timezone;
    _reportFrequency = s.reportFrequency;
    _targetClasses = s.targetClasses;
    _includeMorning = s.includeMorning;
    _includeAfternoon = s.includeAfternoon;
    _includeCombined = s.includeCombined;
    _sendPreliminary = s.sendPreliminary;
    _sendFinalOnCompletion = s.sendFinalOnCompletion;
    _threshold = s.absenceThreshold;
    _windowDays = s.reportingWindowDays;

    _phoneIdCtrl = TextEditingController(text: s.phoneNumberId);
    _businessAccountCtrl = TextEditingController(text: s.businessAccountId);
    _apiVersionCtrl = TextEditingController(text: s.apiVersion);
    _reportTemplateCtrl = TextEditingController(text: s.reportTemplateName);
    _absenceTemplateCtrl = TextEditingController(text: s.absenceTemplateName);
    _summaryTemplateCtrl = TextEditingController(text: s.summaryTemplateName);
    _deanNameCtrl = TextEditingController(text: s.deanPlacementName);
    _deanPhoneCtrl = TextEditingController(text: s.deanPlacementPhone);
    _adminNameCtrl = TextEditingController(
        text: s.adminName.isNotEmpty
            ? s.adminName
            : "Dr. Ramesh Sharma (Administrator)");
    _adminPhoneCtrl = TextEditingController(
        text: s.adminPhone.isNotEmpty ? s.adminPhone : "+919876543200");

    if (mounted) {
      setState(() {
        _allClasses = classes;
        _authorizedRecipients = List.from(recs);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneIdCtrl.dispose();
    _businessAccountCtrl.dispose();
    _apiVersionCtrl.dispose();
    _reportTemplateCtrl.dispose();
    _absenceTemplateCtrl.dispose();
    _summaryTemplateCtrl.dispose();
    _deanNameCtrl.dispose();
    _deanPhoneCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _testPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final current = await _service.getSettings();
    final updated = current.copyWith(
      reportsEnabled: _reportsEnabled,
      immediateAlertsEnabled: _immediateEnabled,
      summaryAlertsEnabled: _summaryEnabled,
      reportTime: _reportTime,
      timezone: _timezone,
      reportFrequency: _reportFrequency,
      targetClasses: _targetClasses,
      includeMorning: _includeMorning,
      includeAfternoon: _includeAfternoon,
      includeCombined: _includeCombined,
      sendPreliminary: _sendPreliminary,
      sendFinalOnCompletion: _sendFinalOnCompletion,
      absenceThreshold: _threshold,
      reportingWindowDays: _windowDays,
      phoneNumberId: _phoneIdCtrl.text.trim(),
      businessAccountId: _businessAccountCtrl.text.trim(),
      apiVersion: _apiVersionCtrl.text.trim(),
      reportTemplateName: _reportTemplateCtrl.text.trim(),
      absenceTemplateName: _absenceTemplateCtrl.text.trim(),
      summaryTemplateName: _summaryTemplateCtrl.text.trim(),
      deanPlacementName: _deanNameCtrl.text.trim(),
      deanPlacementPhone: _deanPhoneCtrl.text.trim(),
      adminName: _adminNameCtrl.text.trim(),
      adminPhone: _adminPhoneCtrl.text.trim(),
    );

    await _service.updateSettings(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "WhatsApp notification & reporting configuration saved successfully."),
          backgroundColor: AppColors.present,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    final res =
        await _service.testWhatsAppConnection(_testPhoneCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isTesting = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              res['success'] == true ? Icons.check_circle : Icons.error_outline,
              color:
                  res['success'] == true ? AppColors.present : AppColors.absent,
            ),
            const SizedBox(width: 8),
            Text(res['success'] == true
                ? "Test Connection Succeeded"
                : "Test Connection Failed"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              res['message'] ?? res['error'] ?? 'Connection test completed.',
              style: const TextStyle(fontSize: 13),
            ),
            if (res['messageId'] != null) ...[
              const SizedBox(height: 8),
              Text(
                "Provider Message ID: ${res['messageId']}",
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _formatTimeDisplay(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    final h = int.tryParse(parts[0]) ?? 14;
    final m = int.tryParse(parts[1]) ?? 0;
    final minuteStr = m.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    return "$time24 ($displayH:$minuteStr $ampm IST)";
  }

  TimeOfDay _parseTimeOfDay(String time24) {
    final parts = time24.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 14;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h, minute: m);
    }
    return const TimeOfDay(hour: 14, minute: 0);
  }

  Future<void> _testConsolidatedAdminReport() async {
    final phone = _adminPhoneCtrl.text.trim();
    final name = _adminNameCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the Admin WhatsApp mobile number."),
          backgroundColor: AppColors.absent,
        ),
      );
      return;
    }

    setState(() => _isSendingAdminReport = true);
    try {
      final res = await _service.sendConsolidatedReportToAdminNow(
        targetPhone: phone,
        adminName: name.isNotEmpty ? name : "Administrator",
        date: DateTime.now(),
      );

      if (!mounted) return;
      setState(() => _isSendingAdminReport = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                res['success'] == true
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: res['success'] == true
                    ? AppColors.present
                    : AppColors.absent,
              ),
              const SizedBox(width: 8),
              Text(res['success'] == true
                  ? "Admin WhatsApp Dispatched"
                  : "Dispatch Status Notice"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                res['message'] ?? 'Report dispatch operation completed.',
                style: const TextStyle(fontSize: 13),
              ),
              if (res['totalClasses'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Classes Included: ${res['totalClasses']}",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
              if (res['recipientPhone'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  "Recipient Mobile: ${res['recipientPhone']}",
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              if (res['note'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    res['note'],
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingAdminReport = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error triggering admin report: $e"),
            backgroundColor: AppColors.absent,
          ),
        );
      }
    }
  }

  void _openAddRecipientDialog([AuthorizedRecipient? existing]) {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final roleCtrl =
        TextEditingController(text: existing?.designation ?? 'Class Advisor');
    final phoneCtrl =
        TextEditingController(text: existing?.phoneNumber ?? '+91');
    String reportTypes = existing?.reportTypes ?? 'both';
    final selectedClassIds = (existing?.assignedClassIds ?? []).toSet();
    bool consent = existing?.consentObtained ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing
              ? "Edit Authorized Recipient"
              : "Add Authorized Report Recipient"),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: "Staff Name",
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(
                        labelText: "Designation / Role",
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: "WhatsApp Phone Number (E.164)",
                      hintText: "+919876543210",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  const Text("Report Type Preference:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'both',
                        groupValue: reportTypes,
                        onChanged: (v) =>
                            setDialogState(() => reportTypes = v!),
                      ),
                      const Text("Both (2 PM & Final)",
                          style: TextStyle(fontSize: 12)),
                      Radio<String>(
                        value: 'final',
                        groupValue: reportTypes,
                        onChanged: (v) =>
                            setDialogState(() => reportTypes = v!),
                      ),
                      const Text("Final Only", style: TextStyle(fontSize: 12)),
                      Radio<String>(
                        value: 'preliminary',
                        groupValue: reportTypes,
                        onChanged: (v) =>
                            setDialogState(() => reportTypes = v!),
                      ),
                      const Text("2 PM Only", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                      "Assigned Classes (Select classes or leave empty for All):",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView(
                      children: _allClasses.map((cls) {
                        final isSelected = selectedClassIds.contains(cls.id);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(cls.className,
                              style: const TextStyle(fontSize: 12)),
                          subtitle: Text(cls.department,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary)),
                          value: isSelected,
                          onChanged: (bool? val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedClassIds.add(cls.id);
                              } else {
                                selectedClassIds.remove(cls.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        "Staff consent obtained for WhatsApp delivery",
                        style: TextStyle(fontSize: 11)),
                    value: consent,
                    onChanged: (v) => setDialogState(() => consent = v ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Please enter a valid staff name and phone number.")),
                  );
                  return;
                }

                final assignedNames = _allClasses
                    .where((c) => selectedClassIds.contains(c.id))
                    .map((c) => c.className)
                    .toList();

                final rec = AuthorizedRecipient(
                  id: existing?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  designation: roleCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  assignedClassIds: selectedClassIds.toList(),
                  assignedClassNames: assignedNames.isEmpty
                      ? ['All College Classes']
                      : assignedNames,
                  reportTypes: reportTypes,
                  active: existing?.active ?? true,
                  consentObtained: consent,
                );

                await _service.saveAuthorizedRecipient(rec);
                final updatedRecs = await _service.getAuthorizedRecipients();
                if (mounted) {
                  setState(() => _authorizedRecipients = updatedRecs);
                }
                Navigator.pop(ctx);
              },
              child: Text(isEditing ? "Save Changes" : "Add Recipient"),
            ),
          ],
        ),
      ),
    );
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
                "WhatsApp Attendance Alerts Configuration",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: "API Settings"),
            Tab(icon: Icon(Icons.schedule), text: "Report Scheduling"),
            Tab(icon: Icon(Icons.people_alt), text: "Authorized Recipients"),
            Tab(icon: Icon(Icons.code), text: "Meta Templates"),
          ],
        ),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, color: Colors.white),
              label: const Text("Save Config",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildApiSettingsTab(),
                _buildReportSchedulingTab(),
                _buildRecipientsTab(),
                _buildTemplatesTab(),
              ],
            ),
    );
  }

  // --- TAB 1: API Configuration & Testing ---
  Widget _buildApiSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(
            "Personal WhatsApp Attendance Automation Active",
            "Attendance reports with PDF & Excel attachments are automated via your personal WhatsApp daemon.",
            Icons.verified,
          ),
          const SizedBox(height: 16),
          _card(
            title: "Personal WhatsApp Worker (Active Sender)",
            icon: Icons.chat_bubble_outline,
            children: [
              const Text(
                "Personal WhatsApp automation is powered by the whatsapp-service daemon using whatsapp-web.js. Daily attendance reports (text summary, PDF document, and Excel spreadsheet) are sent directly to the administrator.",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.present.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.present.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.present, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Personal WhatsApp Worker Ready",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.present),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "LocalAuth session persistence enabled. Automated schedule fires Monday–Saturday at 2:00 PM IST (14:00) with instant test dispatch support.",
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: "Meta API Credentials (Legacy / Cloud API)",
            icon: Icons.vpn_key_outlined,
            children: [
              TextField(
                controller: _phoneIdCtrl,
                decoration: const InputDecoration(
                  labelText: "WhatsApp Business Phone Number ID",
                  hintText: "100000000000000",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _businessAccountCtrl,
                decoration: const InputDecoration(
                  labelText: "WhatsApp Business Account ID (WABA ID)",
                  hintText: "200000000000000",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiVersionCtrl,
                decoration: const InputDecoration(
                  labelText: "Meta Graph API Version",
                  hintText: "v21.0",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              // Security Token Indicator (Always masked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 20, color: AppColors.present),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "Meta System User Access Token: ••••••••••••••••••••••••••••••••",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(height: 2),
                          Text(
                              "Access tokens and app secrets are stored strictly in backend server environment variables (WHATSAPP_ACCESS_TOKEN) and are never exposed to client browsers.",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: "Test WhatsApp Connection",
            icon: Icons.send_to_mobile,
            children: [
              const Text(
                "Send an instantaneous test message to verify that your Meta Cloud API connection, Phone Number ID, and token authorization are operating properly.",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: "Test WhatsApp Phone Number",
                        hintText: "+919876543200",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF075E54),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 16),
                    label: const Text("Test Message"),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Automated Report Scheduling ---
  Widget _buildReportSchedulingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(
            "Automated Report Delivery Schedule (${_formatTimeDisplay(_reportTime)})",
            "Configure scheduled report dispatch times, session preferences, and designated Administrator destination.",
            Icons.access_time,
          ),
          const SizedBox(height: 16),
          _card(
            title: "Administrator WhatsApp Destination & Instant Trigger",
            icon: Icons.admin_panel_settings_outlined,
            children: [
              const Text(
                "Automated daily attendance reports are delivered directly to the Administrator via WhatsApp at the scheduled time. Enter your WhatsApp number below with country code (e.g. +91):",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Administrator Name",
                  hintText: "Dr. Ramesh Sharma (Administrator)",
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: "Administrator WhatsApp Mobile Number",
                  hintText: "+919876543200",
                  prefixIcon: Icon(Icons.phone_android_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF075E54),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onPressed: _isSendingAdminReport
                          ? null
                          : _testConsolidatedAdminReport,
                      icon: _isSendingAdminReport
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_to_mobile, size: 18),
                      label: Text(
                        _isSendingAdminReport
                            ? "Compiling & Dispatching Report..."
                            : "Send Daily Attendance Report to Admin Now (Instant Test)",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: "Daily Scheduled Reports",
            icon: Icons.alarm,
            children: [
              SwitchListTile(
                title: const Text("Enable Automatic Daily WhatsApp Reports",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                    "Automatically generate and dispatch attendance reports at the scheduled time.",
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                value: _reportsEnabled,
                activeThumbColor: const Color(0xFF075E54),
                onChanged: (v) => setState(() => _reportsEnabled = v),
              ),
              const Divider(),
              ListTile(
                title: const Text("Report Generation Time:",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
                    "Automated daily dispatch scheduled for: ${_formatTimeDisplay(_reportTime)}",
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: OutlinedButton.icon(
                  icon: const Icon(Icons.timer, size: 16),
                  label: Text(_formatTimeDisplay(_reportTime)),
                  onPressed: () async {
                    final initial = _parseTimeOfDay(_reportTime);
                    final time = await showTimePicker(
                      context: context,
                      initialTime: initial,
                    );
                    if (time != null) {
                      setState(() {
                        _reportTime =
                            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: Text(
                    "Send Preliminary Report at ${_formatTimeDisplay(_reportTime)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                    "Dispatches morning attendance and available afternoon attendance with clear [PRELIMINARY] status marker.",
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                value: _sendPreliminary,
                activeThumbColor: const Color(0xFF075E54),
                onChanged: (v) => setState(() => _sendPreliminary = v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("Send Final Report on Afternoon Completion",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                    "Automatically triggers final reconciliation report once afternoon attendance session is marked closed.",
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                value: _sendFinalOnCompletion,
                activeThumbColor: const Color(0xFF075E54),
                onChanged: (v) => setState(() => _sendFinalOnCompletion = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: "Absence Triggers & Thresholds",
            icon: Icons.tune,
            children: [
              SwitchListTile(
                title: const Text("Immediate Absence Alert to Class Advisors",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                    "Triggers approved WhatsApp alert to class advisor when a student is marked ABSENT.",
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                value: _immediateEnabled,
                activeThumbColor: const Color(0xFF075E54),
                onChanged: (v) => setState(() => _immediateEnabled = v),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text("Repeated-Absence Summary Alerts to Dean",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                    "Notifies Dean of Placement & Training when students cross the repeated absence threshold.",
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                value: _summaryEnabled,
                activeThumbColor: const Color(0xFF075E54),
                onChanged: (v) => setState(() => _summaryEnabled = v),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Qualifying Absence Threshold:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("$_threshold Absences",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.absent)),
                ],
              ),
              Slider(
                value: _threshold.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: "$_threshold absences",
                activeColor: const Color(0xFF075E54),
                onChanged: (v) => setState(() => _threshold = v.toInt()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Authorized Recipients Management ---
  Widget _buildRecipientsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _banner(
                "Authorized WhatsApp Report Recipients",
                "Manage verified staff, class coordinators, and college leadership eligible for attendance delivery.",
                Icons.people,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recipients (${_authorizedRecipients.length})",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _openAddRecipientDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add Recipient"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_authorizedRecipients.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                    "No authorized recipients configured. Click Add Recipient to get started."),
              ),
            )
          else
            ..._authorizedRecipients.map((rec) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: rec.active
                        ? const Color(0xFF075E54).withValues(alpha: 0.12)
                        : AppColors.unmarked,
                    child: Icon(Icons.person,
                        color: rec.active
                            ? const Color(0xFF075E54)
                            : AppColors.textSecondary),
                  ),
                  title: Row(
                    children: [
                      Text(rec.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rec.active
                              ? AppColors.present.withValues(alpha: 0.1)
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rec.active ? "Active" : "Inactive",
                          style: TextStyle(
                              fontSize: 10,
                              color: rec.active
                                  ? AppColors.present
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("${rec.designation} • ${rec.maskedPhoneNumber}",
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text("Classes: ${rec.assignedClassNames.join(', ')}",
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary)),
                      Text("Reports: ${rec.reportTypes.toUpperCase()}",
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rec.active,
                        activeThumbColor: const Color(0xFF075E54),
                        onChanged: (val) async {
                          await _service.toggleRecipientStatus(rec.id, val);
                          final updated =
                              await _service.getAuthorizedRecipients();
                          setState(() => _authorizedRecipients = updated);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openAddRecipientDialog(rec),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.absent),
                        onPressed: () async {
                          await _service.deleteAuthorizedRecipient(rec.id);
                          final updated =
                              await _service.getAuthorizedRecipients();
                          setState(() => _authorizedRecipients = updated);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- TAB 4: Meta Approved Templates ---
  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(
            "Meta WhatsApp Cloud API Approved Message Templates",
            "Configure template names corresponding to approved templates in Meta WhatsApp Business Manager.",
            Icons.description,
          ),
          const SizedBox(height: 16),
          _card(
            title: "Template Mappings",
            icon: Icons.code,
            children: [
              TextField(
                controller: _reportTemplateCtrl,
                decoration: const InputDecoration(
                  labelText: "Daily Attendance Report Template Name",
                  hintText: "attendance_daily_report",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _absenceTemplateCtrl,
                decoration: const InputDecoration(
                  labelText: "Immediate Absence Alert Template Name",
                  hintText: "attendance_absence_alert",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summaryTemplateCtrl,
                decoration: const InputDecoration(
                  labelText: "Repeated-Absence Summary Template Name",
                  hintText: "attendance_repeat_summary",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            title: "Official Meta Template Format Specification",
            icon: Icons.info_outline,
            children: const [
              Text(
                "Template 1: attendance_daily_report (Category: UTILITY)\n"
                "Body Parameters:\n"
                "{{1}} - Date (YYYY-MM-DD)\n"
                "{{2}} - Department & Class Name\n"
                "{{3}} - Morning Attendance (Total, Present, Absent, OD, Not Marked, %)\n"
                "{{4}} - Afternoon Attendance (Total, Present, Absent, OD, Bunk, Not Marked, %)\n"
                "{{5}} - Comparison & Report Status (PRELIMINARY / FINAL)\n"
                "{{6}} - Timestamp in IST\n\n"
                "Note: Outside the 24-hour customer service window, Meta Cloud API requires pre-approved templates for business-initiated notifications.",
                style: TextStyle(
                    fontSize: 11.5, height: 1.4, color: AppColors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner(String title, String subtitle, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF075E54),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
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
            children: [
              Icon(icon, size: 18, color: const Color(0xFF075E54)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
