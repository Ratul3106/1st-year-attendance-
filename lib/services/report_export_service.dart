import 'package:intl/intl.dart';
import 'package:student_attendance_system/models/class_model.dart';

class OverallReportConfig {
  final DateTime startDate;
  final DateTime endDate;
  final List<ClassModel> selectedClasses;
  final String sessionType; // 'Both', 'Morning', 'Afternoon'

  OverallReportConfig({
    required this.startDate,
    required this.endDate,
    required this.selectedClasses,
    required this.sessionType,
  });
}

class StudentReportRow {
  final int sNo;
  final String registerNumber;
  final String studentName;
  final String className;
  final String department;
  final String academicYear;
  final String morningStatus;
  final String afternoonStatus;
  final String overallStatus;

  StudentReportRow({
    required this.sNo,
    required this.registerNumber,
    required this.studentName,
    required this.className,
    required this.department,
    required this.academicYear,
    required this.morningStatus,
    required this.afternoonStatus,
    required this.overallStatus,
  });
}

class ClassSummaryReportItem {
  final String className;
  final String department;
  final int totalEnrolled;
  final int morningPresent;
  final int morningAbsent;
  final int morningOd;
  final int afternoonPresent;
  final int afternoonAbsent;
  final int afternoonOd;
  final int afternoonBunk;
  final int bothPresent;
  final double morningPercentage;
  final double afternoonPercentage;

  ClassSummaryReportItem({
    required this.className,
    required this.department,
    required this.totalEnrolled,
    required this.morningPresent,
    required this.morningAbsent,
    required this.morningOd,
    required this.afternoonPresent,
    required this.afternoonAbsent,
    required this.afternoonOd,
    required this.afternoonBunk,
    required this.bothPresent,
    required this.morningPercentage,
    required this.afternoonPercentage,
  });
}

class OverallReportResult {
  final DateTime generatedAt;
  final OverallReportConfig config;
  final List<ClassSummaryReportItem> classSummaries;
  final List<StudentReportRow> studentRows;

  OverallReportResult({
    required this.generatedAt,
    required this.config,
    required this.classSummaries,
    required this.studentRows,
  });

  /// Generates CSV content adhering to RFC 4180
  String generateCsv() {
    final buffer = StringBuffer();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(generatedAt);

    buffer.writeln("# STUDENT ATTENDANCE MANAGEMENT SYSTEM — OVERALL REPORT");
    buffer.writeln("# Generated At: $dateStr");
    buffer.writeln("# Date Range: ${DateFormat('yyyy-MM-dd').format(config.startDate)} to ${DateFormat('yyyy-MM-dd').format(config.endDate)}");
    buffer.writeln("# Session Filter: ${config.sessionType}");
    buffer.writeln("");

    // Section 1: Class Summary
    buffer.writeln("--- CLASS-WISE ATTENDANCE SUMMARY ---");
    buffer.writeln("Class,Department,Enrolled,Morning Pres,Morning Abs,Morning OD,Morning %,Afternoon Pres,Afternoon Abs,Afternoon OD,Afternoon Bunk,Afternoon %,Both Pres");
    for (var s in classSummaries) {
      buffer.writeln('"${s.className}","${s.department}",${s.totalEnrolled},${s.morningPresent},${s.morningAbsent},${s.morningOd},${s.morningPercentage.toStringAsFixed(1)}%,${s.afternoonPresent},${s.afternoonAbsent},${s.afternoonOd},${s.afternoonBunk},${s.afternoonPercentage.toStringAsFixed(1)}%,${s.bothPresent}');
    }

    buffer.writeln("");
    // Section 2: Detailed Student Attendance
    buffer.writeln("--- DETAILED STUDENT ATTENDANCE ---");
    buffer.writeln("S.No,Register Number,Student Name,Class,Department,Academic Year,Morning Status,Afternoon Status,Overall Status");
    for (var r in studentRows) {
      buffer.writeln('${r.sNo},"${r.registerNumber}","${r.studentName}","${r.className}","${r.department}","${r.academicYear}","${r.morningStatus}","${r.afternoonStatus}","${r.overallStatus}"');
    }

    return buffer.toString();
  }
}
