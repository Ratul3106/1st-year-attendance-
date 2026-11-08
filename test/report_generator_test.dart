import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/services/attendance_report_generator_service.dart';

void main() {
  test('AttendanceReportGeneratorService generates valid PDF and Excel reports', () async {
    final service = AttendanceReportGeneratorService();

    final testClass = ClassModel(
      id: 'class-test-1',
      className: 'III CSE - A',
      department: 'CSE',
      academicYear: '2024-2025',
    );

    final config = AttendanceReportConfig(
      selectedClass: testClass,
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 1),
      sessionFilter: 'Both',
      format: 'pdf',
    );

    final item1 = StudentReportItem(
      sNo: 1,
      registerNumber: 'REG101',
      studentName: 'Alice Smith',
      className: 'III CSE - A',
      department: 'CSE',
      date: '2026-11-01',
      session: 'Morning',
      status: AttendanceStatus.present,
    );

    final item2 = StudentReportItem(
      sNo: 2,
      registerNumber: 'REG102',
      studentName: 'Bob Jones',
      className: 'III CSE - A',
      department: 'CSE',
      date: '2026-11-01',
      session: 'Morning',
      status: AttendanceStatus.absent,
    );

    final item3 = StudentReportItem(
      sNo: 3,
      registerNumber: 'REG103',
      studentName: 'Charlie Brown',
      className: 'III CSE - A',
      department: 'CSE',
      date: '2026-11-01',
      session: 'Morning',
      status: AttendanceStatus.od,
    );

    final item4 = StudentReportItem(
      sNo: 4,
      registerNumber: 'REG104',
      studentName: 'David Miller',
      className: 'III CSE - A',
      department: 'CSE',
      date: '2026-11-01',
      session: 'Afternoon',
      status: AttendanceStatus.bunk,
    );

    final item5 = StudentReportItem(
      sNo: 5,
      registerNumber: 'REG105',
      studentName: 'Eve Johnson',
      className: 'III CSE - A',
      department: 'CSE',
      date: '2026-11-01',
      session: 'Afternoon',
      status: null, // Unmarked
    );

    final analytics = AttendanceReportAnalytics(
      totalEnrolledStudents: 5,
      totalMarkedEntries: 4,
      totalPresent: 1,
      totalAbsent: 1,
      totalOd: 1,
      totalBunk: 1,
      totalUnmarked: 1,
      overallPercentage: 50.0,
      percentageFormula: "((Present + OD) / Total Marked Records) * 100",
      morningPresent: 1,
      morningAbsent: 1,
      morningOd: 1,
      morningUnmarked: 0,
      morningPercentage: 66.7,
      afternoonPresent: 0,
      afternoonAbsent: 0,
      afternoonOd: 0,
      afternoonBunk: 1,
      afternoonUnmarked: 1,
      afternoonPercentage: 0.0,
      presentBothSessions: 0,
      presentMorningAbsentAfternoon: 0,
      absentBothSessions: 0,
    );

    final reportData = AttendanceReportData(
      config: config,
      generatedAt: DateTime.now(),
      analytics: analytics,
      allItems: [item1, item2, item3, item4, item5],
      presentList: [item1],
      absentList: [item2],
      odList: [item3],
      bunkList: [item4],
      unmarkedList: [item5],
    );

    // 1. Verify PDF Generation
    final pdfBytes = await service.generatePdfReport(reportData);
    expect(pdfBytes, isNotNull);
    expect(pdfBytes.isNotEmpty, isTrue);

    // 2. Verify Excel Generation
    final excelBytes = await service.generateExcelReport(reportData);
    expect(excelBytes, isNotNull);
    expect(excelBytes.isNotEmpty, isTrue);

    // Decode Excel and check all 7 sheets exist
    final excel = Excel.decodeBytes(excelBytes);
    expect(excel.tables.containsKey('Summary'), isTrue);
    expect(excel.tables.containsKey('Present Students'), isTrue);
    expect(excel.tables.containsKey('Absent Students'), isTrue);
    expect(excel.tables.containsKey('OD Students'), isTrue);
    expect(excel.tables.containsKey('Bunked Students'), isTrue);
    expect(excel.tables.containsKey('Unmarked Students'), isTrue);
    expect(excel.tables.containsKey('Detailed Attendance'), isTrue);
  });
}
