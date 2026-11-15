import 'package:flutter/material.dart';
import 'package:student_attendance_system/models/attendance_record.dart';

/// Configurable risk levels for attendance monitoring.
enum AttendanceRiskLevel {
  critical,
  highRisk,
  warning,
  good;

  String get label {
    switch (this) {
      case AttendanceRiskLevel.critical:
        return 'Critical (<50%)';
      case AttendanceRiskLevel.highRisk:
        return 'High Risk (50-65%)';
      case AttendanceRiskLevel.warning:
        return 'Warning (65-75%)';
      case AttendanceRiskLevel.good:
        return 'Good Standing (≥75%)';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceRiskLevel.critical:
        return 'Critical';
      case AttendanceRiskLevel.highRisk:
        return 'High Risk';
      case AttendanceRiskLevel.warning:
        return 'Warning';
      case AttendanceRiskLevel.good:
        return 'Good';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceRiskLevel.critical:
        return const Color(0xFFD32F2F); // Deep Red
      case AttendanceRiskLevel.highRisk:
        return const Color(0xFFE65100); // Orange / Amber Deep
      case AttendanceRiskLevel.warning:
        return const Color(0xFFF57C00); // Amber
      case AttendanceRiskLevel.good:
        return const Color(0xFF2E7D32); // Deep Green
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AttendanceRiskLevel.critical:
        return const Color(0xFFFFEBEE);
      case AttendanceRiskLevel.highRisk:
        return const Color(0xFFFFF3E0);
      case AttendanceRiskLevel.warning:
        return const Color(0xFFFFF8E1);
      case AttendanceRiskLevel.good:
        return const Color(0xFFE8F5E9);
    }
  }
}

/// Threshold configuration for attendance risk stratification.
class RiskThresholdConfig {
  final double criticalThreshold; // Default: 50.0%
  final double highRiskThreshold; // Default: 65.0%
  final double warningThreshold; // Default: 75.0%

  const RiskThresholdConfig({
    this.criticalThreshold = 50.0,
    this.highRiskThreshold = 65.0,
    this.warningThreshold = 75.0,
  });

  AttendanceRiskLevel evaluate(double percentage) {
    if (percentage < criticalThreshold) {
      return AttendanceRiskLevel.critical;
    } else if (percentage < highRiskThreshold) {
      return AttendanceRiskLevel.highRisk;
    } else if (percentage < warningThreshold) {
      return AttendanceRiskLevel.warning;
    } else {
      return AttendanceRiskLevel.good;
    }
  }
}

/// Trend direction for individual student monthly performance.
enum AttendanceTrendDirection {
  improving,
  declining,
  stable,
  insufficientData;

  String get label {
    switch (this) {
      case AttendanceTrendDirection.improving:
        return 'Improving';
      case AttendanceTrendDirection.declining:
        return 'Declining';
      case AttendanceTrendDirection.stable:
        return 'Stable';
      case AttendanceTrendDirection.insufficientData:
        return 'N/A';
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceTrendDirection.improving:
        return Icons.trending_up;
      case AttendanceTrendDirection.declining:
        return Icons.trending_down;
      case AttendanceTrendDirection.stable:
        return Icons.trending_flat;
      case AttendanceTrendDirection.insufficientData:
        return Icons.remove;
    }
  }

  Color get color {
    switch (this) {
      case AttendanceTrendDirection.improving:
        return const Color(0xFF2E7D32);
      case AttendanceTrendDirection.declining:
        return const Color(0xFFD32F2F);
      case AttendanceTrendDirection.stable:
        return const Color(0xFF1976D2);
      case AttendanceTrendDirection.insufficientData:
        return Colors.grey;
    }
  }
}

/// Comprehensive performance metrics for a single student over a filtered period.
class StudentPerformanceMetric {
  final String studentId;
  final String registerNumber;
  final String fullName;
  final String classId;
  final String className;
  final String department;
  final String academicYear;

  // Conducted sessions for this student's class (The True Denominator)
  final int totalConductedSessions;

  // Actual records Breakdown
  final int presentCount;
  final int absentCount;
  final int odCount;
  final int bunkCount;

  // Missing / Unmarked conducted sessions (Never silently assumed present)
  final int unmarkedCount;

  // Session-wise Breakdown
  final int morningConducted;
  final int morningPresent;
  final int morningAbsent;
  final int morningOd;
  final int morningBunk;
  final int morningUnmarked;

  final int afternoonConducted;
  final int afternoonPresent;
  final int afternoonAbsent;
  final int afternoonOd;
  final int afternoonBunk;
  final int afternoonUnmarked;

