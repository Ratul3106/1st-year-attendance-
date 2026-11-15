import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/utils/file_download_helper.dart';

/// Service responsible for multi-format export (Excel .xlsx, PDF .pdf, CSV .csv)
/// of the Advanced Attendance Analytics & Reports Module.
class AdvancedAnalyticsExportService {
  static const String _collegeName =
      "VEL TECH MULTI TECH Dr. RANGARAJAN Dr. SAKUNTHALA ENGINEERING COLLEGE";
  static const String _collegeSub =
      "An Autonomous Institution  |  Approved by AICTE  |  Affiliated to Anna University, Chennai";

  static const List<String> _monthNames = [
    'All Year',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ===========================================================================
  // 1. EXCEL WORKBOOK EXPORT (.xlsx)
  // ===========================================================================

  /// Generates a professional 5-sheet Excel workbook.
  ///
  /// Sheet 1: Executive Overview
  /// Sheet 2: Student Performance
  /// Sheet 3: Monthly Bunk Leaderboard
  /// Sheet 4: Morning vs Afternoon
  /// Sheet 5: Department & Class Comparison
  static Future<Uint8List> generateExcelWorkbook({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) async {
    final excel = Excel.createExcel();
    final overview = data.overview;
    final genTimeStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final monthStr = filter.month == null
        ? "All Months (Annual)"
        : "${_monthNames[filter.month!]} ${filter.year}";
    final sessionScope = filter.sessionFilter.toUpperCase();
    final dateRangeStr = (filter.customStartDate != null && filter.customEndDate != null)
        ? "${DateFormat('yyyy-MM-dd').format(filter.customStartDate!)} to ${DateFormat('yyyy-MM-dd').format(filter.customEndDate!)}"
        : "Standard Academic Range";

    // -------------------------------------------------------------------------
    // Sheet 1: Executive Overview
    // -------------------------------------------------------------------------
    final sheet1 = excel['Executive Overview'];

    sheet1.appendRow([TextCellValue(_collegeName)]);
    sheet1.appendRow([TextCellValue(_collegeSub)]);
    sheet1.appendRow([TextCellValue("ADVANCED ATTENDANCE ANALYTICS — EXECUTIVE OVERVIEW")]);
    sheet1.appendRow([TextCellValue("Generated On:"), TextCellValue(genTimeStr)]);
    sheet1.appendRow([TextCellValue("")]);

    // Applied Filters
    sheet1.appendRow([TextCellValue("--- APPLIED ANALYTICS FILTERS ---")]);
    sheet1.appendRow([TextCellValue("Academic Year:"), TextCellValue(filter.academicYear)]);
    sheet1.appendRow([TextCellValue("Department:"), TextCellValue(filter.department)]);
    sheet1.appendRow([TextCellValue("Class / Section:"), TextCellValue(filter.classId)]);
    sheet1.appendRow([TextCellValue("Reporting Month / Period:"), TextCellValue(monthStr)]);
    sheet1.appendRow([TextCellValue("Session Scope:"), TextCellValue(sessionScope)]);
    sheet1.appendRow([TextCellValue("Custom Date Range:"), TextCellValue(dateRangeStr)]);
    sheet1.appendRow([TextCellValue("")]);

    // KPI Metrics Table
    sheet1.appendRow([
      TextCellValue("Metric Description"),
      TextCellValue("Calculated Value"),
      TextCellValue("Unit / Scope Note"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total Enrolled Students"),
      IntCellValue(overview.totalEnrolledStudents),
      TextCellValue("Enrolled in selected filter scope"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total Conducted Sessions (Closed)"),
      IntCellValue(overview.totalConductedSessions),
      TextCellValue("Only finalized/closed sessions"),
    ]);
    sheet1.appendRow([
      TextCellValue("Average Attendance Percentage"),
      DoubleCellValue(double.parse(overview.averageAttendancePercentage.toStringAsFixed(2))),
      TextCellValue("Formula: ((Present + OD) / Conducted) * 100"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total Present Records"),
      IntCellValue(overview.totalPresentRecords),
      TextCellValue("Attended sessions"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total Absent Records"),
      IntCellValue(overview.totalAbsentRecords),
      TextCellValue("Unauthorized absences"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total On-Duty (OD) Records"),
      IntCellValue(overview.totalOdRecords),
      TextCellValue("Institutional duty / sports"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total Bunk Records"),
      IntCellValue(overview.totalBunkRecords),
      TextCellValue("Afternoon session bunks"),
    ]);
    sheet1.appendRow([
      TextCellValue("Total Unmarked Records"),
      IntCellValue(overview.totalUnmarkedRecords),
      TextCellValue("Penalized missing records in closed sessions"),
    ]);
    sheet1.appendRow([TextCellValue("")]);

    // Attendance Risk Distribution
    sheet1.appendRow([TextCellValue("--- ATTENDANCE RISK DISTRIBUTION ---")]);
    sheet1.appendRow([
      TextCellValue("Risk Category"),
      TextCellValue("Student Count"),
      TextCellValue("Institutional Threshold"),
    ]);
    sheet1.appendRow([
      TextCellValue("Good Standing"),
      IntCellValue(overview.studentsGoodStandingCount),
      TextCellValue("Attendance >= 75.0%"),
    ]);
    sheet1.appendRow([
      TextCellValue("Warning Tier"),
      IntCellValue(overview.studentsBelow75Count),
      TextCellValue("Attendance 65.0% - 74.9%"),
    ]);
    sheet1.appendRow([
      TextCellValue("High Risk Tier"),
      IntCellValue(overview.studentsBelow65Count),
      TextCellValue("Attendance 50.0% - 64.9%"),
    ]);
    sheet1.appendRow([
      TextCellValue("Critical Tier"),
      IntCellValue(overview.studentsBelow50Count),
      TextCellValue("Attendance < 50.0%"),
    ]);
    sheet1.appendRow([TextCellValue("")]);

    // Institutional Highlights
    sheet1.appendRow([TextCellValue("--- SECTION PERFORMANCE HIGHLIGHTS ---")]);
    sheet1.appendRow([
      TextCellValue("Highest Attendance Class:"),
      TextCellValue(overview.highestAttendanceClassName),
      DoubleCellValue(double.parse(overview.highestAttendanceClassPercentage.toStringAsFixed(1))),
      TextCellValue("%"),
    ]);
    sheet1.appendRow([
      TextCellValue("Lowest Attendance Class:"),
      TextCellValue(overview.lowestAttendanceClassName),
      DoubleCellValue(double.parse(overview.lowestAttendanceClassPercentage.toStringAsFixed(1))),
      TextCellValue("%"),
    ]);
    sheet1.appendRow([
      TextCellValue("Highest Bunk Class:"),
      TextCellValue(overview.highestBunkClassName),
      IntCellValue(overview.highestBunkCount),
      TextCellValue("bunks"),
    ]);

    _applyColumnWidths(sheet1, [36, 24, 45, 15]);

    // -------------------------------------------------------------------------
    // Sheet 2: Student Performance
    // -------------------------------------------------------------------------
    final sheet2 = excel['Student Performance'];

    sheet2.appendRow([TextCellValue("STUDENT ATTENDANCE PERFORMANCE ROSTER")]);
    sheet2.appendRow([
      TextCellValue("Scope:"),
      TextCellValue("Dept: ${filter.department}  |  Class: ${filter.classId}  |  Year: ${filter.academicYear}"),
    ]);
    sheet2.appendRow([TextCellValue("")]);

    sheet2.appendRow([
      TextCellValue("Rank"),
      TextCellValue("Register Number"),
      TextCellValue("Student Full Name"),
      TextCellValue("Department"),
      TextCellValue("Class / Section"),
      TextCellValue("Conducted Sessions"),
      TextCellValue("Present Count"),
      TextCellValue("Absent Count"),
      TextCellValue("OD Count"),
      TextCellValue("Bunk Count"),
      TextCellValue("Unmarked Count"),
      TextCellValue("Attendance %"),
      TextCellValue("Strict % (Excl OD)"),
      TextCellValue("Risk Level"),
    ]);

    for (int i = 0; i < data.studentPerformanceList.length; i++) {
      final s = data.studentPerformanceList[i];
      sheet2.appendRow([
        IntCellValue(i + 1),
        TextCellValue(s.registerNumber),
        TextCellValue(s.fullName),
        TextCellValue(s.department),
        TextCellValue(s.className),
        IntCellValue(s.totalConductedSessions),
        IntCellValue(s.presentCount),
        IntCellValue(s.absentCount),
        IntCellValue(s.odCount),
        IntCellValue(s.bunkCount),
        IntCellValue(s.unmarkedCount),
        DoubleCellValue(double.parse(s.attendancePercentage.toStringAsFixed(2))),
        DoubleCellValue(double.parse(s.strictAttendancePercentage.toStringAsFixed(2))),
        TextCellValue(_formatRiskLevel(s.riskLevel)),
      ]);
    }

    _applyColumnWidths(sheet2, [8, 16, 26, 10, 14, 14, 10, 10, 8, 8, 12, 14, 16, 14]);

    // -------------------------------------------------------------------------
    // Sheet 3: Monthly Bunk Leaderboard
    // -------------------------------------------------------------------------
    final sheet3 = excel['Monthly Bunk Leaderboard'];

    sheet3.appendRow([TextCellValue("MONTHLY STUDENT BUNK LEADERBOARD (HIGHEST TO LOWEST)")]);
    sheet3.appendRow([
      TextCellValue("Scope:"),
      TextCellValue("Dept: ${filter.department}  |  Year: ${filter.academicYear}"),
    ]);
    sheet3.appendRow([TextCellValue("")]);

    sheet3.appendRow([
      TextCellValue("Rank"),
      TextCellValue("Register Number"),
      TextCellValue("Student Full Name"),
      TextCellValue("Class / Section"),
      TextCellValue("Department"),
      TextCellValue("Jan"),
      TextCellValue("Feb"),
      TextCellValue("Mar"),
      TextCellValue("Apr"),
      TextCellValue("May"),
      TextCellValue("Jun"),
      TextCellValue("Jul"),
      TextCellValue("Aug"),
      TextCellValue("Sep"),
      TextCellValue("Oct"),
      TextCellValue("Nov"),
      TextCellValue("Dec"),
      TextCellValue("Total Bunks"),
      TextCellValue("Current Mo"),
      TextCellValue("Previous Mo"),
      TextCellValue("MoM Delta (Δ)"),
      TextCellValue("Overall Att %"),
      TextCellValue("Risk Tier"),
    ]);

    for (final item in data.bunkRankings) {
      sheet3.appendRow([
        IntCellValue(item.rank),
        TextCellValue(item.registerNumber),
        TextCellValue(item.fullName),
        TextCellValue(item.className),
        TextCellValue(item.department),
        IntCellValue(item.monthlyBunkBreakdown[1] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[2] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[3] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[4] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[5] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[6] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[7] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[8] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[9] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[10] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[11] ?? 0),
        IntCellValue(item.monthlyBunkBreakdown[12] ?? 0),
        IntCellValue(item.totalBunkCount),
        IntCellValue(item.currentMonthBunks),
        IntCellValue(item.previousMonthBunks),
        IntCellValue(item.monthToMonthDelta),
        DoubleCellValue(double.parse(item.attendancePercentage.toStringAsFixed(1))),
        TextCellValue(_formatRiskLevel(item.riskLevel)),
      ]);
    }

    _applyColumnWidths(sheet3, [8, 16, 26, 14, 10, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 12, 12, 12, 14, 14, 14]);

    // -------------------------------------------------------------------------
    // Sheet 4: Morning vs Afternoon
    // -------------------------------------------------------------------------
    final sheet4 = excel['Morning vs Afternoon'];

    sheet4.appendRow([TextCellValue("MORNING VS AFTERNOON SHIFT ATTENDANCE ANALYSIS")]);
    sheet4.appendRow([TextCellValue("Generated On:"), TextCellValue(genTimeStr)]);
    sheet4.appendRow([TextCellValue("")]);

    // Aggregate Shift Overview
    int mConducted = 0;
    int mPresent = 0;
    int aConducted = 0;
    int aPresent = 0;
    int aBunk = 0;
    int totalShiftDropoffs = 0;

    for (final s in data.studentPerformanceList) {
      mConducted += s.morningConducted;
      mPresent += s.morningPresent;
      aConducted += s.afternoonConducted;
      aPresent += s.afternoonPresent;
      aBunk += s.afternoonBunk;
      totalShiftDropoffs += s.afternoonShiftDiscrepancyCount;
    }

    final mPct = mConducted > 0 ? (mPresent / mConducted) * 100.0 : 0.0;
    final aPct = aConducted > 0 ? (aPresent / aConducted) * 100.0 : 0.0;
    final gap = mPct - aPct;

    sheet4.appendRow([TextCellValue("--- CONSOLIDATED SHIFT METRICS ---")]);
    sheet4.appendRow([TextCellValue("Morning Sessions Conducted:"), IntCellValue(mConducted)]);
    sheet4.appendRow([TextCellValue("Morning Attendance Rate:"), DoubleCellValue(double.parse(mPct.toStringAsFixed(2))), TextCellValue("%")]);
    sheet4.appendRow([TextCellValue("Afternoon Sessions Conducted:"), IntCellValue(aConducted)]);
    sheet4.appendRow([TextCellValue("Afternoon Attendance Rate:"), DoubleCellValue(double.parse(aPct.toStringAsFixed(2))), TextCellValue("%")]);
    sheet4.appendRow([TextCellValue("Afternoon Bunk Count:"), IntCellValue(aBunk), TextCellValue("bunks")]);
    sheet4.appendRow([TextCellValue("Shift Attendance Gap:"), DoubleCellValue(double.parse(gap.toStringAsFixed(2))), TextCellValue("% drop-off in afternoon")]);
    sheet4.appendRow([TextCellValue("Total Shift Drop-off Incidents:"), IntCellValue(totalShiftDropoffs), TextCellValue("Morning Present -> Afternoon Bunk/Absent")]);
    sheet4.appendRow([TextCellValue("")]);

    // Shift Student Roster
    sheet4.appendRow([TextCellValue("--- STUDENT SHIFT ATTENDANCE ROSTER ---")]);
    sheet4.appendRow([
      TextCellValue("Register Number"),
      TextCellValue("Student Name"),
      TextCellValue("Class"),
      TextCellValue("Department"),
      TextCellValue("Morning Conducted"),
      TextCellValue("Morning Present"),
      TextCellValue("Morning %"),
      TextCellValue("Afternoon Conducted"),
      TextCellValue("Afternoon Present"),
      TextCellValue("Afternoon Bunk"),
      TextCellValue("Afternoon %"),
      TextCellValue("Shift Gap %"),
      TextCellValue("Discrepancies"),
    ]);

    for (final s in data.studentPerformanceList) {
      final sMPct = s.morningConducted > 0 ? ((s.morningPresent + s.morningOd) / s.morningConducted) * 100.0 : 0.0;
      final sAPct = s.afternoonConducted > 0 ? ((s.afternoonPresent + s.afternoonOd) / s.afternoonConducted) * 100.0 : 0.0;
      final sGap = sMPct - sAPct;

      sheet4.appendRow([
        TextCellValue(s.registerNumber),
        TextCellValue(s.fullName),
        TextCellValue(s.className),
        TextCellValue(s.department),
        IntCellValue(s.morningConducted),
        IntCellValue(s.morningPresent),
        DoubleCellValue(double.parse(sMPct.toStringAsFixed(1))),
        IntCellValue(s.afternoonConducted),
        IntCellValue(s.afternoonPresent),
        IntCellValue(s.afternoonBunk),
        DoubleCellValue(double.parse(sAPct.toStringAsFixed(1))),
        DoubleCellValue(double.parse(sGap.toStringAsFixed(1))),
        IntCellValue(s.afternoonShiftDiscrepancyCount),
      ]);
    }

    _applyColumnWidths(sheet4, [16, 26, 14, 10, 16, 14, 12, 16, 14, 14, 12, 12, 14]);

    // -------------------------------------------------------------------------
    // Sheet 5: Department & Class Comparison
    // -------------------------------------------------------------------------
    final sheet5 = excel['Dept & Class Comparison'];

    sheet5.appendRow([TextCellValue("DEPARTMENT & CLASS / SECTION ATTENDANCE COMPARISONS")]);
    sheet5.appendRow([TextCellValue("Academic Year:"), TextCellValue(filter.academicYear)]);
    sheet5.appendRow([TextCellValue("")]);

    // Section 1: Department Comparisons
    sheet5.appendRow([TextCellValue("--- 1. INTER-DEPARTMENT COMPARISON ---")]);
    sheet5.appendRow([
      TextCellValue("Department"),
      TextCellValue("Enrolled"),
      TextCellValue("Conducted Sessions"),
      TextCellValue("Average %"),
      TextCellValue("Present"),
      TextCellValue("Absent"),
      TextCellValue("OD"),
      TextCellValue("Bunk"),
      TextCellValue("Bunk Rate/Student"),
      TextCellValue("Below 75%"),
      TextCellValue("Below 65%"),
      TextCellValue("Below 50%"),
    ]);

    for (final d in data.departmentComparisons) {
      sheet5.appendRow([
        TextCellValue(d.departmentName),
        IntCellValue(d.totalEnrolledStudents),
        IntCellValue(d.totalConductedSessions),
        DoubleCellValue(double.parse(d.averageAttendancePercentage.toStringAsFixed(2))),
        IntCellValue(d.totalPresent),
        IntCellValue(d.totalAbsent),
        IntCellValue(d.totalOd),
        IntCellValue(d.totalBunk),
        DoubleCellValue(double.parse(d.bunkRate.toStringAsFixed(2))),
        IntCellValue(d.studentsBelow75),
        IntCellValue(d.studentsBelow65),
        IntCellValue(d.studentsBelow50),
      ]);
    }
    sheet5.appendRow([TextCellValue("")]);

    // Section 2: Class Comparisons
    sheet5.appendRow([TextCellValue("--- 2. INTRA-DEPARTMENT SECTION COMPARISON ---")]);
    sheet5.appendRow([
      TextCellValue("Class / Section"),
      TextCellValue("Department"),
      TextCellValue("Academic Year"),
      TextCellValue("Enrolled"),
      TextCellValue("Conducted Sessions"),
      TextCellValue("Average %"),
      TextCellValue("Present"),
      TextCellValue("Absent"),
      TextCellValue("OD"),
      TextCellValue("Bunk"),
      TextCellValue("Bunk Rate/Student"),
      TextCellValue("Below 75%"),
      TextCellValue("Below 65%"),
      TextCellValue("Below 50%"),
    ]);

    for (final c in data.classComparisons) {
      sheet5.appendRow([
        TextCellValue(c.className),
        TextCellValue(c.department),
        TextCellValue(c.academicYear),
        IntCellValue(c.totalEnrolledStudents),
        IntCellValue(c.totalConductedSessions),
        DoubleCellValue(double.parse(c.averageAttendancePercentage.toStringAsFixed(2))),
        IntCellValue(c.totalPresent),
        IntCellValue(c.totalAbsent),
        IntCellValue(c.totalOd),
        IntCellValue(c.totalBunk),
        DoubleCellValue(double.parse(c.bunkRate.toStringAsFixed(2))),
        IntCellValue(c.studentsBelow75),
        IntCellValue(c.studentsBelow65),
        IntCellValue(c.studentsBelow50),
      ]);
    }

    _applyColumnWidths(sheet5, [18, 14, 14, 10, 16, 12, 10, 10, 8, 8, 16, 12, 12, 12]);

    // Clean up default sheet
    excel.delete('Sheet1');

    final encoded = excel.save();
    return Uint8List.fromList(encoded ?? []);
  }

  static void _applyColumnWidths(Sheet sheet, List<double> widths) {
    for (int col = 0; col < widths.length; col++) {
      sheet.setColumnWidth(col, widths[col]);
    }
  }

  // ===========================================================================
  // 2. PDF EXECUTIVE REPORT EXPORT (.pdf)
  // ===========================================================================

  /// Generates a professional Vel Tech institutional executive report.
  static Future<Uint8List> generatePdfReport({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) async {
    final pdf = pw.Document();
    final overview = data.overview;
    final genTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final monthStr = filter.month == null
        ? "All Months (Annual)"
        : "${_monthNames[filter.month!]} ${filter.year}";
    final sessionScope = filter.sessionFilter.toUpperCase();
    final dateRangeStr = (filter.customStartDate != null && filter.customEndDate != null)
        ? "${DateFormat('dd/MM/yyyy').format(filter.customStartDate!)} to ${DateFormat('dd/MM/yyyy').format(filter.customEndDate!)}"
        : "Standard Academic Semester";

    // Identifying low-attendance students (<75%)
    final atRiskStudents = data.studentPerformanceList
        .where((s) => s.attendancePercentage < 75.0)
        .toList()
      ..sort((a, b) => a.attendancePercentage.compareTo(b.attendancePercentage));

    // Top bunking students (top 8)
    final topBunkers = data.bunkRankings.take(8).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        header: (context) => _buildPdfHeader(),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 8),

          // Report Title Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "ADVANCED ATTENDANCE ANALYTICS & EXECUTIVE REPORT",
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  "ACADEMIC YEAR: ${filter.academicYear}",
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.amber100),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 8),

          // Metadata Information Box
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _pdfMetaItem("Department", filter.department),
                _pdfMetaItem("Class / Section", filter.classId),
                _pdfMetaItem("Reporting Period", monthStr),
                _pdfMetaItem("Date Range", dateRangeStr),
                _pdfMetaItem("Session Filter", sessionScope),
                _pdfMetaItem("Generated On", genTimeStr),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // Section 1: Executive KPI Overview
          pw.Text("1. EXECUTIVE ATTENDANCE OVERVIEW & METRICS",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),

          pw.TableHelper.fromTextArray(
            headers: [
              "Enrolled",
              "Conducted Sessions",
              "Avg Attendance %",
              "Present",
              "Absent",
              "On Duty (OD)",
              "Bunks",
              "Unmarked",
            ],
            data: [
              [
                "${overview.totalEnrolledStudents}",
                "${overview.totalConductedSessions}",
                "${overview.averageAttendancePercentage.toStringAsFixed(1)}%",
                "${overview.totalPresentRecords}",
                "${overview.totalAbsentRecords}",
                "${overview.totalOdRecords}",
                "${overview.totalBunkRecords}",
                "${overview.totalUnmarkedRecords}",
              ],
            ],
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            cellHeight: 18,
          ),

          pw.SizedBox(height: 10),

          // Section 2: Attendance Risk Distribution
          pw.Text("2. ATTENDANCE RISK DISTRIBUTION & STATUTORY THRESHOLDS",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),

          pw.TableHelper.fromTextArray(
            headers: ["Risk Tier", "Attendance Band", "Student Count", "Percentage of Cohort", "Statutory Action Status"],
            data: [
              [
                "Good Standing",
                "Attendance >= 75.0%",
                "${overview.studentsGoodStandingCount}",
                "${overview.totalEnrolledStudents > 0 ? (overview.studentsGoodStandingCount / overview.totalEnrolledStudents * 100).toStringAsFixed(1) : 0}%",
                "Eligible for semester examinations without condonation",
              ],
              [
                "Warning",
                "Attendance 65.0% - 74.9%",
                "${overview.studentsBelow75Count}",
                "${overview.totalEnrolledStudents > 0 ? (overview.studentsBelow75Count / overview.totalEnrolledStudents * 100).toStringAsFixed(1) : 0}%",
                "Requires condonation application with medical/institutional proof",
              ],
              [
                "High Risk",
                "Attendance 50.0% - 64.9%",
                "${overview.studentsBelow65Count}",
                "${overview.totalEnrolledStudents > 0 ? (overview.studentsBelow65Count / overview.totalEnrolledStudents * 100).toStringAsFixed(1) : 0}%",
                "Mandatory counselor meeting; parent notification dispatched",
              ],
              [
                "Critical",
                "Attendance < 50.0%",
                "${overview.studentsBelow50Count}",
                "${overview.totalEnrolledStudents > 0 ? (overview.studentsBelow50Count / overview.totalEnrolledStudents * 100).toStringAsFixed(1) : 0}%",
                "Detention risk; mandatory review with Head of Department",
              ],
            ],
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellHeight: 16,
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(4.5),
            },
          ),

          pw.SizedBox(height: 12),

          // Section 3: Student Bunk Leaderboard
          pw.Text("3. STUDENT BUNK LEADERBOARD (HIGHEST INCIDENTS)",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),

          if (topBunkers.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Text("Zero session bunks recorded across the selected reporting scope.",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ["Rank", "Register No", "Student Name", "Class", "Total Bunks", "Current Mo", "MoM Delta", "Overall %", "Risk Tier"],
              data: topBunkers.map((b) {
                return [
                  "#${b.rank}",
                  b.registerNumber,
                  b.fullName,
                  b.className,
                  "${b.totalBunkCount}",
                  "${b.currentMonthBunks}",
                  b.monthToMonthDelta > 0 ? "+${b.monthToMonthDelta}" : "${b.monthToMonthDelta}",
                  "${b.attendancePercentage.toStringAsFixed(1)}%",
                  _formatRiskLevel(b.riskLevel),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.purple800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellHeight: 16,
            ),

          pw.SizedBox(height: 12),

          // Section 4: Low Attendance Cohort (<75%)
          pw.Text("4. AT-RISK ATTENDANCE ROSTER (BELOW 75% REGULATORY BENCHMARK)",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
          pw.SizedBox(height: 4),

          if (atRiskStudents.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Text("All students meet or exceed the mandatory 75% attendance benchmark.",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.green800)),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ["Reg Number", "Student Name", "Class", "Conducted", "Present", "Absent", "OD", "Bunk", "Att %", "Strict %", "Risk Status"],
              data: atRiskStudents.take(15).map((s) {
                return [
                  s.registerNumber,
                  s.fullName,
                  s.className,
                  "${s.totalConductedSessions}",
                  "${s.presentCount}",
                  "${s.absentCount}",
                  "${s.odCount}",
                  "${s.bunkCount}",
                  "${s.attendancePercentage.toStringAsFixed(1)}%",
                  "${s.strictAttendancePercentage.toStringAsFixed(1)}%",
                  _formatRiskLevel(s.riskLevel),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellHeight: 16,
            ),

          pw.SizedBox(height: 12),

          // Section 5: Department & Class Comparison Summary
          pw.Text("5. SECTION & DEPARTMENTAL BENCHMARK COMPARISON",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),

          pw.TableHelper.fromTextArray(
            headers: ["Section / Dept", "Enrolled", "Conducted", "Average %", "Total Present", "Total Bunk", "<75% Count", "<50% Count"],
            data: data.classComparisons.take(8).map((c) {
              return [
                c.className,
                "${c.totalEnrolledStudents}",
                "${c.totalConductedSessions}",
                "${c.averageAttendancePercentage.toStringAsFixed(1)}%",
                "${c.totalPresent}",
                "${c.totalBunk}",
                "${c.studentsBelow75}",
                "${c.studentsBelow50}",
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellHeight: 16,
          ),

          pw.SizedBox(height: 12),

          // Section 6: Actionable Institutional Observations
          pw.Text("6. INSTITUTIONAL OBSERVATIONS & DIRECTIVES",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),

          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfBulletPoint(
                    "Statutory Compliance: ${overview.studentsGoodStandingCount} of ${overview.totalEnrolledStudents} students (${overview.totalEnrolledStudents > 0 ? (overview.studentsGoodStandingCount / overview.totalEnrolledStudents * 100).toStringAsFixed(1) : 0}%) meet Anna University examination eligibility thresholds."),
                _pdfBulletPoint(
                    "Intervention Priority: ${overview.studentsBelow65Count} student(s) fall below 65% attendance. Departmental mentors are instructed to schedule immediate parent-guardian conferences."),
                _pdfBulletPoint(
                    "Afternoon Shift Integrity: A total of ${data.shiftDiscrepancies.length} individual shift drop-off discrepancies were logged where students attended morning but missed afternoon sessions."),
                _pdfBulletPoint(
                    "Session Accountability: All analytics are derived strictly from finalized closed sessions. Unmarked student sessions have been penalized as unexcused absences in accordance with college academic policy."),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Sign-off Block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfSignBlock("Prepared By\nAttendance Coordinator"),
              _pdfSignBlock("Verified By\nHead of the Department"),
              _pdfSignBlock("Approved By\nPrincipal / Dean Academic"),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_collegeName,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text(_collegeSub,
                  style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue900, width: 0.8),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text("ADMIN PORTAL",
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Vel Tech Attendance Management System  |  Official Academic Document",
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
          pw.Text("Page ${context.pageNumber} of ${context.pagesCount}",
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  static pw.Widget _pdfMetaItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.SizedBox(height: 1),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _pdfBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 3, right: 5),
            width: 3.5,
            height: 3.5,
            decoration: const pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColors.blue900,
            ),
          ),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfSignBlock(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 110, height: 26),
        pw.Container(width: 120, height: 0.8, color: PdfColors.grey600),
        pw.SizedBox(height: 3),
        pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, color: PdfColors.black)),
      ],
    );
  }

  // ===========================================================================
  // 3. CSV EXPORTS (.csv)
  // ===========================================================================

  /// Complete Student Performance CSV
  static String generateStudentPerformanceCsv({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM for Microsoft Excel compatibility
    buffer.write('\uFEFF');

    buffer.writeln("# STUDENT ATTENDANCE MANAGEMENT SYSTEM — STUDENT PERFORMANCE REPORT");
    buffer.writeln("# Academic Year: ${_escapeCsv(filter.academicYear)}");
    buffer.writeln("# Department: ${_escapeCsv(filter.department)}");
    buffer.writeln("# Class / Section: ${_escapeCsv(filter.classId)}");
    buffer.writeln("# Reporting Month: ${filter.month != null ? _monthNames[filter.month!] : 'All Year'}");
    buffer.writeln("# Generated At: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}");
    buffer.writeln("");

    buffer.writeln(
      "Rank,Register Number,Student Name,Department,Class,Conducted Sessions,Present,Absent,OD,Bunk,Unmarked,Attendance %,Strict %,Risk Tier",
    );

    for (int i = 0; i < data.studentPerformanceList.length; i++) {
      final s = data.studentPerformanceList[i];
      buffer.writeln([
        "${i + 1}",
        _escapeCsv(s.registerNumber),
        _escapeCsv(s.fullName),
        _escapeCsv(s.department),
        _escapeCsv(s.className),
        "${s.totalConductedSessions}",
        "${s.presentCount}",
        "${s.absentCount}",
        "${s.odCount}",
        "${s.bunkCount}",
        "${s.unmarkedCount}",
        s.attendancePercentage.toStringAsFixed(2),
        s.strictAttendancePercentage.toStringAsFixed(2),
        _escapeCsv(_formatRiskLevel(s.riskLevel)),
      ].join(","));
    }

    return buffer.toString();
  }

  /// Monthly Bunk Rankings CSV
  static String generateBunkRankingsCsv({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln("# STUDENT ATTENDANCE MANAGEMENT SYSTEM — BUNK LEADERBOARD REPORT");
    buffer.writeln("# Academic Year: ${_escapeCsv(filter.academicYear)}");
    buffer.writeln("# Department: ${_escapeCsv(filter.department)}");
    buffer.writeln("# Generated At: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}");
    buffer.writeln("");

    buffer.writeln(
      "Rank,Register Number,Student Name,Class,Department,Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec,Total Bunks,Current Month Bunks,Previous Month Bunks,MoM Delta,Attendance %,Risk Tier",
    );

    for (final b in data.bunkRankings) {
      buffer.writeln([
        "${b.rank}",
        _escapeCsv(b.registerNumber),
        _escapeCsv(b.fullName),
        _escapeCsv(b.className),
        _escapeCsv(b.department),
        "${b.monthlyBunkBreakdown[1] ?? 0}",
        "${b.monthlyBunkBreakdown[2] ?? 0}",
        "${b.monthlyBunkBreakdown[3] ?? 0}",
        "${b.monthlyBunkBreakdown[4] ?? 0}",
        "${b.monthlyBunkBreakdown[5] ?? 0}",
        "${b.monthlyBunkBreakdown[6] ?? 0}",
        "${b.monthlyBunkBreakdown[7] ?? 0}",
        "${b.monthlyBunkBreakdown[8] ?? 0}",
        "${b.monthlyBunkBreakdown[9] ?? 0}",
        "${b.monthlyBunkBreakdown[10] ?? 0}",
        "${b.monthlyBunkBreakdown[11] ?? 0}",
        "${b.monthlyBunkBreakdown[12] ?? 0}",
        "${b.totalBunkCount}",
        "${b.currentMonthBunks}",
        "${b.previousMonthBunks}",
        "${b.monthToMonthDelta}",
        b.attendancePercentage.toStringAsFixed(1),
        _escapeCsv(_formatRiskLevel(b.riskLevel)),
      ].join(","));
    }

    return buffer.toString();
  }

  /// Department and Class Comparison CSV
  static String generateDepartmentComparisonCsv({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln("# STUDENT ATTENDANCE MANAGEMENT SYSTEM — DEPARTMENT & CLASS COMPARISON");
    buffer.writeln("# Academic Year: ${_escapeCsv(filter.academicYear)}");
    buffer.writeln("# Generated At: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}");
    buffer.writeln("");

    // 1. Department Table
    buffer.writeln("--- INTER-DEPARTMENT COMPARISON ---");
    buffer.writeln(
      "Department,Enrolled,Conducted Sessions,Average %,Present,Absent,OD,Bunk,Bunk Rate,Below 75%,Below 65%,Below 50%",
    );
    for (final d in data.departmentComparisons) {
      buffer.writeln([
        _escapeCsv(d.departmentName),
        "${d.totalEnrolledStudents}",
        "${d.totalConductedSessions}",
        d.averageAttendancePercentage.toStringAsFixed(2),
        "${d.totalPresent}",
        "${d.totalAbsent}",
        "${d.totalOd}",
        "${d.totalBunk}",
        d.bunkRate.toStringAsFixed(2),
        "${d.studentsBelow75}",
        "${d.studentsBelow65}",
        "${d.studentsBelow50}",
      ].join(","));
    }
    buffer.writeln("");

    // 2. Class Table
    buffer.writeln("--- INTRA-DEPARTMENT SECTION COMPARISON ---");
    buffer.writeln(
      "Class,Department,Academic Year,Enrolled,Conducted Sessions,Average %,Present,Absent,OD,Bunk,Bunk Rate,Below 75%,Below 65%,Below 50%",
    );
    for (final c in data.classComparisons) {
      buffer.writeln([
        _escapeCsv(c.className),
        _escapeCsv(c.department),
        _escapeCsv(c.academicYear),
        "${c.totalEnrolledStudents}",
        "${c.totalConductedSessions}",
        c.averageAttendancePercentage.toStringAsFixed(2),
        "${c.totalPresent}",
        "${c.totalAbsent}",
        "${c.totalOd}",
        "${c.totalBunk}",
        c.bunkRate.toStringAsFixed(2),
        "${c.studentsBelow75}",
        "${c.studentsBelow65}",
        "${c.studentsBelow50}",
      ].join(","));
    }

    return buffer.toString();
  }

  /// Morning vs Afternoon Analysis CSV
  static String generateShiftDiscrepancyCsv({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln("# STUDENT ATTENDANCE MANAGEMENT SYSTEM — MORNING VS AFTERNOON SHIFT REPORT");
    buffer.writeln("# Academic Year: ${_escapeCsv(filter.academicYear)}");
    buffer.writeln("# Generated At: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}");
    buffer.writeln("");

    buffer.writeln(
      "Register Number,Student Name,Class,Department,Morning Conducted,Morning Present,Morning %,Afternoon Conducted,Afternoon Present,Afternoon Bunk,Afternoon %,Shift Gap %,Discrepancies",
    );

    for (final s in data.studentPerformanceList) {
      final sMPct = s.morningConducted > 0 ? ((s.morningPresent + s.morningOd) / s.morningConducted) * 100.0 : 0.0;
      final sAPct = s.afternoonConducted > 0 ? ((s.afternoonPresent + s.afternoonOd) / s.afternoonConducted) * 100.0 : 0.0;
      final sGap = sMPct - sAPct;

      buffer.writeln([
        _escapeCsv(s.registerNumber),
        _escapeCsv(s.fullName),
        _escapeCsv(s.className),
        _escapeCsv(s.department),
        "${s.morningConducted}",
        "${s.morningPresent}",
        sMPct.toStringAsFixed(1),
        "${s.afternoonConducted}",
        "${s.afternoonPresent}",
        "${s.afternoonBunk}",
        sAPct.toStringAsFixed(1),
        sGap.toStringAsFixed(1),
        "${s.afternoonShiftDiscrepancyCount}",
      ].join(","));
    }

    return buffer.toString();
  }

  // ===========================================================================
  // 4. PLATFORM DOWNLOAD WRAPPERS
  // ===========================================================================

  /// Trigger download for Excel Workbook
  static Future<void> downloadExcel({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) async {
    final bytes = await generateExcelWorkbook(data: data, filter: filter);
    final filename = _makeFilename("Attendance_Analytics_${filter.department}_${filter.academicYear}", "xlsx");
    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
  }

  /// Trigger download for PDF Report
  static Future<void> downloadPdf({
    required AdvancedAnalyticsResult data,
    required AnalyticsFilterState filter,
  }) async {
    final bytes = await generatePdfReport(data: data, filter: filter);
    final filename = _makeFilename("Executive_Report_${filter.department}_${filter.academicYear}", "pdf");
    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: "application/pdf",
    );
  }

  /// Trigger download for CSV
  static Future<void> downloadCsv({
    required String csvContent,
    required String baseName,
  }) async {
    final bytes = Uint8List.fromList(csvContent.codeUnits);
    final filename = _makeFilename(baseName, "csv");
    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: "text/csv;charset=utf-8",
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static String _makeFilename(String base, String ext) {
    final cleanBase = base.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return "${cleanBase}_$stamp.$ext";
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _formatRiskLevel(AttendanceRiskLevel level) {
    switch (level) {
      case AttendanceRiskLevel.good:
        return "Good Standing (>=75%)";
      case AttendanceRiskLevel.warning:
        return "Warning (65-75%)";
      case AttendanceRiskLevel.highRisk:
        return "High Risk (50-65%)";
      case AttendanceRiskLevel.critical:
        return "Critical (<50%)";
    }
  }
}
