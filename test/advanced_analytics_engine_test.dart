import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/services/advanced_analytics_engine.dart';

void main() {
  group('AdvancedAnalyticsEngine Attendance Calculations', () {
    test('1. Percentage formula correctly includes OD and Present in numerator', () {
      // 18 Present, 2 OD out of 25 conducted sessions = (18 + 2) / 25 * 100 = 80.0%
      final pct = AdvancedAnalyticsEngine.calculateAttendancePercentage(
        presentCount: 18,
        odCount: 2,
        totalConductedSessions: 25,
      );
      expect(pct, 80.0);

      // Strict percentage excludes OD: 18 / 25 * 100 = 72.0%
      final strictPct = AdvancedAnalyticsEngine.calculateStrictAttendancePercentage(
        presentCount: 18,
        totalConductedSessions: 25,
      );
      expect(strictPct, 72.0);
    });

    test('2. Zero conducted sessions safely returns 0.0% without division-by-zero or NaN', () {
      final pct = AdvancedAnalyticsEngine.calculateAttendancePercentage(
        presentCount: 0,
        odCount: 0,
        totalConductedSessions: 0,
      );
      expect(pct, 0.0);
      expect(pct.isNaN, isFalse);

      final strictPct = AdvancedAnalyticsEngine.calculateStrictAttendancePercentage(
        presentCount: 0,
        totalConductedSessions: 0,
      );
      expect(strictPct, 0.0);
      expect(strictPct.isNaN, isFalse);
    });

    test('3. Missing attendance records are explicitly counted in denominator and not marked present', () {
      final student1 = Student(
        id: 's1',
        registerNumber: '26CS001',
        fullName: 'Aarav Sharma',
        active: true,
        createdAt: DateTime.now(),
      );

      final class1 = ClassModel(
        id: 'c1',
        className: 'CSE-A',
        department: 'Computer Science',
        academicYear: '2025-2026',
        active: true,
        createdAt: DateTime.now(),
      );

      // 4 conducted sessions for class c1
      final sessions = [
        AttendanceSession(
          id: 'sess1',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
        AttendanceSession(
          id: 'sess2',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
        AttendanceSession(
          id: 'sess3',
          classId: 'c1',
          attendanceDate: '2026-03-02',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
        AttendanceSession(
          id: 'sess4',
          classId: 'c1',
          attendanceDate: '2026-03-02',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
      ];

      // Student only has records for sess1 (present) and sess2 (absent).
      // sess3 and sess4 have NO records for student1 (Missing records!).
      final records = [
        AttendanceRecord(
          id: 'r1',
          sessionId: 'sess1',
          studentId: 's1',
          status: AttendanceStatus.present,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
        AttendanceRecord(
          id: 'r2',
          sessionId: 'sess2',
          studentId: 's1',
          status: AttendanceStatus.absent,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
      ];

      final metrics = AdvancedAnalyticsEngine.computeStudentPerformanceList(
        students: [student1],
        classMap: {'c1': class1},
        studentClassMap: {'s1': 'c1'},
        sessions: sessions,
        records: records,
      );

      expect(metrics.length, 1);
      final m = metrics.first;

      // Total conducted sessions must be 4
      expect(m.totalConductedSessions, 4);
      expect(m.presentCount, 1);
      expect(m.absentCount, 1);
      expect(m.odCount, 0);
      expect(m.bunkCount, 0);

      // Missing records explicitly counted: 4 conducted - 2 marked = 2 unmarked
      expect(m.unmarkedCount, 2);

      // Percentage is 1 present / 4 conducted = 25.0% (NOT 50.0%)
      expect(m.attendancePercentage, 25.0);

      // Risk level must be critical (<50%)
      expect(m.riskLevel, AttendanceRiskLevel.critical);
    });

    test('4. Risk level thresholds categorize boundaries correctly', () {
      const config = RiskThresholdConfig(
        criticalThreshold: 50.0,
        highRiskThreshold: 65.0,
        warningThreshold: 75.0,
      );

      expect(config.evaluate(49.99), AttendanceRiskLevel.critical);
      expect(config.evaluate(50.0), AttendanceRiskLevel.highRisk);
      expect(config.evaluate(64.99), AttendanceRiskLevel.highRisk);
      expect(config.evaluate(65.0), AttendanceRiskLevel.warning);
      expect(config.evaluate(74.99), AttendanceRiskLevel.warning);
      expect(config.evaluate(75.0), AttendanceRiskLevel.good);
      expect(config.evaluate(100.0), AttendanceRiskLevel.good);
    });

    test('5. Configurable thresholds adapt appropriately', () {
      // Custom institutional thresholds: critical < 60%, warning < 85%
      const customConfig = RiskThresholdConfig(
        criticalThreshold: 60.0,
        highRiskThreshold: 75.0,
        warningThreshold: 85.0,
      );

      expect(customConfig.evaluate(55.0), AttendanceRiskLevel.critical);
      expect(customConfig.evaluate(70.0), AttendanceRiskLevel.highRisk);
      expect(customConfig.evaluate(80.0), AttendanceRiskLevel.warning);
      expect(customConfig.evaluate(85.0), AttendanceRiskLevel.good);
    });

    test('6. Bunk ranking sorts descending by bunk count and calculates monthly delta', () {
      final s1Metric = StudentPerformanceMetric(
        studentId: 's1',
        registerNumber: '26CS001',
        fullName: 'Student One',
        classId: 'c1',
        className: 'CSE-A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 20,
        presentCount: 10,
        absentCount: 5,
        odCount: 0,
        bunkCount: 5,
        unmarkedCount: 0,
        morningConducted: 10,
        morningPresent: 8,
        morningAbsent: 2,
        morningOd: 0,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 10,
        afternoonPresent: 2,
        afternoonAbsent: 3,
        afternoonOd: 0,
        afternoonBunk: 5,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 5,
        attendancePercentage: 50.0,
        strictAttendancePercentage: 50.0,
        riskLevel: AttendanceRiskLevel.highRisk,
      );

      final s2Metric = StudentPerformanceMetric(
        studentId: 's2',
        registerNumber: '26CS002',
        fullName: 'Student Two',
        classId: 'c1',
        className: 'CSE-A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 20,
        presentCount: 16,
        absentCount: 3,
        odCount: 0,
        bunkCount: 1,
        unmarkedCount: 0,
        morningConducted: 10,
        morningPresent: 9,
        morningAbsent: 1,
        morningOd: 0,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 10,
        afternoonPresent: 7,
        afternoonAbsent: 2,
        afternoonOd: 0,
        afternoonBunk: 1,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 1,
        attendancePercentage: 80.0,
        strictAttendancePercentage: 80.0,
        riskLevel: AttendanceRiskLevel.good,
      );

      final sessions = [
        AttendanceSession(
          id: 'sess_feb',
          classId: 'c1',
          attendanceDate: '2026-02-10',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
        AttendanceSession(
          id: 'sess_mar',
          classId: 'c1',
          attendanceDate: '2026-03-10',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
      ];

      final records = [
        // s1 had 2 bunks in Feb, 3 bunks in Mar
        AttendanceRecord(
          id: 'b1',
          sessionId: 'sess_feb',
          studentId: 's1',
          status: AttendanceStatus.bunk,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
        AttendanceRecord(
          id: 'b2',
          sessionId: 'sess_feb',
          studentId: 's1',
          status: AttendanceStatus.bunk,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
        AttendanceRecord(
          id: 'b3',
          sessionId: 'sess_mar',
          studentId: 's1',
          status: AttendanceStatus.bunk,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
        // s2 had 1 bunk in Mar
        AttendanceRecord(
          id: 'b4',
          sessionId: 'sess_mar',
          studentId: 's2',
          status: AttendanceStatus.bunk,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
      ];

      final rankings = AdvancedAnalyticsEngine.rankBunkingStudents(
        performanceList: [s2Metric, s1Metric],
        sessions: sessions,
        records: records,
        currentMonth: 3,
        previousMonth: 2,
      );

      expect(rankings.length, 2);
      // Student 1 has 5 bunks -> Rank 1
      expect(rankings.first.studentId, 's1');
      expect(rankings.first.rank, 1);
      expect(rankings.first.totalBunkCount, 5);
      expect(rankings.first.previousMonthBunks, 2);
      expect(rankings.first.currentMonthBunks, 1);
      expect(rankings.first.monthToMonthDelta, -1);

      // Student 2 has 1 bunk -> Rank 2
      expect(rankings.last.studentId, 's2');
      expect(rankings.last.rank, 2);
    });

    test('7. Morning vs Afternoon shift discrepancy identifies afternoon shifts accurately', () {
      final student = Student(
        id: 's1',
        registerNumber: '26CS001',
        fullName: 'Aarav Sharma',
        active: true,
        createdAt: DateTime.now(),
      );

      final class1 = ClassModel(
        id: 'c1',
        className: 'CSE-A',
        department: 'CSE',
        academicYear: '2025-2026',
        active: true,
        createdAt: DateTime.now(),
      );

      final sessions = [
        AttendanceSession(
          id: 'm1',
          classId: 'c1',
          attendanceDate: '2026-03-05',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
        AttendanceSession(
          id: 'a1',
          classId: 'c1',
          attendanceDate: '2026-03-05',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
      ];

      // Student was PRESENT in morning, but BUNK in afternoon on 2026-03-05
      final records = [
        AttendanceRecord(
          id: 'r1',
          sessionId: 'm1',
          studentId: 's1',
          status: AttendanceStatus.present,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
        AttendanceRecord(
          id: 'r2',
          sessionId: 'a1',
          studentId: 's1',
          status: AttendanceStatus.bunk,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
      ];

      final discrepancies = AdvancedAnalyticsEngine.computeMorningAfternoonDiscrepancies(
        students: [student],
        classMap: {'c1': class1},
        studentClassMap: {'s1': 'c1'},
        sessions: sessions,
        records: records,
      );

      expect(discrepancies.length, 1);
      final d = discrepancies.first;
      expect(d.studentId, 's1');
      expect(d.morningStatus, AttendanceStatus.present);
      expect(d.afternoonStatus, AttendanceStatus.bunk);
      expect(d.discrepancyReason.contains('Afternoon Bunk'), isTrue);
    });

    test('8. Individual student analytics computes monthly trends and highest/lowest month', () {
      final metric = StudentPerformanceMetric(
        studentId: 's1',
        registerNumber: '26CS001',
        fullName: 'Aarav Sharma',
        classId: 'c1',
        className: 'CSE-A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 40,
        presentCount: 30,
        absentCount: 5,
        odCount: 5,
        bunkCount: 0,
        unmarkedCount: 0,
        morningConducted: 20,
        morningPresent: 18,
        morningAbsent: 2,
        morningOd: 0,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 20,
        afternoonPresent: 12,
        afternoonAbsent: 3,
        afternoonOd: 5,
        afternoonBunk: 0,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 0,
        attendancePercentage: 87.5,
        strictAttendancePercentage: 75.0,
        riskLevel: AttendanceRiskLevel.good,
      );

      // Sessions in Jan 2026 (10 sessions) and Feb 2026 (10 sessions)
      final janSessions = List.generate(
        10,
        (i) => AttendanceSession(
          id: 'jan_$i',
          classId: 'c1',
          attendanceDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          sessionType: i % 2 == 0 ? SessionType.morning : SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
      );

      final febSessions = List.generate(
        10,
        (i) => AttendanceSession(
          id: 'feb_$i',
          classId: 'c1',
          attendanceDate: '2026-02-${(i + 1).toString().padLeft(2, '0')}',
          sessionType: i % 2 == 0 ? SessionType.morning : SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
      );

      // Jan: 9 present, 1 absent = 90%
      final janRecords = List.generate(
        10,
        (i) => AttendanceRecord(
          id: 'r_jan_$i',
          sessionId: 'jan_$i',
          studentId: 's1',
          status: i < 9 ? AttendanceStatus.present : AttendanceStatus.absent,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
      );

      // Feb: 6 present, 4 absent = 60%
      final febRecords = List.generate(
        10,
        (i) => AttendanceRecord(
          id: 'r_feb_$i',
          sessionId: 'feb_$i',
          studentId: 's1',
          status: i < 6 ? AttendanceStatus.present : AttendanceStatus.absent,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
      );

      final analytics = AdvancedAnalyticsEngine.computeIndividualStudentAnalytics(
        studentMetric: metric,
        sessions: [...janSessions, ...febSessions],
        records: [...janRecords, ...febRecords],
        targetYear: 2026,
      );

      expect(analytics.monthlyTrends.length, 2);
      expect(analytics.highestAttendanceMonth?.month, 1); // Jan
      expect(analytics.highestAttendanceMonth?.attendancePercentage, 90.0);
      expect(analytics.lowestAttendanceMonth?.month, 2); // Feb
      expect(analytics.lowestAttendanceMonth?.attendancePercentage, 60.0);
      // Trend from Jan (90%) to Feb (60%) is declining (-30%)
      expect(analytics.trendDirection, AttendanceTrendDirection.declining);
      expect(analytics.trendChangeDelta, -30.0);
    });

    test('9. Department and Class comparisons aggregate figures accurately', () {
      final s1 = StudentPerformanceMetric(
        studentId: 's1',
        registerNumber: '26CS001',
        fullName: 'Student 1',
        classId: 'c1',
        className: 'CSE-A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 10,
        presentCount: 9,
        absentCount: 1,
        odCount: 0,
        bunkCount: 0,
        unmarkedCount: 0,
        morningConducted: 5,
        morningPresent: 5,
        morningAbsent: 0,
        morningOd: 0,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 5,
        afternoonPresent: 4,
        afternoonAbsent: 1,
        afternoonOd: 0,
        afternoonBunk: 0,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 0,
        attendancePercentage: 90.0,
        strictAttendancePercentage: 90.0,
        riskLevel: AttendanceRiskLevel.good,
      );

      final s2 = StudentPerformanceMetric(
        studentId: 's2',
        registerNumber: '26EC001',
        fullName: 'Student 2',
        classId: 'c2',
        className: 'ECE-A',
        department: 'ECE',
        academicYear: '2025-2026',
        totalConductedSessions: 10,
        presentCount: 4,
        absentCount: 6,
        odCount: 0,
        bunkCount: 2,
        unmarkedCount: 0,
        morningConducted: 5,
        morningPresent: 2,
        morningAbsent: 3,
        morningOd: 0,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 5,
        afternoonPresent: 2,
        afternoonAbsent: 3,
        afternoonOd: 0,
        afternoonBunk: 2,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 1,
        attendancePercentage: 40.0,
        strictAttendancePercentage: 40.0,
        riskLevel: AttendanceRiskLevel.critical,
      );

      final classMap = {
        'c1': ClassModel(
          id: 'c1',
          className: 'CSE-A',
          department: 'CSE',
          academicYear: '2025-2026',
          active: true,
          createdAt: DateTime.now(),
        ),
        'c2': ClassModel(
          id: 'c2',
          className: 'ECE-A',
          department: 'ECE',
          academicYear: '2025-2026',
          active: true,
          createdAt: DateTime.now(),
        ),
      };

      final deptComp = AdvancedAnalyticsEngine.computeDepartmentComparisons(
        performanceList: [s1, s2],
      );

      expect(deptComp.length, 2);
      // CSE is top department with 90%
      expect(deptComp.first.departmentName, 'CSE');
      expect(deptComp.first.averageAttendancePercentage, 90.0);
      expect(deptComp.first.studentsBelow50, 0);

      // ECE is second with 40%
      expect(deptComp.last.departmentName, 'ECE');
      expect(deptComp.last.averageAttendancePercentage, 40.0);
      expect(deptComp.last.studentsBelow50, 1);

      final classComp = AdvancedAnalyticsEngine.computeClassComparisons(
        performanceList: [s1, s2],
        classMap: classMap,
      );

      expect(classComp.length, 2);
      expect(classComp.first.className, 'CSE-A');
      expect(classComp.last.className, 'ECE-A');
    });

    test('10. Calendar heatmap computes day counts and intensity categories accurately', () {
      final sessions = [
        AttendanceSession(
          id: 's_day1_m',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
        AttendanceSession(
          id: 's_day1_a',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'u1',
          openedAt: DateTime.now(),
        ),
      ];

      // Total enrolled = 10 students. 2 sessions = 20 expected records.
      // 18 present, 2 absent = 90% -> intensity 4 (excellent >=85%)
      final records = [
        ...List.generate(
          9,
          (i) => AttendanceRecord(
            id: 'rec_m_$i',
            sessionId: 's_day1_m',
            studentId: 'st_$i',
            status: AttendanceStatus.present,
            markedBy: 'u1',
            markedAt: DateTime.now(),
          ),
        ),
        AttendanceRecord(
          id: 'rec_m_9',
          sessionId: 's_day1_m',
          studentId: 'st_9',
          status: AttendanceStatus.absent,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
        ...List.generate(
          9,
          (i) => AttendanceRecord(
            id: 'rec_a_$i',
            sessionId: 's_day1_a',
            studentId: 'st_$i',
            status: AttendanceStatus.present,
            markedBy: 'u1',
            markedAt: DateTime.now(),
          ),
        ),
        AttendanceRecord(
          id: 'rec_a_9',
          sessionId: 's_day1_a',
          studentId: 'st_9',
          status: AttendanceStatus.absent,
          markedBy: 'u1',
          markedAt: DateTime.now(),
        ),
      ];

      final heatmap = AdvancedAnalyticsEngine.computeCalendarHeatmap(
        year: 2026,
        month: 3,
        sessions: sessions,
        records: records,
        totalEnrolledStudents: 10,
      );

      // March has 31 days
      expect(heatmap.length, 31);

      // Day 1 conducted
      final day1 = heatmap.first;
      expect(day1.dayOfMonth, 1);
      expect(day1.isConducted, isTrue);
      expect(day1.morningConducted, isTrue);
      expect(day1.afternoonConducted, isTrue);
      expect(day1.totalExpectedRecords, 20);
      expect(day1.presentCount, 18);
      expect(day1.absentCount, 2);
      expect(day1.attendancePercentage, 90.0);
      expect(day1.intensityLevel, 4);

      // Day 2 was not conducted (intensity 0)
      final day2 = heatmap[1];
      expect(day2.isConducted, isFalse);
      expect(day2.intensityLevel, 0);
      expect(day2.attendancePercentage, 0.0);
    });
  });
}