  // Shift discrepancy: Morning present/OD, but afternoon absent/bunk
  final int afternoonShiftDiscrepancyCount;

  // Calculated attendance percentage: (Present + OD) / TotalConductedSessions * 100
  final double attendancePercentage;

  // Strict attendance percentage: Present / TotalConductedSessions * 100 (excluding OD)
  final double strictAttendancePercentage;

  // Risk categorization
  final AttendanceRiskLevel riskLevel;

  StudentPerformanceMetric({
    required this.studentId,
    required this.registerNumber,
    required this.fullName,
    required this.classId,
    required this.className,
    required this.department,
    required this.academicYear,
    required this.totalConductedSessions,
    required this.presentCount,
    required this.absentCount,
    required this.odCount,
    required this.bunkCount,
    required this.unmarkedCount,
    required this.morningConducted,
    required this.morningPresent,
    required this.morningAbsent,
    required this.morningOd,
    required this.morningBunk,
    required this.morningUnmarked,
    required this.afternoonConducted,
    required this.afternoonPresent,
    required this.afternoonAbsent,
    required this.afternoonOd,
    required this.afternoonBunk,
    required this.afternoonUnmarked,
    required this.afternoonShiftDiscrepancyCount,
    required this.attendancePercentage,
    required this.strictAttendancePercentage,
    required this.riskLevel,
  });

  /// Total attended sessions (Present + OD)
  int get totalAttendedCount => presentCount + odCount;

  /// Total unattended sessions (Absent + Bunk + Unmarked)
  int get totalUnattendedCount => absentCount + bunkCount + unmarkedCount;

  /// Morning percentage
  double get morningPercentage => morningConducted > 0
      ? ((morningPresent + morningOd) / morningConducted) * 100.0
      : 0.0;

  /// Afternoon percentage
  double get afternoonPercentage => afternoonConducted > 0
      ? ((afternoonPresent + afternoonOd) / afternoonConducted) * 100.0
      : 0.0;
}

/// Item in the Bunk Ranking Leaderboard.
class BunkRankingItem {
  final int rank;
  final String studentId;
  final String registerNumber;
  final String fullName;
  final String classId;
  final String className;
  final String department;
  final int totalBunkCount;
  final int totalConductedSessions;
  final double attendancePercentage;
  final AttendanceRiskLevel riskLevel;

  // Month-wise Bunk count mapping: Month Number (1-12) -> Bunk count
  final Map<int, int> monthlyBunkBreakdown;

  // Month-to-Month comparison
  final int previousMonthBunks;
  final int currentMonthBunks;
  final int monthToMonthDelta; // current - previous

  BunkRankingItem({
    required this.rank,
    required this.studentId,
    required this.registerNumber,
    required this.fullName,
    required this.classId,
    required this.className,
    required this.department,
    required this.totalBunkCount,
    required this.totalConductedSessions,
    required this.attendancePercentage,
    required this.riskLevel,
    required this.monthlyBunkBreakdown,
    required this.previousMonthBunks,
    required this.currentMonthBunks,
    required this.monthToMonthDelta,
  });
}

/// Monthly attendance summary for a single student over an academic year.
class MonthlyStudentTrend {
  final int month; // 1 - 12
  final int year;
  final String monthLabel; // e.g. "Jan 2026"
  final int conductedSessions;
  final int presentCount;
  final int absentCount;
  final int odCount;
  final int bunkCount;
  final int unmarkedCount;
  final double attendancePercentage;

  MonthlyStudentTrend({
    required this.month,
    required this.year,
    required this.monthLabel,
    required this.conductedSessions,
    required this.presentCount,
    required this.absentCount,
    required this.odCount,
    required this.bunkCount,
    required this.unmarkedCount,
    required this.attendancePercentage,
  });
}

/// Comprehensive individual student analytics package for the drilldown modal.
class IndividualStudentAnalytics {
  final StudentPerformanceMetric summary;
  final List<MonthlyStudentTrend> monthlyTrends;
  final MonthlyStudentTrend? highestAttendanceMonth;
  final MonthlyStudentTrend? lowestAttendanceMonth;
  final AttendanceTrendDirection trendDirection;
  final double trendChangeDelta; // Recent month % - Prior month %

  IndividualStudentAnalytics({
    required this.summary,
    required this.monthlyTrends,
    this.highestAttendanceMonth,
    this.lowestAttendanceMonth,
    required this.trendDirection,
    required this.trendChangeDelta,
  });
}

