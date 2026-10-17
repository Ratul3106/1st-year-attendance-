import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/daily_report.dart';

class StudentDailyComparison {
  final Student student;
  final AttendanceStatus? morningStatus;
  final AttendanceStatus? afternoonStatus;
  final String category;
  final bool isDiscrepancy;

  StudentDailyComparison({
    required this.student,
    this.morningStatus,
    this.afternoonStatus,
    required this.category,
    required this.isDiscrepancy,
  });

  String get morningStatusDisplay => morningStatus?.displayName ?? 'Not Marked';
  String get afternoonStatusDisplay => afternoonStatus?.displayName ?? 'Not Marked';
}

class AttendanceComparisonEngine {
  /// Categorizes student daily attendance comparison without inventing values.
  static String categorizeComparison({
    required AttendanceStatus? morning,
    required AttendanceStatus? afternoon,
  }) {
    if (morning == null && afternoon == null) {
      return 'Not Marked';
    }
    if (morning != null && afternoon == null) {
      return 'Afternoon attendance incomplete';
    }
    if (morning == null && afternoon != null) {
      return 'Morning attendance incomplete';
    }

    // Both sessions are explicitly marked
    if (morning == AttendanceStatus.present && afternoon == AttendanceStatus.present) {
      return 'Present in both sessions';
    }
    if (morning == AttendanceStatus.present && afternoon == AttendanceStatus.absent) {
      return 'Present in the morning, absent in the afternoon';
    }
    if (morning == AttendanceStatus.present && afternoon == AttendanceStatus.od) {
      return 'OD in the afternoon';
    }
    if (morning == AttendanceStatus.present && afternoon == AttendanceStatus.bunk) {
      return 'Marked Bunk in the afternoon';
    }
    if (morning == AttendanceStatus.absent && afternoon == AttendanceStatus.present) {
      return 'Present in the afternoon after morning absent';
    }
    if (morning == AttendanceStatus.absent && afternoon == AttendanceStatus.absent) {
      return 'Absent in both sessions';
    }
    if (morning == AttendanceStatus.absent && afternoon == AttendanceStatus.od) {
      return 'Morning absent, afternoon OD';
    }
    if (morning == AttendanceStatus.absent && afternoon == AttendanceStatus.bunk) {
      return 'Morning absent, afternoon Bunk';
    }
    if (morning == AttendanceStatus.od && afternoon == AttendanceStatus.present) {
      return 'Present in the afternoon after morning OD';
    }
    if (morning == AttendanceStatus.od && afternoon == AttendanceStatus.absent) {
      return 'Morning OD, afternoon absent';
    }
    if (morning == AttendanceStatus.od && afternoon == AttendanceStatus.od) {
      return 'OD in both sessions';
    }
    if (morning == AttendanceStatus.od && afternoon == AttendanceStatus.bunk) {
      return 'Morning OD, afternoon Bunk';
    }

    return 'Status: ${morning?.displayName ?? "Not Marked"} / ${afternoon?.displayName ?? "Not Marked"}';
  }

  /// Determines if this combination is an attendance shift / discrepancy
  static bool isDiscrepancy(AttendanceStatus? morning, AttendanceStatus? afternoon) {
    if (morning == null || afternoon == null) return false;
    // Difference between morning and afternoon
    return morning != afternoon;
  }

  /// Evaluates comparisons for a list of students given session records
  static List<StudentDailyComparison> compareStudents({
    required List<Student> students,
    required Map<String, AttendanceStatus> morningRecords,
    required Map<String, AttendanceStatus> afternoonRecords,
  }) {
    return students.map((student) {
      final mStatus = morningRecords[student.id];
      final aStatus = afternoonRecords[student.id];
      final category = categorizeComparison(morning: mStatus, afternoon: aStatus);
      final disc = isDiscrepancy(mStatus, aStatus);

      return StudentDailyComparison(
        student: student,
        morningStatus: mStatus,
        afternoonStatus: aStatus,
        category: category,
        isDiscrepancy: disc,
      );
    }).toList();
  }

  /// Computes a comprehensive DailyReport from student comparisons
  static DailyReport buildDailyReport({
    required String classId,
    required String date,
    required List<Student> students,
    required Map<String, AttendanceStatus> morningRecords,
    required Map<String, AttendanceStatus> afternoonRecords,
    required bool hasMorningSession,
    required bool hasAfternoonSession,
  }) {
    final comparisons = compareStudents(
      students: students,
      morningRecords: morningRecords,
      afternoonRecords: afternoonRecords,
    );

    int mP = 0, mA = 0, mOd = 0;
    int aP = 0, aA = 0, aOd = 0, aBunk = 0;
    int bothP = 0, bothA = 0;
    int mP_aA = 0, mA_aP = 0, mP_aBunk = 0, mP_aOd = 0, mOd_aP = 0;
    int incompleteCount = 0;
    final List<StudentDiscrepancy> discrepancies = [];

    for (final comp in comparisons) {
      final m = comp.morningStatus;
      final a = comp.afternoonStatus;

      if (m == AttendanceStatus.present) mP++;
      if (m == AttendanceStatus.absent) mA++;
      if (m == AttendanceStatus.od) mOd++;

      if (a == AttendanceStatus.present) aP++;
      if (a == AttendanceStatus.absent) aA++;
      if (a == AttendanceStatus.od) aOd++;
      if (a == AttendanceStatus.bunk) aBunk++;

      if (m == AttendanceStatus.present && a == AttendanceStatus.present) bothP++;
      if (m == AttendanceStatus.absent && a == AttendanceStatus.absent) bothA++;
      if (m == AttendanceStatus.present && a == AttendanceStatus.absent) mP_aA++;
      if (m == AttendanceStatus.absent && a == AttendanceStatus.present) mA_aP++;
      if (m == AttendanceStatus.present && a == AttendanceStatus.bunk) mP_aBunk++;
      if (m == AttendanceStatus.present && a == AttendanceStatus.od) mP_aOd++;
      if (m == AttendanceStatus.od && a == AttendanceStatus.present) mOd_aP++;

      // Incomplete flag
      if ((hasMorningSession && m == null) || (hasAfternoonSession && a == null)) {
        incompleteCount++;
      }

      if (comp.isDiscrepancy) {
        discrepancies.add(StudentDiscrepancy(
          studentId: comp.student.id,
          registerNumber: comp.student.registerNumber,
          fullName: comp.student.fullName,
          morningStatus: m?.displayName,
          afternoonStatus: a?.displayName,
          discrepancyType: comp.category,
        ));
      }
    }

    final isFinal = hasMorningSession &&
        hasAfternoonSession &&
        morningRecords.length == students.length &&
        afternoonRecords.length == students.length;

    return DailyReport(
      id: 'report-$classId-$date',
      classId: classId,
      attendanceDate: date,
      reportType: isFinal ? 'final' : 'preliminary',
      totalEnrolled: students.length,
      morningPresent: mP,
      morningAbsent: mA,
      morningOd: mOd,
      afternoonPresent: aP,
      afternoonAbsent: aA,
      afternoonOd: aOd,
      afternoonBunk: aBunk,
      bothPresent: bothP,
      bothAbsent: bothA,
      morningPresentAfternoonAbsent: mP_aA,
      morningAbsentAfternoonPresent: mA_aP,
      morningPresentAfternoonBunk: mP_aBunk,
      morningPresentAfternoonOd: mP_aOd,
      morningOdAfternoonPresent: mOd_aP,
      incompleteCount: incompleteCount,
      discrepancies: discrepancies,
      status: 'generated',
      generatedAt: DateTime.now(),
    );
  }
}
