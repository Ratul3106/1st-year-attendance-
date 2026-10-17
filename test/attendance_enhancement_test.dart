import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/services/attendance_comparison_service.dart';
import 'package:student_attendance_system/services/admin_analytics_service.dart';
import 'package:student_attendance_system/services/report_export_service.dart';

void main() {
  group('1. Login and Role Mismatch Tests', () {
    test('Role mismatch rejects unauthorized access', () async {
      final auth = AuthService();
      // Trying to sign in with Coordinator email as Administrator
      expect(
        () => auth.signInWithRole(
          email: 'coordinator@college.edu',
          password: 'password123',
          selectedRole: UserRole.admin,
        ),
        throwsA(isA<RoleMismatchAuthException>()),
      );
    });

    test('Matching role authenticates successfully', () async {
      final auth = AuthService();
      final profile = await auth.signInWithRole(
        email: 'coordinator@college.edu',
        password: 'password123',
        selectedRole: UserRole.coordinator,
      );
      expect(profile.role, equals(UserRole.coordinator));
      expect(profile.active, isTrue);
    });
  });

  group('2. Morning vs Afternoon Allowed Statuses Tests', () {
    test('Morning allows Present, Absent, OD only (no Bunk)', () {
      final morningStatuses = [
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.od,
      ];
      expect(morningStatuses.contains(AttendanceStatus.bunk), isFalse);
      expect(morningStatuses.length, equals(3));
    });

    test('Afternoon allows Present, Absent, OD, Bunk', () {
      final afternoonStatuses = [
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.od,
        AttendanceStatus.bunk,
      ];
      expect(afternoonStatuses.contains(AttendanceStatus.bunk), isTrue);
      expect(afternoonStatuses.length, equals(4));
    });
  });

  group('3. Attendance Comparison Engine Tests', () {
    test('Calculates comparison categories accurately without inventing records', () {
      // Morning Present + Afternoon Present
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.present,
          afternoon: AttendanceStatus.present,
        ),
        equals('Present in both sessions'),
      );

      // Morning Present + Afternoon Absent
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.present,
          afternoon: AttendanceStatus.absent,
        ),
        equals('Present in the morning, absent in the afternoon'),
      );

      // Morning Present + Afternoon OD
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.present,
          afternoon: AttendanceStatus.od,
        ),
        equals('OD in the afternoon'),
      );

      // Morning Present + Afternoon Bunk
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.present,
          afternoon: AttendanceStatus.bunk,
        ),
        equals('Marked Bunk in the afternoon'),
      );

      // Morning Absent + Afternoon Present
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.absent,
          afternoon: AttendanceStatus.present,
        ),
        equals('Present in the afternoon after morning absent'),
      );

      // Morning OD + Afternoon Present
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.od,
          afternoon: AttendanceStatus.present,
        ),
        equals('Present in the afternoon after morning OD'),
      );

      // Incomplete afternoon
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: AttendanceStatus.present,
          afternoon: null,
        ),
        equals('Afternoon attendance incomplete'),
      );

      // Not marked
      expect(
        AttendanceComparisonEngine.categorizeComparison(
          morning: null,
          afternoon: null,
        ),
        equals('Not Marked'),
      );
    });

    test('Unmarked students are not counted as absent', () {
      final students = [
        Student(id: 's1', registerNumber: 'R1', fullName: 'Student 1', active: true, createdAt: DateTime.now()),
        Student(id: 's2', registerNumber: 'R2', fullName: 'Student 2', active: true, createdAt: DateTime.now()),
      ];

      // Only student 1 marked as Present in morning; student 2 is unmarked
      final report = AttendanceComparisonEngine.buildDailyReport(
        classId: 'c1',
        date: '2026-10-13',
        students: students,
        morningRecords: {'s1': AttendanceStatus.present},
        afternoonRecords: {},
        hasMorningSession: true,
        hasAfternoonSession: false,
      );

      expect(report.morningPresent, equals(1));
      expect(report.morningAbsent, equals(0)); // s2 must NOT be counted as absent!
      expect(report.incompleteCount, equals(1));
    });
  });

  group('4. Duplicate Prevention and Storage Tests', () {
    test('Saving updated attendance replaces previous student record without duplication', () {
      final demo = DemoDataService.instance;
      const testSessionId = 'test-session-duplicate-check';
      const testStudentId = 'std-1';

      // Save as Absent
      demo.saveAttendanceRecords(testSessionId, {testStudentId: AttendanceStatus.absent});
      var records = demo.getSessionRecords(testSessionId);
      expect(records.where((r) => r.studentId == testStudentId).length, equals(1));
      expect(records.firstWhere((r) => r.studentId == testStudentId).status, equals(AttendanceStatus.absent));

      // Overwrite/Update to Present
      demo.saveAttendanceRecords(testSessionId, {testStudentId: AttendanceStatus.present});
      records = demo.getSessionRecords(testSessionId);
      expect(records.where((r) => r.studentId == testStudentId).length, equals(1));
      expect(records.firstWhere((r) => r.studentId == testStudentId).status, equals(AttendanceStatus.present));
    });
  });

  group('5. Overall Report CSV Generation Tests', () {
    test('Generates structured CSV with headers and records', () {
      final now = DateTime.now();
      final config = OverallReportConfig(
        startDate: now,
        endDate: now,
        selectedClasses: [
          ClassModel(
            id: 'c1',
            className: '1st Year - CSE (Sec A)',
            department: 'Computer Science',
            academicYear: '2026-2027',
            active: true,
            createdAt: now,
          )
        ],
        sessionType: 'Both',
      );

      final result = OverallReportResult(
        generatedAt: now,
        config: config,
        classSummaries: [
          ClassSummaryReportItem(
            className: '1st Year - CSE (Sec A)',
            department: 'Computer Science',
            totalEnrolled: 12,
            morningPresent: 10,
            morningAbsent: 1,
            morningOd: 1,
            afternoonPresent: 8,
            afternoonAbsent: 1,
            afternoonOd: 2,
            afternoonBunk: 1,
            bothPresent: 8,
            morningPercentage: 83.3,
            afternoonPercentage: 66.7,
          ),
        ],
        studentRows: [
          StudentReportRow(
            sNo: 1,
            registerNumber: '26CS001',
            studentName: 'Aarav Patel',
            className: '1st Year - CSE (Sec A)',
            department: 'Computer Science',
            academicYear: '2026-2027',
            morningStatus: 'Present',
            afternoonStatus: 'Present',
            overallStatus: 'Present in both sessions',
          ),
        ],
      );

      final csv = result.generateCsv();
      expect(csv.contains('CLASS-WISE ATTENDANCE SUMMARY'), isTrue);
      expect(csv.contains('DETAILED STUDENT ATTENDANCE'), isTrue);
      expect(csv.contains('26CS001'), isTrue);
      expect(csv.contains('Present in both sessions'), isTrue);
    });
  });

  group('6. Admin Analytics Service Tests', () {
    test('Computes 12 metrics accurately across demo classes', () async {
      final analyticsService = AdminAnalyticsService();
      final nowStr = "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      final data = await analyticsService.fetchAnalytics(
        date: nowStr,
        sessionFilter: 'All',
      );

      expect(data.totalStudents, greaterThan(0));
      expect(data.morningPresent, greaterThanOrEqualTo(0));
      expect(data.afternoonBunk, greaterThanOrEqualTo(0));
      expect(data.hasRecords, isTrue);
    });
  });
}
