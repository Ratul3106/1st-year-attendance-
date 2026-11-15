import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/services/advanced_analytics_export_service.dart';

enum ExportFormatType {
  excel,
  pdf,
  csv,
}

enum CsvExportCategory {
  studentPerformance,
  bunkLeaderboard,
  deptClassComparison,
  shiftDiscrepancy,
}

/// Modal dialog for configuring and downloading multi-format analytics reports (Excel, PDF, CSV).
class AnalyticsExportDialog extends StatefulWidget {
  final AdvancedAnalyticsResult data;
  final AnalyticsFilterState filter;

  const AnalyticsExportDialog({
    super.key,
    required this.data,
    required this.filter,
  });

  static Future<void> show(
    BuildContext context, {
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AnalyticsExportDialog(data: data, filter: filter),
    );
  }

  @override
  State<AnalyticsExportDialog> createState() => _AnalyticsExportDialogState();
}

class _AnalyticsExportDialogState extends State<AnalyticsExportDialog> {
  ExportFormatType _selectedFormat = ExportFormatType.excel;
  CsvExportCategory _selectedCsvCategory = CsvExportCategory.studentPerformance;
  bool _isGenerating = false;
  String? _statusMessage;

  Future<void> _handleExport() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = "Generating export file...";
    });

    try {
      switch (_selectedFormat) {
        case ExportFormatType.excel:
          setState(() => _statusMessage = "Building multi-sheet Excel workbook...");
          await AdvancedAnalyticsExportService.downloadExcel(
            data: widget.data,
            filter: widget.filter,
          );
          break;

        case ExportFormatType.pdf:
          setState(() => _statusMessage = "Compiling executive PDF document...");
          await AdvancedAnalyticsExportService.downloadPdf(
            data: widget.data,
            filter: widget.filter,
          );
          break;

        case ExportFormatType.csv:
          setState(() => _statusMessage = "Formatting CSV data...");
          switch (_selectedCsvCategory) {
            case CsvExportCategory.studentPerformance:
              final csv = AdvancedAnalyticsExportService.generateStudentPerformanceCsv(
                data: widget.data,
                filter: widget.filter,
              );
              await AdvancedAnalyticsExportService.downloadCsv(
                csvContent: csv,
                baseName: "Student_Performance_${widget.filter.department}",
              );
              break;

            case CsvExportCategory.bunkLeaderboard:
              final csv = AdvancedAnalyticsExportService.generateBunkRankingsCsv(
                data: widget.data,
                filter: widget.filter,
              );
              await AdvancedAnalyticsExportService.downloadCsv(
                csvContent: csv,
                baseName: "Bunk_Leaderboard_${widget.filter.department}",
              );
              break;

            case CsvExportCategory.deptClassComparison:
              final csv = AdvancedAnalyticsExportService.generateDepartmentComparisonCsv(
                data: widget.data,
                filter: widget.filter,
              );
              await AdvancedAnalyticsExportService.downloadCsv(
                csvContent: csv,
                baseName: "Dept_Class_Comparison_${widget.filter.academicYear}",
              );
              break;

            case CsvExportCategory.shiftDiscrepancy:
              final csv = AdvancedAnalyticsExportService.generateShiftDiscrepancyCsv(
                data: widget.data,
                filter: widget.filter,
              );
              await AdvancedAnalyticsExportService.downloadCsv(
                csvContent: csv,
                baseName: "Morning_vs_Afternoon_${widget.filter.department}",
              );
              break;
          }
          break;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export completed successfully: ${_selectedFormat.name.toUpperCase()} file ready."),
            backgroundColor: AppColors.present,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to generate export: $e"),
            backgroundColor: AppColors.absent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Export Analytics & Reports",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          "Export data reflecting active filters (${widget.filter.department} • ${widget.filter.academicYear})",
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              // Active Filters Summary Pill Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Applied Export Scope:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _scopePill("Academic Year", widget.filter.academicYear),
                        _scopePill("Department", widget.filter.department),
                        _scopePill("Class", widget.filter.classId),
                        _scopePill("Month", widget.filter.month == null ? "All Year" : "Month ${widget.filter.month}"),
                        _scopePill("Session", widget.filter.sessionFilter),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Format Selection Heading
              const Text(
                "Select Export Format:",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              // Format Options List
              _formatOptionCard(
                type: ExportFormatType.excel,
                title: "Excel Consolidated Workbook (.xlsx)",
                subtitle: "Full 5-sheet workbook: Executive Overview, Performance Roster, Bunk Leaderboard, Shift Analysis, and Section Comparisons.",
                badge: "Full Analytical Package",
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF2E7D32),
              ),

              const SizedBox(height: 10),

              _formatOptionCard(
                type: ExportFormatType.pdf,
                title: "Institutional Executive Report (.pdf)",
                subtitle: "Official Vel Tech college layout with executive KPIs, statutory risk breakdown, at-risk rosters, and sign-off blocks.",
                badge: "Formal Document",
                icon: Icons.picture_as_pdf_outlined,
                color: const Color(0xFFC62828),
              ),

              const SizedBox(height: 10),

              _formatOptionCard(
                type: ExportFormatType.csv,
                title: "Raw Tabular Data (.csv)",
                subtitle: "Standard RFC 4180 UTF-8 formatted CSV for spreadsheet processing or institutional data ingest.",
                badge: "Spreadsheet Ready",
                icon: Icons.grid_on_outlined,
                color: const Color(0xFF1565C0),
              ),

              // CSV Sub-Category Dropdown (if CSV is selected)
              if (_selectedFormat == ExportFormatType.csv) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "CSV Dataset: ",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CsvExportCategory>(
                            value: _selectedCsvCategory,
                            isDense: true,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(
                                value: CsvExportCategory.studentPerformance,
                                child: Text("All Students Performance Roster"),
                              ),
                              DropdownMenuItem(
                                value: CsvExportCategory.bunkLeaderboard,
                                child: Text("Monthly Bunk Rankings Leaderboard"),
                              ),
                              DropdownMenuItem(
                                value: CsvExportCategory.deptClassComparison,
                                child: Text("Department & Class Comparisons"),
                              ),
                              DropdownMenuItem(
                                value: CsvExportCategory.shiftDiscrepancy,
                                child: Text("Morning vs Afternoon Shift Analysis"),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCsvCategory = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Progress status message
              if (_isGenerating) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _statusMessage ?? "Preparing file...",
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _handleExport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                      _isGenerating ? "Exporting..." : "Download ${_selectedFormat.name.toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _formatOptionCard({
    required ExportFormatType type,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedFormat == type;

    return InkWell(
      onTap: _isGenerating ? null : () => setState(() => _selectedFormat = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 5.5 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopePill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }
}