/// Comparison metric across departments.
class DepartmentComparisonMetric {
  final String departmentName;
  final int totalEnrolledStudents;
  final int totalConductedSessions;
  final double averageAttendancePercentage;
  final int totalPresent;
  final int totalAbsent;
  final int totalOd;
  final int totalBunk;
  final int totalUnmarked;
  final int studentsBelow75;
  final int studentsBelow65;
  final int studentsBelow50;
  final double bunkRate; // Average bunks per student

  DepartmentComparisonMetric({
    required this.departmentName,
    required this.totalEnrolledStudents,
    required this.totalConductedSessions,
    required this.averageAttendancePercentage,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalOd,
    required this.totalBunk,
    required this.totalUnmarked,
    required this.studentsBelow75,
    required this.studentsBelow65,
    required this.studentsBelow50,
    required this.bunkRate,
  });
}

/// Comparison metric across classes.
class ClassComparisonMetric {
  final String classId;
  final String className;
  final String department;
  final String academicYear;
  final int totalEnrolledStudents;
  final int totalConductedSessions;
  final double averageAttendancePercentage;
  final int totalPresent;
  final int totalAbsent;
  final int totalOd;
  final int totalBunk;
  final int totalUnmarked;
  final int studentsBelow75;
  final int studentsBelow65;
  final int studentsBelow50;
  final double bunkRate;

  ClassComparisonMetric({
    required this.classId,
    required this.className,
    required this.department,
    required this.academicYear,
    required this.totalEnrolledStudents,
    required this.totalConductedSessions,
    required this.averageAttendancePercentage,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalOd,
    required this.totalBunk,
    required this.totalUnmarked,
    required this.studentsBelow75,
    required this.studentsBelow65,
    required this.studentsBelow50,
    required this.bunkRate,
  });
}

/// Single session shift discrepancy record (e.g., Morning Present, Afternoon Bunk/Absent).
class SessionShiftDiscrepancy {
  final String studentId;
  final String registerNumber;
  final String studentName;
  final String className;
  final String department;
  final DateTime date;
  final AttendanceStatus morningStatus;
  final AttendanceStatus afternoonStatus;
  final String discrepancyReason;

  SessionShiftDiscrepancy({
    required this.studentId,
    required this.registerNumber,
    required this.studentName,
    required this.className,
    required this.department,
    required this.date,
    required this.morningStatus,
    required this.afternoonStatus,
    required this.discrepancyReason,
  });
}

/// Single day node in the monthly calendar heatmap.
class DayHeatmapData {
  final DateTime date;
  final int dayOfMonth;
  final bool isConducted;
  final bool morningConducted;
  final bool afternoonConducted;
  final int totalExpectedRecords;
  final int presentCount;
  final int absentCount;
  final int odCount;
  final int bunkCount;
  final int unmarkedCount;
  final double attendancePercentage;
  final int intensityLevel; // 0 = no class, 1 = <50%, 2 = 50-74%, 3 = 75-84%, 4 = >=85%

  DayHeatmapData({
    required this.date,
    required this.dayOfMonth,
    required this.isConducted,
    required this.morningConducted,
    required this.afternoonConducted,
    required this.totalExpectedRecords,
    required this.presentCount,
    required this.absentCount,
    required this.odCount,
    required this.bunkCount,
    required this.unmarkedCount,
    required this.attendancePercentage,
    required this.intensityLevel,
  });
}

/// Monthly attendance aggregated overview data for the primary KPI section.
class MonthlyAttendanceOverviewData {
  final String academicYear;
  final String department;
  final int month;
  final int year;
  final int totalEnrolledStudents;
  final int totalConductedSessions;
  final double averageAttendancePercentage;
  final int totalPresentRecords;
  final int totalAbsentRecords;
  final int totalOdRecords;
  final int totalBunkRecords;
  final int totalUnmarkedRecords;

  // Risk Threshold Student Counts
  final int studentsBelow75Count; // Warning
  final int studentsBelow65Count; // High Risk
  final int studentsBelow50Count; // Critical
  final int studentsGoodStandingCount; // Good (≥75%)

  // Benchmarks
  final String highestAttendanceClassName;
  final double highestAttendanceClassPercentage;
  final String lowestAttendanceClassName;
  final double lowestAttendanceClassPercentage;
  final String highestBunkClassName;
  final int highestBunkCount;

