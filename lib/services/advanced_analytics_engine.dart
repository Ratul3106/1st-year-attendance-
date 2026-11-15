import 'package:intl/intl.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/class_model.dart';

/// Pure computational engine for Advanced Attendance Analytics.
///
/// Strictly enforces institutional calculation standards:
/// 1. Denominator is derived exclusively from valid, conducted sessions for each student's class.
/// 2. Missing attendance records are explicitly identified and penalized (never silently assumed present).
/// 3. Zero-division safe: returns 0.0% when conducted sessions are zero.
/// 4. OD is counted as attended in the primary percentage, but displayed distinctly.
/// 5. Historical class enrollments are preserved without cross-contamination.
class AdvancedAnalyticsEngine {
  /// Primary attendance percentage calculation:
  /// ((Present + OD) / TotalConductedSessions) * 100.0
  static double calculateAttendancePercentage({
    required int presentCount,
    required int odCount,
    required int totalConductedSessions,
  }) {
    if (totalConductedSessions <= 0) return 0.0;
    final attended = presentCount + odCount;
    final raw = (attended / totalConductedSessions) * 100.0;
    return double.parse(raw.clamp(0.0, 100.0).toStringAsFixed(2));
  }

  /// Strict attendance percentage calculation (excluding OD):
  /// (Present / TotalConductedSessions) * 100.0
  static double calculateStrictAttendancePercentage({
    required int presentCount,
    required int totalConductedSessions,
  }) {
    if (totalConductedSessions <= 0) return 0.0;
    final raw = (presentCount / totalConductedSessions) * 100.0;
    return double.parse(raw.clamp(0.0, 100.0).toStringAsFixed(2));
  }

  /// Evaluates attendance risk level based on the percentage and configuration thresholds.
  static AttendanceRiskLevel evaluateRiskLevel(
    double percentage, {
    RiskThresholdConfig config = const RiskThresholdConfig(),
  }) {
    return config.evaluate(percentage);
  }

