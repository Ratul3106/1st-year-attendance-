import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/services/attendance_report_generator_service.dart';
import 'package:student_attendance_system/widgets/attendance_report_preview_dialog.dart';

class DownloadReportDialog extends StatefulWidget {
  final List<ClassModel> classes;
  final String? initialClassId;
  final DateTime? initialDate;

  const DownloadReportDialog({
    super.key,
    required this.classes,
    this.initialClassId,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ClassModel> classes,
    String? initialClassId,
    DateTime? initialDate,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DownloadReportDialog(
        classes: classes,
        initialClassId: initialClassId,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<DownloadReportDialog> createState() => _DownloadReportDialogState();
}

class _DownloadReportDialogState extends State<DownloadReportDialog> {
  final _reportService = AttendanceReportGeneratorService();

  late String _selectedClassId;
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedSession = 'Both'; // 'Both', 'Morning', 'Afternoon'
  String _selectedFormat = 'pdf'; // 'pdf' or 'excel'

  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);

    if (widget.initialClassId != null &&
        widget.initialClassId != 'All' &&
        widget.classes.any((c) => c.id == widget.initialClassId)) {
      _selectedClassId = widget.initialClassId!;
    } else {
      _selectedClassId = 'All';
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
      helpText: 'Select End Date',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _errorMessage = null;
      });
    }
  }

  void _applyQuickPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _errorMessage = null;
      switch (preset) {
        case 'Today':
          _startDate = today;
          _endDate = today;
          break;
        case 'Yesterday':
          final y = today.subtract(const Duration(days: 1));
          _startDate = y;
          _endDate = y;
          break;
        case 'This Week':
          // Monday to today
          final monday = today.subtract(Duration(days: today.weekday - 1));
          _startDate = monday;
          _endDate = today;
          break;
        case 'This Month':
          final firstDay = DateTime(today.year, today.month, 1);
          _startDate = firstDay;
          _endDate = today;
          break;
      }
    });
  }

  Future<void> _handleShowReport() async {
    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _errorMessage = 'Start date cannot be after end date.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    ClassModel? targetClass;
    if (_selectedClassId != 'All') {
      try {
        targetClass =
            widget.classes.firstWhere((c) => c.id == _selectedClassId);
      } catch (_) {
        targetClass = null;
      }
    }

    final config = AttendanceReportConfig(
      selectedClass: targetClass,
      startDate: _startDate,
      endDate: _endDate,
      sessionFilter: _selectedSession,
      format: _selectedFormat,
    );

    try {
      final reportData = await _reportService.fetchReportData(config);
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });

      // Close this configuration dialog
      Navigator.of(context).pop();

      // Open the comprehensive Report Preview Dialog
      AttendanceReportPreviewDialog.show(context, data: reportData);
    } on NoAttendanceDataException catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage =
              'Report generation failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _handleDownload() async {
    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _errorMessage = 'Start date cannot be after end date.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    ClassModel? targetClass;
    if (_selectedClassId != 'All') {
      try {
        targetClass = widget.classes.firstWhere((c) => c.id == _selectedClassId);
      } catch (_) {
        targetClass = null;
      }
    }

    final config = AttendanceReportConfig(
      selectedClass: targetClass,
      startDate: _startDate,
      endDate: _endDate,
      sessionFilter: _selectedSession,
      format: _selectedFormat,
    );

    try {
      final filename = await _reportService.downloadReport(config);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report successfully exported:\n$filename',
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
    } on NoAttendanceDataException catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Download failed: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_outlined,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Download Attendance Report",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Export attendance records, analytics & categorized lists",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content Body (Scrollable for smaller screens)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.absent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.absent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.absent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.absent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 1. Target Class Selection
                      const Text(
                        "1. Select Class",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClassId,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String>(
                                value: 'All',
                                child: Row(
                                  children: [
                                    Icon(Icons.domain, size: 18, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      "All Classes (Entire College)",
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              ...widget.classes.map((cls) {
                                return DropdownMenuItem<String>(
                                  value: cls.id,
                                  child: Text(
                                    "${cls.className} (${cls.department} - ${cls.academicYear})",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: _isGenerating
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedClassId = val;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 2. Date Range Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "2. Date Range",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            children: [
                              _presetChip("Today"),
                              _presetChip("Yesterday"),
                              _presetChip("This Week"),
                              _presetChip("This Month"),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _datePickerTile(
                              label: "Start Date",
                              date: _startDate,
                              dateFormat: dateFormat,
                              onTap: _pickStartDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _datePickerTile(
                              label: "End Date",
                              date: _endDate,
                              dateFormat: dateFormat,
                              onTap: _pickEndDate,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 3. Attendance Session Selection
                      const Text(
                        "3. Attendance Session",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _sessionChoiceChip(
                              keyName: 'Both',
                              title: 'Both Sessions',
                              subtitle: 'Morning & Afternoon',
                              icon: Icons.calendar_view_day_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _sessionChoiceChip(
                              keyName: 'Morning',
                              title: 'Morning Session',
                              subtitle: 'AM Only',
                              icon: Icons.wb_sunny_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _sessionChoiceChip(
                              keyName: 'Afternoon',
                              title: 'Afternoon Session',
                              subtitle: 'PM Only (Incl. Bunks)',
                              icon: Icons.brightness_6_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 4. File Export Format Selection
                      const Text(
                        "4. Report Format",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _formatChoiceCard(
                              formatKey: 'pdf',
                              title: 'PDF Document (.pdf)',
                              description: 'Printable executive report with analytics & student tables',
                              badgeText: 'PDF',
                              badgeColor: const Color(0xFFD32F2F),
                              icon: Icons.picture_as_pdf_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _formatChoiceCard(
                              formatKey: 'excel',
                              title: 'Excel Workbook (.xlsx)',
                              description: '7 structured sheets with Present, Absent, OD, Bunks & Unmarked',
                              badgeText: 'XLSX',
                              badgeColor: const Color(0xFF2E7D32),
                              icon: Icons.table_chart_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  // Direct Download Option
                  OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _handleDownload,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: Text("Direct ${_selectedFormat.toUpperCase()}"),
                  ),
                  const SizedBox(width: 10),
                  // Primary Show Report Button
                  IntrinsicWidth(
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _handleShowReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.visibility_outlined, size: 18),
                      label: Text(
                        _isGenerating ? "Loading Report..." : "Show Report",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label) {
    return InkWell(
      onTap: _isGenerating ? null : () => _applyQuickPreset(label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime date,
    required DateFormat dateFormat,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isGenerating ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionChoiceChip({
    required String keyName,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedSession == keyName;
    return InkWell(
      onTap: _isGenerating ? null : () => setState(() => _selectedSession = keyName),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatChoiceCard({
    required String formatKey,
    required String title,
    required String description,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
  }) {
    final isSelected = _selectedFormat == formatKey;
    return InkWell(
      onTap: _isGenerating ? null : () => setState(() => _selectedFormat = formatKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: badgeColor, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: formatKey,
              groupValue: _selectedFormat,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: _isGenerating
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedFormat = val);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
