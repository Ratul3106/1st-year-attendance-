import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/services/advanced_analytics_service.dart';

void main() {
  group('AdvancedAnalyticsService Query & Session Validation Tests', () {
    final service = AdvancedAnalyticsService.instance;

    setUp(() {
      service.invalidateCache();
    });

    test('1. Strictly includes only closed sessions and excludes open sessions', () async {
      // In demo dataset for year 2026, month 3 has 15 days * 2 sessions = 30 sessions per class.
      // Day 15 afternoon session was explicitly set to SessionStatus.open.
      // Therefore, for each class in month 3, exactly 29 closed sessions must be evaluated (not 30).
      const filter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'Computer Science & Engineering',
        classId: 'class-cse-1a',
        month: 3,
        year: 2026,
        sessionFilter: 'Both',
      );

      final result = await service.fetchAnalytics(filter, forceRefresh: true);

      expect(result.studentPerformanceList.isNotEmpty, isTrue);
      final firstStudent = result.studentPerformanceList.first;

      // Exactly 29 closed sessions conducted for class-cse-1a in March 2026
      expect(firstStudent.totalConductedSessions, 29);
      expect(firstStudent.morningConducted, 15);
      // Afternoon conducted must be 14 (because day 15 afternoon is OPEN, so excluded!)
      expect(firstStudent.afternoonConducted, 14);
    });

    test('2. Missing attendance records in closed sessions are penalized and marked as unmarked', () async {
      const filter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'Computer Science & Engineering',
        classId: 'class-cse-1a',
        month: 3,
        year: 2026,
        sessionFilter: 'Both',
      );

      final result = await service.fetchAnalytics(filter, forceRefresh: true);

      // Student index 0 (std-1 Aarav Patel) had day 10 morning skipped
      final std1 = result.studentPerformanceList.firstWhere((s) => s.studentId == 'std-1');

      expect(std1.totalConductedSessions, 29);
      // Missing records on day 10 (both morning and afternoon skipped) must be recorded as 2 unmarked
      expect(std1.unmarkedCount, 2);
      expect(std1.morningUnmarked, 1);
      expect(std1.afternoonUnmarked, 1);
      // Attended count = 27 / 29 = 93.10%
      expect(std1.attendancePercentage < 100.0, isTrue);
    });

    test('3. Historical enrollment preserves class relationships without student duplication', () async {
      const filter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'All',
        classId: 'All',
        month: 3,
        year: 2026,
      );

      final result = await service.fetchAnalytics(filter, forceRefresh: true);

      // In demo dataset: 12 total unique students (6 in ECE, 6 in MECH)
      expect(result.studentPerformanceList.length, 12);

      // Ensure no duplicate student IDs exist across classes
      final ids = result.studentPerformanceList.map((s) => s.studentId).toSet();
      expect(ids.length, 12);

      // Verify each student belongs to their designated enrolled class
      final eceStudents = result.studentPerformanceList.where((s) => s.className.contains('ECE')).toList();
      final mechStudents = result.studentPerformanceList.where((s) => s.className.contains('MECH')).toList();
      expect(eceStudents.length, 6);
      expect(mechStudents.length, 6);
    });

    test('4. In-memory cache returns cached result on duplicate calls and refreshes on invalidateCache', () async {
      const filter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'Computer Science & Engineering',
        classId: 'class-cse-1a',
        month: 1,
        year: 2026,
      );

      final firstCall = await service.fetchAnalytics(filter);
      final secondCall = await service.fetchAnalytics(filter);

      // Both should have identical computedAt timestamp from cache
      expect(firstCall.computedAt, secondCall.computedAt);

      // Invalidate cache
      service.invalidateCache();

      // Force delay to ensure different millisecond timestamp
      await Future.delayed(const Duration(milliseconds: 10));
      final thirdCall = await service.fetchAnalytics(filter);

      expect(thirdCall.computedAt.isAfter(firstCall.computedAt), isTrue);
    });

    test('5. Session filtering isolates Morning and Afternoon correctly', () async {
      // 1. Morning Only
      const morningFilter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'Computer Science & Engineering',
        classId: 'class-cse-1a',
        month: 2,
        year: 2026,
        sessionFilter: 'Morning',
      );

      final morningResult = await service.fetchAnalytics(morningFilter, forceRefresh: true);
      final mStudent = morningResult.studentPerformanceList.first;
      expect(mStudent.totalConductedSessions, 15);
      expect(mStudent.afternoonConducted, 0);

      // 2. Afternoon Only
      const afternoonFilter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'Computer Science & Engineering',
        classId: 'class-cse-1a',
        month: 2,
        year: 2026,
        sessionFilter: 'Afternoon',
      );

      final afternoonResult = await service.fetchAnalytics(afternoonFilter, forceRefresh: true);
      final aStudent = afternoonResult.studentPerformanceList.first;
      expect(aStudent.totalConductedSessions, 15);
      expect(aStudent.morningConducted, 0);
    });

    test('6. Individual student analytics drilldown produces historical monthly trends', () async {
      const filter = AnalyticsFilterState(
        academicYear: '2026-2027',
        department: 'Computer Science & Engineering',
        classId: 'class-cse-1a',
        month: 3,
        year: 2026,
      );

      final result = await service.fetchAnalytics(filter);
      final student = result.studentPerformanceList.first;

      final drilldown = await service.fetchIndividualStudentAnalytics(
        studentId: student.studentId,
        filter: filter,
        studentMetric: student,
        targetYear: 2026,
      );

      expect(drilldown, isNotNull);
      expect(drilldown!.monthlyTrends.isNotEmpty, isTrue);
      // All 3 simulated months (Jan, Feb, Mar)
      expect(drilldown.monthlyTrends.length, 3);
      expect(drilldown.highestAttendanceMonth, isNotNull);
      expect(drilldown.lowestAttendanceMonth, isNotNull);
    });
  });
}