  /// Computes performance metrics for every student in the dataset.
  ///
  /// [students]: List of students to evaluate.
  /// [classMap]: Map of classId -> ClassModel.
  /// [studentClassMap]: Map of studentId -> classId (preserves historical enrollment).
  /// [sessions]: Valid conducted sessions in the filtered timeframe.
  /// [records]: Attendance records mapped for these sessions.
  /// [riskConfig]: Configurable risk thresholds.
  static List<StudentPerformanceMetric> computeStudentPerformanceList({
    required List<Student> students,
    required Map<String, ClassModel> classMap,
    required Map<String, String> studentClassMap,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    RiskThresholdConfig riskConfig = const RiskThresholdConfig(),
  }) {
    // 1. Group conducted sessions by classId
    final Map<String, List<AttendanceSession>> sessionsByClass = {};
    final Map<String, AttendanceSession> sessionById = {};

    for (final session in sessions) {
      sessionById[session.id] = session;
      sessionsByClass.putIfAbsent(session.classId, () => []).add(session);
    }

    // 2. Group records by studentId -> sessionId -> record
    final Map<String, Map<String, AttendanceRecord>> studentSessionRecords = {};
    for (final record in records) {
      studentSessionRecords
          .putIfAbsent(record.studentId, () => {})[record.sessionId] = record;
    }

    final List<StudentPerformanceMetric> metrics = [];

    for (final student in students) {
      final classId = studentClassMap[student.id];
      final classModel = classId != null ? classMap[classId] : null;

      // Conducted sessions specifically for this student's enrolled class
      final classSessions =
          classId != null ? (sessionsByClass[classId] ?? []) : <AttendanceSession>[];

      int present = 0;
      int absent = 0;
      int od = 0;
      int bunk = 0;

      int mConducted = 0;
      int mPresent = 0;
      int mAbsent = 0;
      int mOd = 0;
      int mBunk = 0;

      int aConducted = 0;
      int aPresent = 0;
      int aAbsent = 0;
      int aOd = 0;
      int aBunk = 0;

      // Map date -> {morningStatus, afternoonStatus} for shift discrepancy tracking
      final Map<String, Map<String, AttendanceStatus>> dateSessionStatus = {};

      final studentRecords = studentSessionRecords[student.id] ?? {};

      for (final session in classSessions) {
        final rec = studentRecords[session.id];
        final isMorning = session.sessionType == SessionType.morning;

        if (isMorning) {
          mConducted++;
        } else {
          aConducted++;
        }

        if (rec != null) {
          dateSessionStatus.putIfAbsent(session.attendanceDate, () => {})[
              isMorning ? 'morning' : 'afternoon'] = rec.status;

          switch (rec.status) {
            case AttendanceStatus.present:
              present++;
              if (isMorning) {
                mPresent++;
              } else {
                aPresent++;
              }
              break;
            case AttendanceStatus.absent:
              absent++;
              if (isMorning) {
                mAbsent++;
              } else {
                aAbsent++;
              }
              break;
            case AttendanceStatus.od:
              od++;
              if (isMorning) {
                mOd++;
              } else {
                aOd++;
              }
              break;
            case AttendanceStatus.bunk:
              bunk++;
              if (isMorning) {
                mBunk++;
              } else {
                aBunk++;
              }
              break;
          }
        }
      }

      final totalConducted = classSessions.length;
      final markedCount = present + absent + od + bunk;
      // Missing records are valid conducted sessions without an attendance record
      final unmarked = (totalConducted - markedCount).clamp(0, totalConducted);

      final mUnmarked = (mConducted - (mPresent + mAbsent + mOd + mBunk)).clamp(0, mConducted);
      final aUnmarked = (aConducted - (aPresent + aAbsent + aOd + aBunk)).clamp(0, aConducted);

      // Evaluate afternoon shift discrepancy count (Morning Present/OD -> Afternoon Absent/Bunk)
      int shiftDiscrepancies = 0;
      for (final dayEntry in dateSessionStatus.values) {
        final mStatus = dayEntry['morning'];
        final aStatus = dayEntry['afternoon'];
        if (mStatus != null && aStatus != null) {
          final attendedMorning = mStatus == AttendanceStatus.present || mStatus == AttendanceStatus.od;
          final unattendedAfternoon = aStatus == AttendanceStatus.bunk || aStatus == AttendanceStatus.absent;
          if (attendedMorning && unattendedAfternoon) {
            shiftDiscrepancies++;
          }
        }
      }

      final percentage = calculateAttendancePercentage(
        presentCount: present,
        odCount: od,
        totalConductedSessions: totalConducted,
      );

      final strictPercentage = calculateStrictAttendancePercentage(
        presentCount: present,
        totalConductedSessions: totalConducted,
      );

      final risk = evaluateRiskLevel(percentage, config: riskConfig);

      metrics.add(StudentPerformanceMetric(
        studentId: student.id,
        registerNumber: student.registerNumber,
        fullName: student.fullName,
        classId: classId ?? '',
        className: classModel?.className ?? 'Unassigned',
        department: classModel?.department ?? 'General',
        academicYear: classModel?.academicYear ?? '2025-2026',
        totalConductedSessions: totalConducted,
        presentCount: present,
        absentCount: absent,
        odCount: od,
        bunkCount: bunk,
        unmarkedCount: unmarked,
        morningConducted: mConducted,
        morningPresent: mPresent,
        morningAbsent: mAbsent,
        morningOd: mOd,
        morningBunk: mBunk,
        morningUnmarked: mUnmarked,
        afternoonConducted: aConducted,
        afternoonPresent: aPresent,
        afternoonAbsent: aAbsent,
        afternoonOd: aOd,
        afternoonBunk: aBunk,
        afternoonUnmarked: aUnmarked,
        afternoonShiftDiscrepancyCount: shiftDiscrepancies,
        attendancePercentage: percentage,
        strictAttendancePercentage: strictPercentage,
        riskLevel: risk,
      ));
    }

    return metrics;
  }

