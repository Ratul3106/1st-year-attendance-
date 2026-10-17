import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  const WhatsAppSettingsScreen({super.key});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  final _service = WhatsAppNotificationService.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  late bool _immediateEnabled;
  late bool _summaryEnabled;
  late int _threshold;
  late int _windowDays;
  late TextEditingController _deanNameCtrl;
  late TextEditingController _deanPhoneCtrl;
  late TextEditingController _phoneIdCtrl;
  late TextEditingController _absenceTemplateCtrl;
  late TextEditingController _summaryTemplateCtrl;
  late List<WhatsAppRecipient> _additionalRecipients;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final s = await _service.getSettings();
    _immediateEnabled = s.immediateAlertsEnabled;
    _summaryEnabled = s.summaryAlertsEnabled;
    _threshold = s.absenceThreshold;
    _windowDays = s.reportingWindowDays;
    _deanNameCtrl = TextEditingController(text: s.deanPlacementName);
    _deanPhoneCtrl = TextEditingController(text: s.deanPlacementPhone);
    _phoneIdCtrl = TextEditingController(text: s.phoneNumberId);
    _absenceTemplateCtrl = TextEditingController(text: s.absenceTemplateName);
    _summaryTemplateCtrl = TextEditingController(text: s.summaryTemplateName);
    _additionalRecipients = List.from(s.additionalRecipients);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _deanNameCtrl.dispose();
    _deanPhoneCtrl.dispose();
    _phoneIdCtrl.dispose();
    _absenceTemplateCtrl.dispose();
    _summaryTemplateCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final current = await _service.getSettings();
    final updated = current.copyWith(
      immediateAlertsEnabled: _immediateEnabled,
      summaryAlertsEnabled: _summaryEnabled,
      absenceThreshold: _threshold,
      reportingWindowDays: _windowDays,
      deanPlacementName: _deanNameCtrl.text.trim(),
      deanPlacementPhone: _deanPhoneCtrl.text.trim(),
      phoneNumberId: _phoneIdCtrl.text.trim(),
      absenceTemplateName: _absenceTemplateCtrl.text.trim(),
      summaryTemplateName: _summaryTemplateCtrl.text.trim(),
      additionalRecipients: _additionalRecipients,
    );

    await _service.updateSettings(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("WhatsApp notification settings saved successfully."),
          backgroundColor: AppColors.present,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _addRecipientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+91');
    final roleCtrl = TextEditingController(text: 'Vice Principal');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Authorized Recipient"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Staff Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(labelText: "Designation / Role"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: "WhatsApp Phone Number (E.164)",
                hintText: "+919876543210",
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _additionalRecipients.add(WhatsAppRecipient(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    role: roleCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    active: true,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WhatsApp Notification Settings"),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, color: Colors.white),
              label: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta WhatsApp Business Header Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF075E54), // Meta WhatsApp brand color
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Meta WhatsApp Business Cloud API",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Automated attendance notifications for Class Advisors & College Leadership",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1. Notification Triggers Section
                  _sectionHeader(Icons.notifications_active_outlined, "Notification Triggers"),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("Immediate Absence Notification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text(
                            "Automatically dispatches an approved WhatsApp alert to the assigned Class Advisor when a student is saved as ABSENT.",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: _immediateEnabled,
                          activeTrackColor: AppColors.primaryLight,
                          onChanged: (v) => setState(() => _immediateEnabled = v),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text("Repeated-Absence Summary Alert", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text(
                            "Automatically compiles students reaching the absence threshold over the reporting window and notifies the Dean of Placement and Training.",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: _summaryEnabled,
                          activeTrackColor: AppColors.primaryLight,
                          onChanged: (v) => setState(() => _summaryEnabled = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Absence Threshold & Window Configuration
                  _sectionHeader(Icons.tune, "Absence Threshold & Reporting Window"),
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
                            const Text("Qualifying Absence Threshold:", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("$_threshold Absences", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.absent)),
                          ],
                        ),
                        Slider(
                          value: _threshold.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: "$_threshold absences",
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _threshold = v.toInt()),
                        ),
                        const Text(
                          "Trigger summary when student accumulates this many distinct absent sessions (default: 3).",
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Reporting Window Days:", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("$_windowDays Days", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                        Slider(
                          value: _windowDays.toDouble(),
                          min: 3,
                          max: 30,
                          divisions: 27,
                          label: "$_windowDays days",
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _windowDays = v.toInt()),
                        ),
                        const Text(
                          "Consecutive calendar days scanned for qualifying absences (development default: 7 days).",
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Authorized Recipients
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader(Icons.people_alt_outlined, "Authorized Recipients"),
                      TextButton.icon(
                        onPressed: _addRecipientDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add Recipient"),
                      ),
                    ],
                  ),
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
                        const Text(
                          "Dean of Placement & Training (Repeated-Absence Summaries):",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _deanNameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Designated Title / Name",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _deanPhoneCtrl,
                          decoration: const InputDecoration(
                            labelText: "WhatsApp Phone Number (E.164)",
                            hintText: "+919876543200",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Class Advisors (Immediate Absence Alerts):",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Automatically routed to the assigned Coordinator for the affected class via Class Assignments.",
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (_additionalRecipients.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Divider(),
                          const Text(
                            "Additional Authorized Staff Recipients:",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          ..._additionalRecipients.map((r) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${r.role} • ${r.phoneNumber}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.absent),
                                  onPressed: () => setState(() => _additionalRecipients.remove(r)),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Meta WhatsApp Cloud API Template Configuration
                  _sectionHeader(Icons.code, "Meta Cloud API Template Configuration"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _phoneIdCtrl,
                          decoration: const InputDecoration(
                            labelText: "Meta WhatsApp Phone Number ID",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _absenceTemplateCtrl,
                          decoration: const InputDecoration(
                            labelText: "Approved Immediate Absence Template Name",
                            hintText: "attendance_absence_alert",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _summaryTemplateCtrl,
                          decoration: const InputDecoration(
                            labelText: "Approved Repeated-Absence Summary Template Name",
                            hintText: "attendance_repeat_summary",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: AppColors.info, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Security Notice: WhatsApp Access Tokens, Webhook Verify Tokens, and App Secrets are stored strictly on the server and are never exposed to the frontend.",
                                  style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: const Text("Save WhatsApp Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