  MonthlyAttendanceOverviewData({
    required this.academicYear,
    required this.department,
    required this.month,
    required this.year,
    required this.totalEnrolledStudents,
    required this.totalConductedSessions,
    required this.averageAttendancePercentage,
    required this.totalPresentRecords,
    required this.totalAbsentRecords,
    required this.totalOdRecords,
    required this.totalBunkRecords,
    required this.totalUnmarkedRecords,
    required this.studentsBelow75Count,
    required this.studentsBelow65Count,
    required this.studentsBelow50Count,
    required this.studentsGoodStandingCount,
    required this.highestAttendanceClassName,
    required this.highestAttendanceClassPercentage,
    required this.lowestAttendanceClassName,
    required this.lowestAttendanceClassPercentage,
    required this.highestBunkClassName,
    required this.highestBunkCount,
  });

  factory MonthlyAttendanceOverviewData.empty() {
    return MonthlyAttendanceOverviewData(
      academicYear: 'All',
      department: 'All',
      month: DateTime.now().month,
      year: DateTime.now().year,
      totalEnrolledStudents: 0,
      totalConductedSessions: 0,
      averageAttendancePercentage: 0.0,
      totalPresentRecords: 0,
      totalAbsentRecords: 0,
      totalOdRecords: 0,
      totalBunkRecords: 0,
      totalUnmarkedRecords: 0,
      studentsBelow75Count: 0,
      studentsBelow65Count: 0,
      studentsBelow50Count: 0,
      studentsGoodStandingCount: 0,
      highestAttendanceClassName: 'N/A',
      highestAttendanceClassPercentage: 0.0,
      lowestAttendanceClassName: 'N/A',
      lowestAttendanceClassPercentage: 0.0,
      highestBunkClassName: 'N/A',
      highestBunkCount: 0,
    );
  }
}

/// State representation for interactive analytics filters.
class AnalyticsFilterState {
  final String academicYear;
  final String department;
  final String classId; // 'All' or specific class ID
  final int? month; // 1-12 or null for All Months
  final int year;
  final String sessionFilter; // 'Both', 'Morning', 'Afternoon'
  final String statusFilter; // 'All', 'Present', 'Absent', 'OD', 'Bunk'
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const AnalyticsFilterState({
    this.academicYear = 'All',
    this.department = 'All',
    this.classId = 'All',
    this.month,
    required this.year,
    this.sessionFilter = 'Both',
    this.statusFilter = 'All',
    this.customStartDate,
    this.customEndDate,
  });

  AnalyticsFilterState copyWith({
    String? academicYear,
    String? department,
    String? classId,
    int? month,
    bool clearMonth = false,
    int? year,
    String? sessionFilter,
    String? statusFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearDateRange = false,
  }) {
    return AnalyticsFilterState(
      academicYear: academicYear ?? this.academicYear,
      department: department ?? this.department,
      classId: classId ?? this.classId,
      month: clearMonth ? null : (month ?? this.month),
      year: year ?? this.year,
      sessionFilter: sessionFilter ?? this.sessionFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      customStartDate:
          clearDateRange ? null : (customStartDate ?? this.customStartDate),
      customEndDate:
          clearDateRange ? null : (customEndDate ?? this.customEndDate),
    );
  }

  static AnalyticsFilterState initial() {
    final now = DateTime.now();
    return AnalyticsFilterState(
      academicYear: 'All',
      department: 'All',
      classId: 'All',
      month: now.month,
      year: now.year,
      sessionFilter: 'Both',
      statusFilter: 'All',
    );
  }
}

/// Comprehensive packaged result holding all aggregated analytics for the active filters.
class AdvancedAnalyticsResult {
  final AnalyticsFilterState appliedFilters;
  final MonthlyAttendanceOverviewData overview;
  final List<StudentPerformanceMetric> studentPerformanceList;
  final List<BunkRankingItem> bunkRankings;
  final List<DepartmentComparisonMetric> departmentComparisons;
  final List<ClassComparisonMetric> classComparisons;
  final List<SessionShiftDiscrepancy> shiftDiscrepancies;
  final List<DayHeatmapData> calendarHeatmap;
  final DateTime computedAt;

  AdvancedAnalyticsResult({
    required this.appliedFilters,
    required this.overview,
    required this.studentPerformanceList,
    required this.bunkRankings,
    required this.departmentComparisons,
    required this.classComparisons,
    required this.shiftDiscrepancies,
    required this.calendarHeatmap,
    required this.computedAt,
  });

  factory AdvancedAnalyticsResult.empty([AnalyticsFilterState? filters]) {
    return AdvancedAnalyticsResult(
      appliedFilters: filters ?? AnalyticsFilterState.initial(),
      overview: MonthlyAttendanceOverviewData.empty(),
      studentPerformanceList: const [],
      bunkRankings: const [],
      departmentComparisons: const [],
      classComparisons: const [],
      shiftDiscrepancies: const [],
      calendarHeatmap: const [],
      computedAt: DateTime.now(),
    );
  }
}