  /// Produces a descending ranking of students based on their Bunk count.
  ///
  /// Also aggregates month-by-month bunk occurrences and computes the month-to-month delta.
  static List<BunkRankingItem> rankBunkingStudents({
    required List<StudentPerformanceMetric> performanceList,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required int currentMonth,
    required int previousMonth,
  }) {
    final Map<String, AttendanceSession> sessionMap = {
      for (final s in sessions) s.id: s
    };

    // Map studentId -> month -> bunk count
    final Map<String, Map<int, int>> studentMonthlyBunks = {};

    for (final record in records) {
      if (record.status == AttendanceStatus.bunk) {
        final sess = sessionMap[record.sessionId];
        if (sess != null) {
          try {
            final date = DateTime.parse(sess.attendanceDate);
            final m = date.month;
            studentMonthlyBunks
                .putIfAbsent(record.studentId, () => {})
                .update(m, (v) => v + 1, ifAbsent: () => 1);
          } catch (_) {}
        }
      }
    }

    // Sort students descending by Bunk count; then ascending by attendance % as tie breaker
    final sorted = List<StudentPerformanceMetric>.from(performanceList)
      ..sort((a, b) {
        final bunkCmp = b.bunkCount.compareTo(a.bunkCount);
        if (bunkCmp != 0) return bunkCmp;
        return a.attendancePercentage.compareTo(b.attendancePercentage);
      });

    final List<BunkRankingItem> ranked = [];
    int rank = 1;

    for (final sp in sorted) {
      final monthlyMap = studentMonthlyBunks[sp.studentId] ?? {};
      final prevBunks = monthlyMap[previousMonth] ?? 0;
      final currBunks = monthlyMap[currentMonth] ?? 0;
      final delta = currBunks - prevBunks;

      ranked.add(BunkRankingItem(
        rank: rank++,
        studentId: sp.studentId,
        registerNumber: sp.registerNumber,
        fullName: sp.fullName,
        classId: sp.classId,
        className: sp.className,
        department: sp.department,
        totalBunkCount: sp.bunkCount,
        totalConductedSessions: sp.totalConductedSessions,
        attendancePercentage: sp.attendancePercentage,
        riskLevel: sp.riskLevel,
        monthlyBunkBreakdown: monthlyMap,
        previousMonthBunks: prevBunks,
        currentMonthBunks: currBunks,
        monthToMonthDelta: delta,
      ));
    }

    return ranked;
  }

