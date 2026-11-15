import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/services/advanced_analytics_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Analytics & Visual Modules Tests', () {
    // -------------------------------------------------------------------------
    // 1. MONTHLY BUNK RANKINGS TEST
    // -------------------------------------------------------------------------
    test('1. Bunk rankings sort descending by bunks, calculate MoM delta & month breakdown', () {
      final performanceList = [
        StudentPerformanceMetric(
          studentId: 's1',
          registerNumber: 'REG01',
          fullName: 'Alice CSE',
          classId: 'c1',
          className: 'CSE-1A',
          department: 'CSE',
          academicYear: '2025-2026',
          totalConductedSessions: 20,
          presentCount: 16,
          absentCount: 0,
          odCount: 0,
          bunkCount: 4, // 4 bunks
          unmarkedCount: 0,
          morningConducted: 10,
          morningPresent: 10,
          morningAbsent: 0,
          morningOd: 0,
          morningBunk: 0,
          morningUnmarked: 0,
          afternoonConducted: 10,
          afternoonPresent: 6,
          afternoonAbsent: 0,
          afternoonOd: 0,
          afternoonBunk: 4,
          afternoonUnmarked: 0,
          afternoonShiftDiscrepancyCount: 4,
          attendancePercentage: 80.0,
          strictAttendancePercentage: 80.0,
          riskLevel: AttendanceRiskLevel.good,
        ),
        StudentPerformanceMetric(
          studentId: 's2',
          registerNumber: 'REG02',
          fullName: 'Bob CSE',
          classId: 'c1',
          className: 'CSE-1A',
          department: 'CSE',
          academicYear: '2025-2026',
          totalConductedSessions: 20,
          presentCount: 12,
          absentCount: 0,
          odCount: 0,
          bunkCount: 8, // 8 bunks (Highest)
          unmarkedCount: 0,
          morningConducted: 10,
          morningPresent: 8,
          morningAbsent: 0,
          morningOd: 0,
          morningBunk: 2,
          morningUnmarked: 0,
          afternoonConducted: 10,
          afternoonPresent: 4,
          afternoonAbsent: 0,
          afternoonOd: 0,
          afternoonBunk: 6,
          afternoonUnmarked: 0,
          afternoonShiftDiscrepancyCount: 6,
          attendancePercentage: 60.0,
          strictAttendancePercentage: 60.0,
          riskLevel: AttendanceRiskLevel.highRisk,
        ),
        StudentPerformanceMetric(
          studentId: 's3',
          registerNumber: 'REG03',
          fullName: 'Charlie CSE',
          classId: 'c1',
          className: 'CSE-1A',
          department: 'CSE',
          academicYear: '2025-2026',
          totalConductedSessions: 20,
          presentCount: 19,
          absentCount: 0,
          odCount: 0,
          bunkCount: 1, // 1 bunk
          unmarkedCount: 0,
          morningConducted: 10,
          morningPresent: 10,
          morningAbsent: 0,
          morningOd: 0,
          morningBunk: 0,
          morningUnmarked: 0,
          afternoonConducted: 10,
          afternoonPresent: 9,
          afternoonAbsent: 0,
          afternoonOd: 0,
          afternoonBunk: 1,
          afternoonUnmarked: 0,
          afternoonShiftDiscrepancyCount: 1,
          attendancePercentage: 95.0,
          strictAttendancePercentage: 95.0,
          riskLevel: AttendanceRiskLevel.good,
        ),
      ];

      // Sessions in February (Month 2) and March (Month 3)
      final List<AttendanceSession> sessions = [
        AttendanceSession(
          id: 'sess_feb',
          classId: 'c1',
          attendanceDate: '2026-02-10',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 2, 10, 12, 20),
        ),
        AttendanceSession(
          id: 'sess_mar',
          classId: 'c1',
          attendanceDate: '2026-03-10',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 10, 12, 20),
        ),
      ];

      final List<AttendanceRecord> records = [
        AttendanceRecord(
          id: 'r1',
          sessionId: 'sess_feb',
          studentId: 's2',
          status: AttendanceStatus.bunk,
          markedBy: 'coord',
          markedAt: DateTime(2026, 2, 10),
        ),
        AttendanceRecord(
          id: 'r2',
          sessionId: 'sess_mar',
          studentId: 's2',
          status: AttendanceStatus.bunk,
          markedBy: 'coord',
          markedAt: DateTime(2026, 3, 10),
        ),
      ];

      final rankings = AdvancedAnalyticsEngine.rankBunkingStudents(
        performanceList: performanceList,
        sessions: sessions,
        records: records,
        currentMonth: 3,
        previousMonth: 2,
      );

      // Verify descending order
      expect(rankings.length, 3);
      expect(rankings[0].studentId, 's2'); // Bob: 8 bunks
      expect(rankings[0].rank, 1);
      expect(rankings[0].totalBunkCount, 8);
      expect(rankings[0].previousMonthBunks, 1);
      expect(rankings[0].currentMonthBunks, 1);
      expect(rankings[0].monthToMonthDelta, 0);

      expect(rankings[1].studentId, 's1'); // Alice: 4 bunks
      expect(rankings[1].rank, 2);

      expect(rankings[2].studentId, 's3'); // Charlie: 1 bunk
      expect(rankings[2].rank, 3);
    });

    // -------------------------------------------------------------------------
    // 2. STUDENT SORTING AND PAGINATION TEST
    // -------------------------------------------------------------------------
    test('2. Student roster sorting and pagination functions accurately', () {
      final list = List.generate(25, (i) {
        return StudentPerformanceMetric(
          studentId: 's$i',
          registerNumber: 'REG${i.toString().padLeft(2, '0')}',
          fullName: 'Student $i',
          classId: 'c1',
          className: 'CSE-1A',
          department: 'CSE',
          academicYear: '2025-2026',
          totalConductedSessions: 10,
          presentCount: i % 10,
          absentCount: 10 - (i % 10),
          odCount: 0,
          bunkCount: (25 - i) % 5,
          unmarkedCount: 0,
          morningConducted: 5,
          morningPresent: 4,
          morningAbsent: 1,
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
          attendancePercentage: (i % 10) * 10.0,
          strictAttendancePercentage: (i % 10) * 10.0,
          riskLevel: (i % 10) * 10.0 >= 75 ? AttendanceRiskLevel.good : AttendanceRiskLevel.critical,
        );
      });

      // Sort by attendance % descending
      final sortedByPctDesc = List<StudentPerformanceMetric>.from(list)
        ..sort((a, b) => b.attendancePercentage.compareTo(a.attendancePercentage));

      expect(sortedByPctDesc.first.attendancePercentage, 90.0);
      expect(sortedByPctDesc.last.attendancePercentage, 0.0);

      // Pagination with pageSize = 10
      const pageSize = 10;
      final totalPages = (list.length / pageSize).ceil();
      expect(totalPages, 3);

      // Page 1
      final page1 = sortedByPctDesc.sublist(0, 10);
      expect(page1.length, 10);

      // Page 3 (final 5 items)
      final page3 = sortedByPctDesc.sublist(20, 25);
      expect(page3.length, 5);
    });

    // -------------------------------------------------------------------------
    // 3. INDIVIDUAL MONTHLY ATTENDANCE TRENDS TEST
    // -------------------------------------------------------------------------
    test('3. Individual student monthly drilldown extracts highest, lowest & trend direction', () {
      final student = StudentPerformanceMetric(
        studentId: 's1',
        registerNumber: 'REG01',
        fullName: 'Alice CSE',
        classId: 'c1',
        className: 'CSE-1A',
        department: 'CSE',
        academicYear: '2025-2026',
        totalConductedSessions: 30,
        presentCount: 24,
        absentCount: 3,
        odCount: 3,
        bunkCount: 0,
        unmarkedCount: 0,
        morningConducted: 15,
        morningPresent: 13,
        morningAbsent: 1,
        morningOd: 1,
        morningBunk: 0,
        morningUnmarked: 0,
        afternoonConducted: 15,
        afternoonPresent: 11,
        afternoonAbsent: 2,
        afternoonOd: 2,
        afternoonBunk: 0,
        afternoonUnmarked: 0,
        afternoonShiftDiscrepancyCount: 0,
        attendancePercentage: 90.0,
        strictAttendancePercentage: 80.0, // Excluding 3 ODs
        riskLevel: AttendanceRiskLevel.good,
      );

      final List<AttendanceSession> sessions = [
        // Jan: 10 sessions, 7 present -> 70%
        ...List.generate(
          10,
          (i) => AttendanceSession(
            id: 'jan_$i',
            classId: 'c1',
            attendanceDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
            sessionType: SessionType.morning,
            status: SessionStatus.closed,
            openedBy: 'coord',
            openedAt: DateTime(2026, 1, i + 1, 8, 15),
          ),
        ),
        // Feb: 10 sessions, 9 present + 1 OD -> 100%
        ...List.generate(
          10,
          (i) => AttendanceSession(
            id: 'feb_$i',
            classId: 'c1',
            attendanceDate: '2026-02-${(i + 1).toString().padLeft(2, '0')}',
            sessionType: SessionType.morning,
            status: SessionStatus.closed,
            openedBy: 'coord',
            openedAt: DateTime(2026, 2, i + 1, 8, 15),
          ),
        ),
      ];

      final List<AttendanceRecord> records = [
        ...List.generate(
          7,
          (i) => AttendanceRecord(
            id: 'rec_jan_$i',
            sessionId: 'jan_$i',
            studentId: 's1',
            status: AttendanceStatus.present,
            markedBy: 'c',
            markedAt: DateTime(2026, 1, i + 1),
          ),
        ),
        ...List.generate(
          3,
          (i) => AttendanceRecord(
            id: 'rec_jan_abs_${i + 7}',
            sessionId: 'jan_${i + 7}',
            studentId: 's1',
            status: AttendanceStatus.absent,
            markedBy: 'c',
            markedAt: DateTime(2026, 1, i + 8),
          ),
        ),
        ...List.generate(
          9,
          (i) => AttendanceRecord(
            id: 'rec_feb_$i',
            sessionId: 'feb_$i',
            studentId: 's1',
            status: AttendanceStatus.present,
            markedBy: 'c',
            markedAt: DateTime(2026, 2, i + 1),
          ),
        ),
        AttendanceRecord(
          id: 'rec_feb_od',
          sessionId: 'feb_9',
          studentId: 's1',
          status: AttendanceStatus.od,
          markedBy: 'c',
          markedAt: DateTime(2026, 2, 10),
        ),
      ];

      final individualAnalytics = AdvancedAnalyticsEngine.computeIndividualStudentAnalytics(
        studentMetric: student,
        sessions: sessions,
        records: records,
        targetYear: 2026,
      );

      expect(individualAnalytics.monthlyTrends.length, 2);
      expect(individualAnalytics.monthlyTrends[0].attendancePercentage, 70.0);
      expect(individualAnalytics.monthlyTrends[1].attendancePercentage, 100.0);

      // Highest: Feb (100%), Lowest: Jan (70%)
      expect(individualAnalytics.highestAttendanceMonth?.month, 2);
      expect(individualAnalytics.lowestAttendanceMonth?.month, 1);

      // Trajectory: 70% -> 100% is Improving
      expect(individualAnalytics.trendDirection, AttendanceTrendDirection.improving);
      expect(individualAnalytics.trendChangeDelta, 30.0);
    });

    // -------------------------------------------------------------------------
    // 4. DEPARTMENT AND CLASS COMPARISONS TEST
    // -------------------------------------------------------------------------
    test('4. Department and Class comparisons aggregate figures and at-risk counts accurately', () {
      final performanceList = [
        // CSE students
        StudentPerformanceMetric(
          studentId: 'cse1',
          registerNumber: 'REG_C1',
          fullName: 'Alice',
          classId: 'c_cse',
          className: 'CSE-1A',
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
        ),
        StudentPerformanceMetric(
          studentId: 'cse2',
          registerNumber: 'REG_C2',
          fullName: 'Bob',
          classId: 'c_cse',
          className: 'CSE-1A',
          department: 'CSE',
          academicYear: '2025-2026',
          totalConductedSessions: 10,
          presentCount: 6,
          absentCount: 0,
          odCount: 0,
          bunkCount: 4,
          unmarkedCount: 0,
          morningConducted: 5,
          morningPresent: 5,
          morningAbsent: 0,
          morningOd: 0,
          morningBunk: 0,
          morningUnmarked: 0,
          afternoonConducted: 5,
          afternoonPresent: 1,
          afternoonAbsent: 0,
          afternoonOd: 0,
          afternoonBunk: 4,
          afternoonUnmarked: 0,
          afternoonShiftDiscrepancyCount: 4,
          attendancePercentage: 60.0,
          strictAttendancePercentage: 60.0,
          riskLevel: AttendanceRiskLevel.highRisk,
        ),
        // ECE student
        StudentPerformanceMetric(
          studentId: 'ece1',
          registerNumber: 'REG_E1',
          fullName: 'David',
          classId: 'c_ece',
          className: 'ECE-1A',
          department: 'ECE',
          academicYear: '2025-2026',
          totalConductedSessions: 10,
          presentCount: 4,
          absentCount: 6,
          odCount: 0,
          bunkCount: 0,
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
          afternoonBunk: 0,
          afternoonUnmarked: 0,
          afternoonShiftDiscrepancyCount: 0,
          attendancePercentage: 40.0,
          strictAttendancePercentage: 40.0,
          riskLevel: AttendanceRiskLevel.critical,
        ),
      ];

      final deptComparisons = AdvancedAnalyticsEngine.computeDepartmentComparisons(
        performanceList: performanceList,
      );

      expect(deptComparisons.length, 2);

      final cse = deptComparisons.firstWhere((d) => d.departmentName == 'CSE');
      expect(cse.totalEnrolledStudents, 2);
      expect(cse.averageAttendancePercentage, 75.0); // (9 + 6) / 20 = 75%
      expect(cse.totalBunk, 4);
      expect(cse.studentsBelow75, 1);
      expect(cse.studentsBelow65, 1);
      expect(cse.studentsBelow50, 0);

      final ece = deptComparisons.firstWhere((d) => d.departmentName == 'ECE');
      expect(ece.totalEnrolledStudents, 1);
      expect(ece.averageAttendancePercentage, 40.0);
      expect(ece.studentsBelow50, 1);
    });

    // -------------------------------------------------------------------------
    // 5. MORNING VS. AFTERNOON SHIFT DISCREPANCIES TEST
    // -------------------------------------------------------------------------
    test('5. Session shift discrepancy flags students who attend morning but miss afternoon', () {
      final List<Student> students = [
        Student(
          id: 's1',
          registerNumber: 'REG01',
          fullName: 'Alice CSE',
          active: true,
          createdAt: DateTime.now(),
        ),
      ];

      final Map<String, ClassModel> classMap = {
        'c1': ClassModel(
          id: 'c1',
          className: 'CSE-1A',
          department: 'CSE',
          academicYear: '2025-2026',
          active: true,
          createdAt: DateTime.now(),
        ),
      };

      final Map<String, String> studentClassMap = {'s1': 'c1'};

      // Day 1: Both sessions conducted. Morning: Present, Afternoon: Bunk -> Discrepancy!
      // Day 2: Only morning session conducted (unconducted afternoon) -> Must NOT count as discrepancy!
      final List<AttendanceSession> sessions = [
        AttendanceSession(
          id: 'm1',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 1, 8, 15),
        ),
        AttendanceSession(
          id: 'a1',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.afternoon,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 1, 12, 20),
        ),
        AttendanceSession(
          id: 'm2',
          classId: 'c1',
          attendanceDate: '2026-03-02',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 2, 8, 15),
        ),
      ];

      final List<AttendanceRecord> records = [
        AttendanceRecord(
          id: 'r_m1',
          sessionId: 'm1',
          studentId: 's1',
          status: AttendanceStatus.present,
          markedBy: 'c',
          markedAt: DateTime(2026, 3, 1),
        ),
        AttendanceRecord(
          id: 'r_a1',
          sessionId: 'a1',
          studentId: 's1',
          status: AttendanceStatus.bunk,
          markedBy: 'c',
          markedAt: DateTime(2026, 3, 1),
        ),
        AttendanceRecord(
          id: 'r_m2',
          sessionId: 'm2',
          studentId: 's1',
          status: AttendanceStatus.present,
          markedBy: 'c',
          markedAt: DateTime(2026, 3, 2),
        ),
      ];

      final discrepancies = AdvancedAnalyticsEngine.computeMorningAfternoonDiscrepancies(
        students: students,
        classMap: classMap,
        studentClassMap: studentClassMap,
        sessions: sessions,
        records: records,
      );

      // Exactly 1 discrepancy flagged on 2026-03-01 (Day 2 is skipped because afternoon was not conducted)
      expect(discrepancies.length, 1);
      expect(discrepancies.first.studentId, 's1');
      expect(discrepancies.first.afternoonStatus, AttendanceStatus.bunk);
      expect(discrepancies.first.discrepancyReason.contains('Afternoon Bunk'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 6. CALENDAR HEATMAP CALCULATIONS TEST
    // -------------------------------------------------------------------------
    test('6. Calendar heatmap groups by date and evaluates intensity tiers correctly', () {
      final List<AttendanceSession> sessions = [
        // Day 1: 100% attendance -> Intensity 4
        AttendanceSession(
          id: 's_day1',
          classId: 'c1',
          attendanceDate: '2026-03-01',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 1, 8, 15),
        ),
        // Day 2: 60% attendance -> Intensity 2 (50-74%)
        AttendanceSession(
          id: 's_day2',
          classId: 'c1',
          attendanceDate: '2026-03-02',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 2, 8, 15),
        ),
        // Day 3: 30% attendance -> Intensity 1 (<50%)
        AttendanceSession(
          id: 's_day3',
          classId: 'c1',
          attendanceDate: '2026-03-03',
          sessionType: SessionType.morning,
          status: SessionStatus.closed,
          openedBy: 'coord',
          openedAt: DateTime(2026, 3, 3, 8, 15),
        ),
      ];

      final List<AttendanceRecord> records = [
        // Day 1: 10 present
        ...List.generate(
          10,
          (i) => AttendanceRecord(
            id: 'r_d1_$i',
            sessionId: 's_day1',
            studentId: 'st_$i',
            status: AttendanceStatus.present,
            markedBy: 'c',
            markedAt: DateTime(2026, 3, 1),
          ),
        ),
        // Day 2: 6 present, 4 absent
        ...List.generate(
          6,
          (i) => AttendanceRecord(
            id: 'r_d2_p_$i',
            sessionId: 's_day2',
            studentId: 'st_$i',
            status: AttendanceStatus.present,
            markedBy: 'c',
            markedAt: DateTime(2026, 3, 2),
          ),
        ),
        ...List.generate(
          4,
          (i) => AttendanceRecord(
            id: 'r_d2_a_$i',
            sessionId: 's_day2',
            studentId: 'st_${i + 6}',
            status: AttendanceStatus.absent,
            markedBy: 'c',
            markedAt: DateTime(2026, 3, 2),
          ),
        ),
        // Day 3: 3 present, 7 absent
        ...List.generate(
          3,
          (i) => AttendanceRecord(
            id: 'r_d3_p_$i',
            sessionId: 's_day3',
            studentId: 'st_$i',
            status: AttendanceStatus.present,
            markedBy: 'c',
            markedAt: DateTime(2026, 3, 3),
          ),
        ),
        ...List.generate(
          7,
          (i) => AttendanceRecord(
            id: 'r_d3_a_$i',
            sessionId: 's_day3',
            studentId: 'st_${i + 3}',
            status: AttendanceStatus.absent,
            markedBy: 'c',
            markedAt: DateTime(2026, 3, 3),
          ),
        ),
      ];

      final heatmap = AdvancedAnalyticsEngine.computeCalendarHeatmap(
        month: 3,
        year: 2026,
        sessions: sessions,
        records: records,
        totalEnrolledStudents: 10,
      );

      // March has 31 days
      expect(heatmap.length, 31);

      final day1 = heatmap.firstWhere((d) => d.dayOfMonth == 1);
      expect(day1.isConducted, isTrue);
      expect(day1.attendancePercentage, 100.0);
      expect(day1.intensityLevel, 4);

      final day2 = heatmap.firstWhere((d) => d.dayOfMonth == 2);
      expect(day2.attendancePercentage, 60.0);
      expect(day2.intensityLevel, 2);

      final day3 = heatmap.firstWhere((d) => d.dayOfMonth == 3);
      expect(day3.attendancePercentage, 30.0);
      expect(day3.intensityLevel, 1);

      // Day 4 has no sessions -> Intensity 0
      final day4 = heatmap.firstWhere((d) => d.dayOfMonth == 4);
      expect(day4.isConducted, isFalse);
      expect(day4.intensityLevel, 0);
    });

    // -------------------------------------------------------------------------
    // 7. EMPTY DATA & MISSING RECORDS SAFETY TEST
    // -------------------------------------------------------------------------
    test('7. Empty data safely computes zero without crashing and missing records count as unmarked', () {
      final emptyOverview = AdvancedAnalyticsEngine.computeMonthlyOverview(
        academicYear: '2025-2026',
        department: 'CSE',
        month: 3,
        year: 2026,
        performanceList: [],
        classComparisons: [],
      );

      expect(emptyOverview.totalEnrolledStudents, 0);
      expect(emptyOverview.averageAttendancePercentage, 0.0);
      expect(emptyOverview.studentsBelow50Count, 0);

      // Denominator formula: 1 conducted session, 0 records -> 1 unmarked session, 0.0%
      final pct = AdvancedAnalyticsEngine.calculateAttendancePercentage(
        presentCount: 0,
        odCount: 0,
        totalConductedSessions: 1,
      );
      expect(pct, 0.0);
    });

    // -------------------------------------------------------------------------
    // 8. HISTORICAL TRANSFERS RETENTION TEST
    // -------------------------------------------------------------------------
    test('8. Transferred students retain historical attendance correctly attributed to past class', () {
      // Student was in CSE-1A in 2024, transferred to CSE-1B in 2025
      final student = Student(
        id: 's_trans',
        registerNumber: 'REG_TR',
        fullName: 'Transferred Student',
        active: true,
        createdAt: DateTime.now(),
      );
      final pastClass = ClassModel(
        id: 'c_past',
        className: 'CSE-1A',
        department: 'CSE',
        academicYear: '2024-2025',
        active: false, // Inactive historical class!
        createdAt: DateTime(2024, 6, 1),
      );

      final pastSession = AttendanceSession(
        id: 'sess_past',
        classId: pastClass.id,
        attendanceDate: '2024-10-15',
        sessionType: SessionType.morning,
        status: SessionStatus.closed,
        openedBy: 'past-coord',
        openedAt: DateTime(2024, 10, 15, 8, 15),
      );

      final pastRecord = AttendanceRecord(
        id: 'rec_past',
        sessionId: pastSession.id,
        studentId: student.id,
        status: AttendanceStatus.present,
        markedBy: 'past-coord',
        markedAt: DateTime(2024, 10, 15),
      );

      final studentMetrics = AdvancedAnalyticsEngine.computeStudentPerformanceList(
        students: [student],
        classMap: {'c_past': pastClass},
        studentClassMap: {'s_trans': 'c_past'},
        sessions: [pastSession],
        records: [pastRecord],
        riskConfig: const RiskThresholdConfig(),
      );

      expect(studentMetrics.length, 1);
      final metric = studentMetrics.first;
      expect(metric.className, 'CSE-1A');
      expect(metric.academicYear, '2024-2025');
      expect(metric.totalConductedSessions, 1);
      expect(metric.presentCount, 1);
      expect(metric.attendancePercentage, 100.0);
    });
  });
}
