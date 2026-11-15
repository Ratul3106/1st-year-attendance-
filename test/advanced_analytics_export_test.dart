import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/services/advanced_analytics_export_service.dart';

void main() {
  group('Advanced Analytics Export Service Tests (Phase 5)', () {
    const filter = AnalyticsFilterState(
      academicYear: '2025-2026',
      department: 'CSE',
      classId: 'All',
      month: 3,
      year: 2026,
      sessionFilter: 'Both',
    );

    final mockStudents = [
      StudentPerformanceMetric(
        studentId: 's1',
        registerNumber: '2025CSE0101',
        fullName: 'Aarav Sharma, "Jr."',
        classId: 'c1',
        className: 'CSE-1A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 40,
        presentCount: 36,
        absentCount: 2,
        odCount: 1,
        bunkCount: 1,
        unmarkedCount: 0,
        morningConducted: 20,
        morningPresent: 19,
        morningAbsent: 0,
        morningOd: 1,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 20,
        afternoonPresent: 17,
        afternoonAbsent: 2,
        afternoonOd: 0,
        afternoonBunk: 1,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 1,
        attendancePercentage: 92.5,
        strictAttendancePercentage: 90.0,
        riskLevel: AttendanceRiskLevel.good,
      ),
      StudentPerformanceMetric(
        studentId: 's2',
        registerNumber: '2025CSE0102',
        fullName: 'Karthik Raja',
        classId: 'c1',
        className: 'CSE-1A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 40,
        presentCount: 26,
        absentCount: 4,
        odCount: 2,
        bunkCount: 8,
        unmarkedCount: 0,
        morningConducted: 20,
        morningPresent: 18,
        morningAbsent: 1,
        morningOd: 1,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 20,
        afternoonPresent: 8,
        afternoonAbsent: 3,
        afternoonOd: 1,
        afternoonBunk: 8,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 8,
        attendancePercentage: 70.0,
        strictAttendancePercentage: 65.0,
        riskLevel: AttendanceRiskLevel.warning,
      ),
      StudentPerformanceMetric(
        studentId: 's3',
        registerNumber: '2025CSE0103',
        fullName: 'Sneha & Patel',
        classId: 'c2',
        className: 'CSE-1B',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 40,
        presentCount: 20,
        absentCount: 8,
        odCount: 2,
        bunkCount: 10,
        unmarkedCount: 0,
        morningConducted: 20,
        morningPresent: 16,
        morningAbsent: 3,
        morningOd: 1,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 20,
        afternoonPresent: 4,
        afternoonAbsent: 5,
        afternoonOd: 1,
        afternoonBunk: 10,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 10,
        attendancePercentage: 55.0,
        strictAttendancePercentage: 50.0,
        riskLevel: AttendanceRiskLevel.highRisk,
      ),
      StudentPerformanceMetric(
        studentId: 's4',
        registerNumber: '2025CSE0104',
        fullName: 'Vikramaditya V',
        classId: 'c2',
        className: 'CSE-1B',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 40,
        presentCount: 16,
        absentCount: 18,
        odCount: 1,
        bunkCount: 5,
        unmarkedCount: 0,
        morningConducted: 20,
        morningPresent: 10,
        morningAbsent: 8,
        morningOd: 1,
        morningBunk: 1,
        morningUnmarked: 0,
        afternoonConducted: 20,
        afternoonPresent: 6,
        afternoonAbsent: 10,
        afternoonOd: 0,
        afternoonBunk: 4,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 4,
        attendancePercentage: 42.5,
        strictAttendancePercentage: 40.0,
        riskLevel: AttendanceRiskLevel.critical,
      ),
    ];

    final mockRankings = [
      BunkRankingItem(
        rank: 1,
        studentId: 's3',
        registerNumber: '2025CSE0103',
        fullName: 'Sneha & Patel',
        classId: 'c2',
        className: 'CSE-1B',
        department: 'CSE',
        totalBunkCount: 10,
        totalConductedSessions: 40,
        attendancePercentage: 55.0,
        riskLevel: AttendanceRiskLevel.highRisk,
        monthlyBunkBreakdown: {1: 2, 2: 3, 3: 5},
        previousMonthBunks: 3,
        currentMonthBunks: 5,
        monthToMonthDelta: 2,
      ),
      BunkRankingItem(
        rank: 2,
        studentId: 's2',
        registerNumber: '2025CSE0102',
        fullName: 'Karthik Raja',
        classId: 'c1',
        className: 'CSE-1A',
        department: 'CSE',
        totalBunkCount: 8,
        totalConductedSessions: 40,
        attendancePercentage: 70.0,
        riskLevel: AttendanceRiskLevel.warning,
        monthlyBunkBreakdown: {1: 1, 2: 4, 3: 3},
        previousMonthBunks: 4,
        currentMonthBunks: 3,
        monthToMonthDelta: -1,
      ),
      BunkRankingItem(
        rank: 3,
        studentId: 's4',
        registerNumber: '2025CSE0104',
        fullName: 'Vikramaditya V',
        classId: 'c2',
        className: 'CSE-1B',
        department: 'CSE',
        totalBunkCount: 5,
        totalConductedSessions: 40,
        attendancePercentage: 42.5,
        riskLevel: AttendanceRiskLevel.critical,
        monthlyBunkBreakdown: {1: 1, 2: 2, 3: 2},
        previousMonthBunks: 2,
        currentMonthBunks: 2,
        monthToMonthDelta: 0,
      ),
      BunkRankingItem(
        rank: 4,
        studentId: 's1',
        registerNumber: '2025CSE0101',
        fullName: 'Aarav Sharma, "Jr."',
        classId: 'c1',
        className: 'CSE-1A',
        department: 'CSE',
        totalBunkCount: 1,
        totalConductedSessions: 40,
        attendancePercentage: 92.5,
        riskLevel: AttendanceRiskLevel.good,
        monthlyBunkBreakdown: {1: 0, 2: 0, 3: 1},
        previousMonthBunks: 0,
        currentMonthBunks: 1,
        monthToMonthDelta: 1,
      ),
    ];

    final mockDeptComparisons = [
      DepartmentComparisonMetric(
        departmentName: 'CSE',
        totalEnrolledStudents: 120,
        totalConductedSessions: 40,
        averageAttendancePercentage: 81.4,
        totalPresent: 3820,
        totalAbsent: 510,
        totalOd: 150,
        totalBunk: 320,
        totalUnmarked: 0,
        studentsBelow75: 18,
        studentsBelow65: 7,
        studentsBelow50: 3,
        bunkRate: 2.67,
      ),
      DepartmentComparisonMetric(
        departmentName: 'ECE',
        totalEnrolledStudents: 95,
        totalConductedSessions: 40,
        averageAttendancePercentage: 76.8,
        totalPresent: 2840,
        totalAbsent: 480,
        totalOd: 80,
        totalBunk: 400,
        totalUnmarked: 0,
        studentsBelow75: 22,
        studentsBelow65: 9,
        studentsBelow50: 4,
        bunkRate: 4.21,
      ),
    ];

    final mockClassComparisons = [
      ClassComparisonMetric(
        classId: 'c1',
        className: 'CSE-1A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalEnrolledStudents: 60,
        totalConductedSessions: 40,
        averageAttendancePercentage: 86.2,
        totalPresent: 2020,
        totalAbsent: 210,
        totalOd: 50,
        totalBunk: 120,
        totalUnmarked: 0,
        studentsBelow75: 5,
        studentsBelow65: 2,
        studentsBelow50: 1,
        bunkRate: 2.0,
      ),
      ClassComparisonMetric(
        classId: 'c2',
        className: 'CSE-1B',
        department: 'CSE',
        academicYear: '2025-2026',
        totalEnrolledStudents: 60,
        totalConductedSessions: 40,
        averageAttendancePercentage: 76.6,
        totalPresent: 1800,
        totalAbsent: 300,
        totalOd: 100,
        totalBunk: 200,
        totalUnmarked: 0,
        studentsBelow75: 13,
        studentsBelow65: 5,
        studentsBelow50: 2,
        bunkRate: 3.33,
      ),
    ];

    final mockDiscrepancies = [
      SessionShiftDiscrepancy(
        studentId: 's3',
        registerNumber: '2025CSE0103',
        studentName: 'Sneha & Patel',
        className: 'CSE-1B',
        department: 'CSE',
        date: DateTime(2026, 3, 14),
        morningStatus: AttendanceStatus.present,
        afternoonStatus: AttendanceStatus.bunk,
        discrepancyReason: 'Afternoon Bunk (Morning Present)',
      ),
      SessionShiftDiscrepancy(
        studentId: 's2',
        registerNumber: '2025CSE0102',
        studentName: 'Karthik Raja',
        className: 'CSE-1A',
        department: 'CSE',
        date: DateTime(2026, 3, 12),
        morningStatus: AttendanceStatus.present,
        afternoonStatus: AttendanceStatus.bunk,
        discrepancyReason: 'Afternoon Bunk (Morning Present)',
      ),
    ];

    final mockOverview = MonthlyAttendanceOverviewData(
      academicYear: '2025-2026',
      department: 'CSE',
      month: 3,
      year: 2026,
      totalEnrolledStudents: 4,
      totalConductedSessions: 40,
      averageAttendancePercentage: 65.0,
      totalPresentRecords: 98,
      totalAbsentRecords: 32,
      totalOdRecords: 6,
      totalBunkRecords: 24,
      totalUnmarkedRecords: 0,
      studentsBelow75Count: 3,
      studentsBelow65Count: 2,
      studentsBelow50Count: 1,
      studentsGoodStandingCount: 1,
      highestAttendanceClassName: 'CSE-1A',
      highestAttendanceClassPercentage: 86.2,
      lowestAttendanceClassName: 'CSE-1B',
      lowestAttendanceClassPercentage: 76.6,
      highestBunkClassName: 'CSE-1B',
      highestBunkCount: 15,
    );

    final mockAnalyticsResult = AdvancedAnalyticsResult(
      appliedFilters: filter,
      overview: mockOverview,
      studentPerformanceList: mockStudents,
      bunkRankings: mockRankings,
      departmentComparisons: mockDeptComparisons,
      classComparisons: mockClassComparisons,
      shiftDiscrepancies: mockDiscrepancies,
      calendarHeatmap: [],
      computedAt: DateTime(2026, 3, 15, 14, 30),
    );

    test('1. Excel Export: Generates valid multi-sheet workbook with all 5 sheets and accurate values', () async {
      final bytes = await AdvancedAnalyticsExportService.generateExcelWorkbook(
        data: mockAnalyticsResult,
        filter: filter,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, contains('Executive Overview'));
      expect(excel.tables.keys, contains('Student Performance'));
      expect(excel.tables.keys, contains('Monthly Bunk Leaderboard'));
      expect(excel.tables.keys, contains('Morning vs Afternoon'));
      expect(excel.tables.keys, contains('Dept & Class Comparison'));
      expect(excel.tables.keys, isNot(contains('Sheet1'))); // Default sheet deleted

      // Verify Sheet 1 content
      final sheet1 = excel['Executive Overview'];
      expect(sheet1.maxRows, greaterThan(10));

      // Verify Sheet 2 content
      final sheet2 = excel['Student Performance'];
      expect(sheet2.maxRows, equals(4 + 4)); // Header + 4 students + title rows

      // Verify Sheet 3 content
      final sheet3 = excel['Monthly Bunk Leaderboard'];
      expect(sheet3.maxRows, equals(4 + 4));
    });

    test('2. PDF Export: Generates compliant document starting with %PDF- header', () async {
      final bytes = await AdvancedAnalyticsExportService.generatePdfReport(
        data: mockAnalyticsResult,
        filter: filter,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(5000));

      // Check %PDF- magic bytes
      final headerStr = String.fromCharCodes(bytes.take(5));
      expect(headerStr, equals('%PDF-'));
    });

    test('3. CSV Export: Proper RFC 4180 escaping and UTF-8 BOM', () {
      final csv = AdvancedAnalyticsExportService.generateStudentPerformanceCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );

      // Check UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);

      // Check headers
      expect(csv, contains('Rank,Register Number,Student Name,Department,Class'));

      // Verify escaping of special characters in name: Aarav Sharma, "Jr."
      expect(csv, contains('"Aarav Sharma, ""Jr."""'));

      // Verify student records
      expect(csv, contains('2025CSE0101'));
      expect(csv, contains('2025CSE0102'));
      expect(csv, contains('2025CSE0103'));
      expect(csv, contains('2025CSE0104'));
    });

    test('4. CSV Export: Bunk rankings CSV contains Jan-Dec breakdown and delta', () {
      final csv = AdvancedAnalyticsExportService.generateBunkRankingsCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );

      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec,Total Bunks'));
      expect(csv, contains('Sneha & Patel'));
      expect(csv, contains('10')); // Total bunks
    });

    test('5. CSV Export: Department and Class Comparison CSV has both tables', () {
      final csv = AdvancedAnalyticsExportService.generateDepartmentComparisonCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );

      expect(csv, contains('--- INTER-DEPARTMENT COMPARISON ---'));
      expect(csv, contains('--- INTRA-DEPARTMENT SECTION COMPARISON ---'));
      expect(csv, contains('CSE'));
      expect(csv, contains('ECE'));
      expect(csv, contains('CSE-1A'));
      expect(csv, contains('CSE-1B'));
    });

    test('6. CSV Export: Morning vs Afternoon CSV contains shift drop-off and incident data', () {
      final csv = AdvancedAnalyticsExportService.generateShiftDiscrepancyCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );

      expect(csv, contains('Morning Conducted,Morning Present,Morning %,Afternoon Conducted'));
      expect(csv, contains('Karthik Raja'));
      expect(csv, contains('8')); // 8 discrepancies
    });

    test('7. Edge Case: Empty Dataset generates valid files without crashing', () async {
      final emptyResult = AdvancedAnalyticsResult.empty();

      // Excel
      final excelBytes = await AdvancedAnalyticsExportService.generateExcelWorkbook(
        data: emptyResult,
        filter: filter,
      );
      expect(excelBytes, isNotEmpty);
      final excel = Excel.decodeBytes(excelBytes);
      expect(excel.tables.keys, contains('Executive Overview'));

      // PDF
      final pdfBytes = await AdvancedAnalyticsExportService.generatePdfReport(
        data: emptyResult,
        filter: filter,
      );
      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));

      // CSV
      final csv = AdvancedAnalyticsExportService.generateStudentPerformanceCsv(
        data: emptyResult,
        filter: filter,
      );
      expect(csv, contains('Rank,Register Number,Student Name'));
    });

    test('8. End-to-End File Persistence: Writes actual sample files to disk for verification', () async {
      final outDir = Directory(
        r'C:\Users\KRISSHORE S\.gemini\antigravity\brain\1f7f4241-9648-4e2e-84a2-5ccbc6b0b3b1\exports',
      );
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      // 1. Excel File
      final excelBytes = await AdvancedAnalyticsExportService.generateExcelWorkbook(
        data: mockAnalyticsResult,
        filter: filter,
      );
      final excelFile = File('${outDir.path}\\sample_attendance_analytics.xlsx');
      excelFile.writeAsBytesSync(excelBytes);
      expect(excelFile.existsSync(), isTrue);
      expect(excelFile.lengthSync(), greaterThan(1000));

      // 2. PDF File
      final pdfBytes = await AdvancedAnalyticsExportService.generatePdfReport(
        data: mockAnalyticsResult,
        filter: filter,
      );
      final pdfFile = File('${outDir.path}\\sample_executive_report.pdf');
      pdfFile.writeAsBytesSync(pdfBytes);
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(5000));

      // 3. CSV File (Student Performance)
      final perfCsv = AdvancedAnalyticsExportService.generateStudentPerformanceCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );
      final perfFile = File('${outDir.path}\\sample_student_performance.csv');
      perfFile.writeAsStringSync(perfCsv);
      expect(perfFile.existsSync(), isTrue);
      expect(perfFile.lengthSync(), greaterThan(100));

      // 4. CSV File (Bunk Leaderboard)
      final bunkCsv = AdvancedAnalyticsExportService.generateBunkRankingsCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );
      final bunkFile = File('${outDir.path}\\sample_bunk_leaderboard.csv');
      bunkFile.writeAsStringSync(bunkCsv);
      expect(bunkFile.existsSync(), isTrue);
      expect(bunkFile.lengthSync(), greaterThan(100));

      // 5. CSV File (Dept & Class Comparison)
      final compCsv = AdvancedAnalyticsExportService.generateDepartmentComparisonCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );
      final compFile = File('${outDir.path}\\sample_dept_class_comparison.csv');
      compFile.writeAsStringSync(compCsv);
      expect(compFile.existsSync(), isTrue);
      expect(compFile.lengthSync(), greaterThan(100));

      // 6. CSV File (Morning vs Afternoon)
      final shiftCsv = AdvancedAnalyticsExportService.generateShiftDiscrepancyCsv(
        data: mockAnalyticsResult,
        filter: filter,
      );
      final shiftFile = File('${outDir.path}\\sample_morning_vs_afternoon.csv');
      shiftFile.writeAsStringSync(shiftCsv);
      expect(shiftFile.existsSync(), isTrue);
      expect(shiftFile.lengthSync(), greaterThan(100));
    });
  });
}