  /// Computes monthly attendance percentage trends for an individual student across the academic year.
  static IndividualStudentAnalytics computeIndividualStudentAnalytics({
    required StudentPerformanceMetric studentMetric,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required int targetYear,
  }) {
    // Filter sessions specifically belonging to this student's enrolled class
    final classSessions = sessions.where((s) => s.classId == studentMetric.classId).toList();

    // Map month (1-12) -> List of sessions
    final Map<int, List<AttendanceSession>> sessionsByMonth = {};
    for (final sess in classSessions) {
      try {
        final dt = DateTime.parse(sess.attendanceDate);
        if (dt.year == targetYear || targetYear == 0) {
          sessionsByMonth.putIfAbsent(dt.month, () => []).add(sess);
        }
      } catch (_) {}
    }

    // Map sessionId -> record for this student
    final Map<String, AttendanceRecord> studentRecordsBySession = {};
    for (final rec in records) {
      if (rec.studentId == studentMetric.studentId) {
        studentRecordsBySession[rec.sessionId] = rec;
      }
    }

    final List<MonthlyStudentTrend> trends = [];

    // Evaluate all 12 months (or active academic months)
    final sortedMonths = sessionsByMonth.keys.toList()..sort();

    for (final m in sortedMonths) {
      final mSessions = sessionsByMonth[m] ?? [];
      int mPresent = 0;
      int mAbsent = 0;
      int mOd = 0;
      int mBunk = 0;

      for (final sess in mSessions) {
        final rec = studentRecordsBySession[sess.id];
        if (rec != null) {
          switch (rec.status) {
            case AttendanceStatus.present:
              mPresent++;
              break;
            case AttendanceStatus.absent:
              mAbsent++;
              break;
            case AttendanceStatus.od:
              mOd++;
              break;
            case AttendanceStatus.bunk:
              mBunk++;
              break;
          }
        }
      }

      final conducted = mSessions.length;
      final marked = mPresent + mAbsent + mOd + mBunk;
      final unmarked = (conducted - marked).clamp(0, conducted);

      final percentage = calculateAttendancePercentage(
        presentCount: mPresent,
        odCount: mOd,
        totalConductedSessions: conducted,
      );

      final dateSample = DateTime(targetYear > 0 ? targetYear : DateTime.now().year, m, 1);
      final label = DateFormat('MMM yyyy').format(dateSample);

      trends.add(MonthlyStudentTrend(
        month: m,
        year: targetYear,
        monthLabel: label,
        conductedSessions: conducted,
        presentCount: mPresent,
        absentCount: mAbsent,
        odCount: mOd,
        bunkCount: mBunk,
        unmarkedCount: unmarked,
        attendancePercentage: percentage,
      ));
    }

    MonthlyStudentTrend? highestMonth;
    MonthlyStudentTrend? lowestMonth;

    if (trends.isNotEmpty) {
      highestMonth = trends.reduce((curr, next) =>
          curr.attendancePercentage >= next.attendancePercentage ? curr : next);
      lowestMonth = trends.reduce((curr, next) =>
          curr.attendancePercentage <= next.attendancePercentage ? curr : next);
    }

    // Compute trend direction between the latest two months
    AttendanceTrendDirection direction = AttendanceTrendDirection.insufficientData;
    double delta = 0.0;

    if (trends.length >= 2) {
      final latest = trends.last.attendancePercentage;
      final prior = trends[trends.length - 2].attendancePercentage;
      delta = double.parse((latest - prior).toStringAsFixed(2));

      if (delta > 0.5) {
        direction = AttendanceTrendDirection.improving;
      } else if (delta < -0.5) {
        direction = AttendanceTrendDirection.declining;
      } else {
        direction = AttendanceTrendDirection.stable;
      }
    } else if (trends.length == 1) {
      direction = AttendanceTrendDirection.stable;
    }

    return IndividualStudentAnalytics(
      summary: studentMetric,
      monthlyTrends: trends,
      highestAttendanceMonth: highestMonth,
      lowestAttendanceMonth: lowestMonth,
      trendDirection: direction,
      trendChangeDelta: delta,
    );
  }

  /// Aggregates performance comparisons across departments.
  static List<DepartmentComparisonMetric> computeDepartmentComparisons({
    required List<StudentPerformanceMetric> performanceList,
  }) {
    final Map<String, List<StudentPerformanceMetric>> deptMap = {};
    for (final sp in performanceList) {
      deptMap.putIfAbsent(sp.department, () => []).add(sp);
    }

    final List<DepartmentComparisonMetric> list = [];

    for (final entry in deptMap.entries) {
      final deptName = entry.key;
      final students = entry.value;

      int present = 0;
      int absent = 0;
      int od = 0;
      int bunk = 0;
      int unmarked = 0;
      int totalConducted = 0;

      int below75 = 0;
      int below65 = 0;
      int below50 = 0;

      for (final s in students) {
        present += s.presentCount;
        absent += s.absentCount;
        od += s.odCount;
        bunk += s.bunkCount;
        unmarked += s.unmarkedCount;
        totalConducted += s.totalConductedSessions;

        if (s.attendancePercentage < 50.0) {
          below50++;
          below65++;
          below75++;
        } else if (s.attendancePercentage < 65.0) {
          below65++;
          below75++;
        } else if (s.attendancePercentage < 75.0) {
          below75++;
        }
      }

      final avgPct = calculateAttendancePercentage(
        presentCount: present,
        odCount: od,
        totalConductedSessions: totalConducted,
      );

      final bunkRate = students.isNotEmpty
          ? double.parse((bunk / students.length).toStringAsFixed(2))
          : 0.0;

      list.add(DepartmentComparisonMetric(
        departmentName: deptName,
        totalEnrolledStudents: students.length,
        totalConductedSessions: totalConducted,
        averageAttendancePercentage: avgPct,
        totalPresent: present,
        totalAbsent: absent,
        totalOd: od,
        totalBunk: bunk,
        totalUnmarked: unmarked,
        studentsBelow75: below75,
        studentsBelow65: below65,
        studentsBelow50: below50,
        bunkRate: bunkRate,
      ));
    }

    // Sort descending by average attendance %
    list.sort((a, b) => b.averageAttendancePercentage.compareTo(a.averageAttendancePercentage));
    return list;
  }

  /// Aggregates performance comparisons across classes.
  static List<ClassComparisonMetric> computeClassComparisons({
    required List<StudentPerformanceMetric> performanceList,
    required Map<String, ClassModel> classMap,
  }) {
    final Map<String, List<StudentPerformanceMetric>> classStudents = {};
    for (final sp in performanceList) {
      classStudents.putIfAbsent(sp.classId, () => []).add(sp);
    }

    final List<ClassComparisonMetric> list = [];

    for (final entry in classStudents.entries) {
      final classId = entry.key;
      final students = entry.value;
      final classModel = classMap[classId];

      int present = 0;
      int absent = 0;
      int od = 0;
      int bunk = 0;
      int unmarked = 0;
      int totalConducted = 0;

      int below75 = 0;
      int below65 = 0;
      int below50 = 0;

      for (final s in students) {
        present += s.presentCount;
        absent += s.absentCount;
        od += s.odCount;
        bunk += s.bunkCount;
        unmarked += s.unmarkedCount;
        totalConducted += s.totalConductedSessions;

        if (s.attendancePercentage < 50.0) {
          below50++;
          below65++;
          below75++;
        } else if (s.attendancePercentage < 65.0) {
          below65++;
        } else if (s.attendancePercentage < 75.0) {
          below75++;
        }
      }

      final avgPct = calculateAttendancePercentage(
        presentCount: present,
        odCount: od,
        totalConductedSessions: totalConducted,
      );

      final bunkRate = students.isNotEmpty
          ? double.parse((bunk / students.length).toStringAsFixed(2))
          : 0.0;

      list.add(ClassComparisonMetric(
        classId: classId,
        className: classModel?.className ?? (students.isNotEmpty ? students.first.className : classId),
        department: classModel?.department ?? (students.isNotEmpty ? students.first.department : 'General'),
        academicYear: classModel?.academicYear ?? '2025-2026',
        totalEnrolledStudents: students.length,
        totalConductedSessions: totalConducted,
        averageAttendancePercentage: avgPct,
        totalPresent: present,
        totalAbsent: absent,
        totalOd: od,
        totalBunk: bunk,
        totalUnmarked: unmarked,
        studentsBelow75: below75,
        studentsBelow65: below65,
        studentsBelow50: below50,
        bunkRate: bunkRate,
      ));
    }

    list.sort((a, b) => b.averageAttendancePercentage.compareTo(a.averageAttendancePercentage));
    return list;
  }

  /// Identifies all individual session shift discrepancies across dates.
  /// (Students present in the morning, but bunking or absent in the afternoon).
  static List<SessionShiftDiscrepancy> computeMorningAfternoonDiscrepancies({
    required List<Student> students,
    required Map<String, ClassModel> classMap,
    required Map<String, String> studentClassMap,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
  }) {
    // 1. Index sessions by date + classId -> {morningSessionId, afternoonSessionId}
    final Map<String, Map<String, String>> classDateSessions = {};
    for (final s in sessions) {
      final key = '${s.classId}_${s.attendanceDate}';
      final isMorning = s.sessionType == SessionType.morning;
      classDateSessions.putIfAbsent(key, () => {})[isMorning ? 'morning' : 'afternoon'] = s.id;
    }

    // 2. Index records by sessionId + studentId -> status
    final Map<String, AttendanceStatus> recordLookup = {};
    for (final r in records) {
      recordLookup['${r.sessionId}_${r.studentId}'] = r.status;
    }

    final List<SessionShiftDiscrepancy> discrepancies = [];

    for (final entry in classDateSessions.entries) {
      final parts = entry.key.split('_');
      final classId = parts[0];
      final dateStr = parts[1];
      final mSessId = entry.value['morning'];
      final aSessId = entry.value['afternoon'];

      // Both morning and afternoon sessions must be conducted to compare shifts
      if (mSessId == null || aSessId == null) continue;

      DateTime parsedDate;
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {
        parsedDate = DateTime.now();
      }

      final classModel = classMap[classId];

      for (final student in students) {
        if (studentClassMap[student.id] != classId) continue;

        final mStatus = recordLookup['${mSessId}_${student.id}'];
        final aStatus = recordLookup['${aSessId}_${student.id}'];

        if (mStatus != null && aStatus != null) {
          final attendedMorning = mStatus == AttendanceStatus.present || mStatus == AttendanceStatus.od;
          final unattendedAfternoon = aStatus == AttendanceStatus.bunk || aStatus == AttendanceStatus.absent;

          if (attendedMorning && unattendedAfternoon) {
            final reason = aStatus == AttendanceStatus.bunk
                ? 'Afternoon Bunk (Morning ${mStatus.displayName})'
                : 'Afternoon Absent (Morning ${mStatus.displayName})';

            discrepancies.add(SessionShiftDiscrepancy(
              studentId: student.id,
              registerNumber: student.registerNumber,
              studentName: student.fullName,
              className: classModel?.className ?? 'Class',
              department: classModel?.department ?? 'General',
              date: parsedDate,
              morningStatus: mStatus,
              afternoonStatus: aStatus,
              discrepancyReason: reason,
            ));
          }
        }
      }
    }

    // Sort descending by date
    discrepancies.sort((a, b) => b.date.compareTo(a.date));
    return discrepancies;
  }

  /// Builds a monthly calendar matrix with daily attendance percentages and intensity indicators.
  static List<DayHeatmapData> computeCalendarHeatmap({
    required int year,
    required int month,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required int totalEnrolledStudents,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final Map<String, List<AttendanceSession>> sessionsByDate = {};
    for (final s in sessions) {
      sessionsByDate.putIfAbsent(s.attendanceDate, () => []).add(s);
    }

    // Map sessionId -> records
    final Map<String, List<AttendanceRecord>> recordsBySession = {};
    for (final r in records) {
      recordsBySession.putIfAbsent(r.sessionId, () => []).add(r);
    }

    final List<DayHeatmapData> heatmap = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final daySessions = sessionsByDate[dateStr] ?? [];

      final isConducted = daySessions.isNotEmpty;
      bool mConducted = false;
      bool aConducted = false;

      int present = 0;
      int absent = 0;
      int od = 0;
      int bunk = 0;

      for (final sess in daySessions) {
        if (sess.sessionType == SessionType.morning) mConducted = true;
        if (sess.sessionType == SessionType.afternoon) aConducted = true;

        final sRecords = recordsBySession[sess.id] ?? [];
        for (final r in sRecords) {
          switch (r.status) {
            case AttendanceStatus.present:
              present++;
              break;
            case AttendanceStatus.absent:
              absent++;
              break;
            case AttendanceStatus.od:
              od++;
              break;
            case AttendanceStatus.bunk:
              bunk++;
              break;
          }
        }
      }

      final expectedRecords = daySessions.length * totalEnrolledStudents;
      final markedCount = present + absent + od + bunk;
      final unmarked = (expectedRecords - markedCount).clamp(0, expectedRecords);

      final pct = calculateAttendancePercentage(
        presentCount: present,
        odCount: od,
        totalConductedSessions: expectedRecords,
      );

      // Determine visual intensity level:
      // 0: No sessions conducted (Weekend/Holiday)
      // 1: Critical (<50%)
      // 2: Warning (50% - 74.9%)
      // 3: Good (75% - 84.9%)
      // 4: Excellent (≥85%)
      int intensity = 0;
      if (isConducted) {
        if (pct < 50.0) {
          intensity = 1;
        } else if (pct < 75.0) {
          intensity = 2;
        } else if (pct < 85.0) {
          intensity = 3;
        } else {
          intensity = 4;
        }
      }

      heatmap.add(DayHeatmapData(
        date: date,
        dayOfMonth: day,
        isConducted: isConducted,
        morningConducted: mConducted,
        afternoonConducted: aConducted,
        totalExpectedRecords: expectedRecords,
        presentCount: present,
        absentCount: absent,
        odCount: od,
        bunkCount: bunk,
        unmarkedCount: unmarked,
        attendancePercentage: pct,
        intensityLevel: intensity,
      ));
    }

    return heatmap;
  }

  /// Compiles the high-level Monthly Attendance Overview KPIs.
  static MonthlyAttendanceOverviewData computeMonthlyOverview({
    required String academicYear,
    required String department,
    required int month,
    required int year,
    required List<StudentPerformanceMetric> performanceList,
    required List<ClassComparisonMetric> classComparisons,
  }) {
    if (performanceList.isEmpty) {
      return MonthlyAttendanceOverviewData.empty();
    }

    int present = 0;
    int absent = 0;
    int od = 0;
    int bunk = 0;
    int unmarked = 0;
    int totalConducted = 0;

    int below75 = 0;
    int below65 = 0;
    int below50 = 0;
    int goodStanding = 0;

    for (final sp in performanceList) {
      present += sp.presentCount;
      absent += sp.absentCount;
      od += sp.odCount;
      bunk += sp.bunkCount;
      unmarked += sp.unmarkedCount;
      totalConducted += sp.totalConductedSessions;

      if (sp.attendancePercentage < 50.0) {
        below50++;
        below65++;
        below75++;
      } else if (sp.attendancePercentage < 65.0) {
        below65++;
        below75++;
      } else if (sp.attendancePercentage < 75.0) {
        below75++;
      } else {
        goodStanding++;
      }
    }

    final avgPercentage = calculateAttendancePercentage(
      presentCount: present,
      odCount: od,
      totalConductedSessions: totalConducted,
    );

    // Class benchmarks
    String highestClass = 'N/A';
    double highestPct = 0.0;
    String lowestClass = 'N/A';
    double lowestPct = 0.0;
    String highestBunkClass = 'N/A';
    int maxBunks = 0;

    if (classComparisons.isNotEmpty) {
      final sortedByPct = List<ClassComparisonMetric>.from(classComparisons)
        ..sort((a, b) => b.averageAttendancePercentage.compareTo(a.averageAttendancePercentage));

      highestClass = sortedByPct.first.className;
      highestPct = sortedByPct.first.averageAttendancePercentage;
      lowestClass = sortedByPct.last.className;
      lowestPct = sortedByPct.last.averageAttendancePercentage;

      final sortedByBunk = List<ClassComparisonMetric>.from(classComparisons)
        ..sort((a, b) => b.totalBunk.compareTo(a.totalBunk));

      highestBunkClass = sortedByBunk.first.className;
      maxBunks = sortedByBunk.first.totalBunk;
    }

    return MonthlyAttendanceOverviewData(
      academicYear: academicYear,
      department: department,
      month: month,
      year: year,
      totalEnrolledStudents: performanceList.length,
      totalConductedSessions: totalConducted,
      averageAttendancePercentage: avgPercentage,
      totalPresentRecords: present,
      totalAbsentRecords: absent,
      totalOdRecords: od,
      totalBunkRecords: bunk,
      totalUnmarkedRecords: unmarked,
      studentsBelow75Count: below75,
      studentsBelow65Count: below65,
      studentsBelow50Count: below50,
      studentsGoodStandingCount: goodStanding,
      highestAttendanceClassName: highestClass,
      highestAttendanceClassPercentage: highestPct,
      lowestAttendanceClassName: lowestClass,
      lowestAttendanceClassPercentage: lowestPct,
      highestBunkClassName: highestBunkClass,
      highestBunkCount: maxBunks,
    );
  }
}
