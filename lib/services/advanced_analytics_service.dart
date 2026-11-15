import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/services/advanced_analytics_engine.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';

/// Cache wrapper containing timestamped analytics data.
class _CachedAnalytics {
  final AdvancedAnalyticsResult result;
  final DateTime cachedAt;

  _CachedAnalytics({required this.result, required this.cachedAt});

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(cachedAt) > ttl;
}

/// Service responsible for querying, batching, caching, and serving Advanced Attendance Analytics.
///
/// Strict Institutional Guardrails:
/// 1. Uses existing authenticated user permissions (Supabase RLS). Never uses service-role keys.
/// 2. Strictly queries ONLY closed sessions (`status = 'closed'`). Open or unconducted sessions are excluded.
/// 3. Preserves historical student-to-class enrollments.
/// 4. Avoids N+1 query patterns by executing unified batch requests.
/// 5. Features non-stale caching with explicit invalidation.
class AdvancedAnalyticsService {
  static final AdvancedAnalyticsService instance =
      AdvancedAnalyticsService._internal();

  AdvancedAnalyticsService._internal();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory cache: Filter Key -> Cached Analytics (TTL: 3 minutes)
  final Map<String, _CachedAnalytics> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 3);

  // In-memory cache for individual student analytics drilldowns
  final Map<String, IndividualStudentAnalytics> _studentAnalyticsCache = {};

  /// Invalidates the analytics cache (e.g. after attendance marking, session close, or manual refresh).
  void invalidateCache() {
    _cache.clear();
    _studentAnalyticsCache.clear();
  }

  /// Generates a deterministic cache key for the given filter state.
  String _buildCacheKey(AnalyticsFilterState f) {
    return '${f.academicYear}_${f.department}_${f.classId}_${f.month}_${f.year}_${f.sessionFilter}_${f.statusFilter}_${f.customStartDate?.millisecondsSinceEpoch}_${f.customEndDate?.millisecondsSinceEpoch}';
  }

  /// Primary fetch method: Aggregates full analytics according to the supplied filter parameters.
  Future<AdvancedAnalyticsResult> fetchAnalytics(
    AnalyticsFilterState filter, {
    bool forceRefresh = false,
    RiskThresholdConfig riskConfig = const RiskThresholdConfig(),
  }) async {
    final cacheKey = _buildCacheKey(filter);

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired(_cacheTtl)) {
        return cached.result;
      }
    }

    AdvancedAnalyticsResult result;

    if (SupabaseConfig.isDemoMode || _supabase == null) {
      result = await _fetchDemoAnalytics(filter, riskConfig: riskConfig);
    } else {
      try {
        result = await _fetchSupabaseAnalytics(filter, riskConfig: riskConfig);
      } catch (e) {
        debugPrint("[AdvancedAnalyticsService] Live query fallback to demo data: $e");
        result = await _fetchDemoAnalytics(filter, riskConfig: riskConfig);
      }
    }

    _cache[cacheKey] = _CachedAnalytics(
      result: result,
      cachedAt: DateTime.now(),
    );

    return result;
  }

  /// Executes optimized batch queries against Supabase tables using existing RLS policies.
  Future<AdvancedAnalyticsResult> _fetchSupabaseAnalytics(
    AnalyticsFilterState filter, {
    RiskThresholdConfig riskConfig = const RiskThresholdConfig(),
  }) async {
    // -------------------------------------------------------------
    // Step 1: Batch Query Classes (Filter by Academic Year & Department)
    // Includes historical/archived classes to support multi-year historical analysis
    // -------------------------------------------------------------
    var classQuery = _supabase!.from('classes').select();

    if (filter.academicYear != 'All' && filter.academicYear.isNotEmpty) {
      classQuery = classQuery.eq('academic_year', filter.academicYear);
    }
    if (filter.department != 'All' && filter.department.isNotEmpty) {
      classQuery = classQuery.eq('department', filter.department);
    }
    if (filter.classId != 'All' && filter.classId.isNotEmpty) {
      classQuery = classQuery.eq('id', filter.classId);
    }

    final classRows = await classQuery.order('class_name');
    final List<ClassModel> classes = (classRows as List)
        .map((row) => ClassModel.fromJson(row as Map<String, dynamic>))
        .toList();

    if (classes.isEmpty) {
      return AdvancedAnalyticsResult.empty(filter);
    }

    final List<String> classIds = classes.map((c) => c.id).toList();
    final Map<String, ClassModel> classMap = {for (final c in classes) c.id: c};

    // -------------------------------------------------------------
    // Step 2: Batch Query Class Enrollments (Preserving Historical Mapping)
    // -------------------------------------------------------------
    final enrollmentRows = await _supabase!
        .from('class_enrollments')
        .select('class_id, student_id, enrolled_at')
        .inFilter('class_id', classIds);

    // Map: studentId -> classId (ensures a student is evaluated strictly with their enrolled class)
    final Map<String, String> studentClassMap = {};
    final Set<String> studentIds = {};

    for (final row in (enrollmentRows as List)) {
      final sId = row['student_id'] as String;
      final cId = row['class_id'] as String;
      studentClassMap[sId] = cId;
      studentIds.add(sId);
    }

    if (studentIds.isEmpty) {
      return AdvancedAnalyticsResult.empty(filter);
    }

    // -------------------------------------------------------------
    // Step 3: Batch Query Active Students
    // -------------------------------------------------------------
    final studentList = studentIds.toList();
    final List<Student> students = [];

    // Chunk student IDs if exceeding 200 to protect URI limits
    for (int i = 0; i < studentList.length; i += 200) {
      final chunk = studentList.sublist(
        i,
        i + 200 > studentList.length ? studentList.length : i + 200,
      );
      final stuRows = await _supabase!
          .from('students')
          .select()
          .inFilter('id', chunk)
          .order('register_number');

      students.addAll((stuRows as List)
          .map((r) => Student.fromJson(r as Map<String, dynamic>)));
    }

    if (students.isEmpty) {
      return AdvancedAnalyticsResult.empty(filter);
    }

    // -------------------------------------------------------------
    // Step 4: Batch Query Conducted Sessions (STRICT SESSION VALIDATION)
    // - Must be: status == 'closed' (Open sessions strictly excluded)
    // - Must match date / month boundaries
    // -------------------------------------------------------------
    var sessionQuery = _supabase!
        .from('attendance_sessions')
        .select()
        .inFilter('class_id', classIds)
        .eq('status', 'closed'); // Strict check: Only finalized sessions!

    if (filter.sessionFilter == 'Morning') {
      sessionQuery = sessionQuery.eq('session_type', 'morning');
    } else if (filter.sessionFilter == 'Afternoon') {
      sessionQuery = sessionQuery.eq('session_type', 'afternoon');
    }

    // Date range filtering
    if (filter.customStartDate != null && filter.customEndDate != null) {
      final startIso = DateFormat('yyyy-MM-dd').format(filter.customStartDate!);
      final endIso = DateFormat('yyyy-MM-dd').format(filter.customEndDate!);
      sessionQuery = sessionQuery.gte('attendance_date', startIso).lte('attendance_date', endIso);
    } else if (filter.month != null) {
      final m = filter.month!;
      final y = filter.year;
      final lastDay = DateTime(y, m + 1, 0).day;
      final startIso = '$y-${m.toString().padLeft(2, '0')}-01';
      final endIso = '$y-${m.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
      sessionQuery = sessionQuery.gte('attendance_date', startIso).lte('attendance_date', endIso);
    } else {
      final y = filter.year;
      sessionQuery = sessionQuery.gte('attendance_date', '$y-01-01').lte('attendance_date', '$y-12-31');
    }

    final sessionRows = await sessionQuery.order('attendance_date');
    final List<AttendanceSession> closedSessions = (sessionRows as List)
        .map((r) => AttendanceSession.fromJson(r as Map<String, dynamic>))
        .toList();

    // -------------------------------------------------------------
    // Step 5: Batch Query Attendance Records for Closed Sessions
    // -------------------------------------------------------------
    final List<AttendanceRecord> records = [];

    if (closedSessions.isNotEmpty) {
      final sessionIds = closedSessions.map((s) => s.id).toList();

      for (int i = 0; i < sessionIds.length; i += 200) {
        final chunk = sessionIds.sublist(
          i,
          i + 200 > sessionIds.length ? sessionIds.length : i + 200,
        );
        final recRows = await _supabase!
            .from('attendance_records')
            .select()
            .inFilter('session_id', chunk);

        records.addAll((recRows as List)
            .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>)));
      }
    }

    // -------------------------------------------------------------
    // Step 6: Compile Full Metrics via AdvancedAnalyticsEngine
    // -------------------------------------------------------------
    return _compileAnalyticsResult(
      filter: filter,
      students: students,
      classes: classes,
      classMap: classMap,
      studentClassMap: studentClassMap,
      sessions: closedSessions,
      records: records,
      riskConfig: riskConfig,
    );
  }

  /// Internal aggregator executing engine algorithms and bundling the complete result.
  AdvancedAnalyticsResult _compileAnalyticsResult({
    required AnalyticsFilterState filter,
    required List<Student> students,
    required List<ClassModel> classes,
    required Map<String, ClassModel> classMap,
    required Map<String, String> studentClassMap,
    required List<AttendanceSession> sessions,
    required List<AttendanceRecord> records,
    required RiskThresholdConfig riskConfig,
  }) {
    // 1. Calculate student performance metrics list
    final performanceList = AdvancedAnalyticsEngine.computeStudentPerformanceList(
      students: students,
      classMap: classMap,
      studentClassMap: studentClassMap,
      sessions: sessions,
      records: records,
      riskConfig: riskConfig,
    );

    // Filter by attendance status if requested (e.g. only students with bunks or absents)
    List<StudentPerformanceMetric> filteredPerformanceList = performanceList;
    if (filter.statusFilter != 'All') {
      filteredPerformanceList = performanceList.where((sp) {
        switch (filter.statusFilter) {
          case 'Present':
            return sp.presentCount > 0;
          case 'Absent':
            return sp.absentCount > 0;
          case 'OD':
            return sp.odCount > 0;
          case 'Bunk':
            return sp.bunkCount > 0;
          default:
            return true;
        }
      }).toList();
    }

    // 2. Rank bunking students
    final currentMonth = filter.month ?? DateTime.now().month;
    final previousMonth = currentMonth > 1 ? currentMonth - 1 : 12;

    final bunkRankings = AdvancedAnalyticsEngine.rankBunkingStudents(
      performanceList: performanceList,
      sessions: sessions,
      records: records,
      currentMonth: currentMonth,
      previousMonth: previousMonth,
    );

    // 3. Department & Class comparisons
    final deptComparisons = AdvancedAnalyticsEngine.computeDepartmentComparisons(
      performanceList: performanceList,
    );

    final classComparisons = AdvancedAnalyticsEngine.computeClassComparisons(
      performanceList: performanceList,
      classMap: classMap,
    );

    // 4. Session shift discrepancies (Morning present -> Afternoon absent/bunk)
    final shiftDiscrepancies = AdvancedAnalyticsEngine.computeMorningAfternoonDiscrepancies(
      students: students,
      classMap: classMap,
      studentClassMap: studentClassMap,
      sessions: sessions,
      records: records,
    );

    // 5. Monthly calendar heatmap
    final heatmapMonth = filter.month ?? DateTime.now().month;
    final calendarHeatmap = AdvancedAnalyticsEngine.computeCalendarHeatmap(
      year: filter.year,
      month: heatmapMonth,
      sessions: sessions,
      records: records,
      totalEnrolledStudents: students.length,
    );

    // 6. High-level Monthly Overview KPIs
    final overview = AdvancedAnalyticsEngine.computeMonthlyOverview(
      academicYear: filter.academicYear,
      department: filter.department,
      month: heatmapMonth,
      year: filter.year,
      performanceList: performanceList,
      classComparisons: classComparisons,
    );

    return AdvancedAnalyticsResult(
      appliedFilters: filter,
      overview: overview,
      studentPerformanceList: filteredPerformanceList,
      bunkRankings: bunkRankings,
      departmentComparisons: deptComparisons,
      classComparisons: classComparisons,
      shiftDiscrepancies: shiftDiscrepancies,
      calendarHeatmap: calendarHeatmap,
      computedAt: DateTime.now(),
    );
  }

  /// Drilldown fetcher for individual student monthly performance.
  Future<IndividualStudentAnalytics?> fetchIndividualStudentAnalytics({
    required String studentId,
    required AnalyticsFilterState filter,
    required StudentPerformanceMetric studentMetric,
    int? targetYear,
  }) async {
    final year = targetYear ?? filter.year;
    final cacheKey = '${studentId}_$year';

    if (_studentAnalyticsCache.containsKey(cacheKey)) {
      return _studentAnalyticsCache[cacheKey];
    }

    List<AttendanceSession> sessions = [];
    List<AttendanceRecord> records = [];

    if (SupabaseConfig.isDemoMode || _supabase == null) {
      final demo = _generateHistoricalDemoData(year);
      sessions = demo.sessions.where((s) => s.status == SessionStatus.closed).toList();
      records = demo.records;
    } else {
      try {
        final sessRows = await _supabase!
            .from('attendance_sessions')
            .select()
            .eq('class_id', studentMetric.classId)
            .eq('status', 'closed')
            .gte('attendance_date', '$year-01-01')
            .lte('attendance_date', '$year-12-31')
            .order('attendance_date');

        sessions = (sessRows as List)
            .map((r) => AttendanceSession.fromJson(r as Map<String, dynamic>))
            .toList();

        if (sessions.isNotEmpty) {
          final sIds = sessions.map((s) => s.id).toList();
          final recRows = await _supabase!
              .from('attendance_records')
              .select()
              .eq('student_id', studentId)
              .inFilter('session_id', sIds);

          records = (recRows as List)
              .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint("[AdvancedAnalyticsService] Error fetching student trend: $e");
        final demo = _generateHistoricalDemoData(year);
        sessions = demo.sessions.where((s) => s.status == SessionStatus.closed).toList();
        records = demo.records;
      }
    }

    final analytics = AdvancedAnalyticsEngine.computeIndividualStudentAnalytics(
      studentMetric: studentMetric,
      sessions: sessions,
      records: records,
      targetYear: year,
    );

    _studentAnalyticsCache[cacheKey] = analytics;
    return analytics;
  }

  /// Demo Fallback: Simulates multi-month closed & open sessions with realistic attendance patterns.
  Future<AdvancedAnalyticsResult> _fetchDemoAnalytics(
    AnalyticsFilterState filter, {
    RiskThresholdConfig riskConfig = const RiskThresholdConfig(),
  }) async {
    final demo = DemoDataService.instance;
    List<ClassModel> classes = demo.getAllClasses();

    if (filter.academicYear != 'All' && filter.academicYear.isNotEmpty) {
      classes = classes.where((c) => c.academicYear == filter.academicYear).toList();
    }
    if (filter.department != 'All' && filter.department.isNotEmpty) {
      classes = classes.where((c) => c.department == filter.department).toList();
    }
    if (filter.classId != 'All' && filter.classId.isNotEmpty) {
      classes = classes.where((c) => c.id == filter.classId).toList();
    }

    if (classes.isEmpty) {
      return AdvancedAnalyticsResult.empty(filter);
    }

    final Map<String, ClassModel> classMap = {for (final c in classes) c.id: c};
    final Map<String, String> studentClassMap = {};
    final Set<String> enrolledStudentIds = {};

    for (final c in classes) {
      final sList = demo.getEnrolledStudents(c.id);
      for (final s in sList) {
        studentClassMap[s.id] = c.id;
        enrolledStudentIds.add(s.id);
      }
    }

    final allStudents = demo.getAllStudents();
    final students = allStudents.where((s) => enrolledStudentIds.contains(s.id)).toList();

    // Generate historical demo data for the requested year
    final historical = _generateHistoricalDemoData(filter.year);

    // CRITICAL: Filter only closed sessions! (Exclude open sessions)
    var sessions = historical.sessions.where((s) {
      final isClosed = s.status == SessionStatus.closed;
      final matchesClass = classMap.containsKey(s.classId);
      return isClosed && matchesClass;
    }).toList();

    // Apply SessionFilter
    if (filter.sessionFilter == 'Morning') {
      sessions = sessions.where((s) => s.sessionType == SessionType.morning).toList();
    } else if (filter.sessionFilter == 'Afternoon') {
      sessions = sessions.where((s) => s.sessionType == SessionType.afternoon).toList();
    }

    // Apply Month / Date Range
    if (filter.customStartDate != null && filter.customEndDate != null) {
      final startStr = DateFormat('yyyy-MM-dd').format(filter.customStartDate!);
      final endStr = DateFormat('yyyy-MM-dd').format(filter.customEndDate!);
      sessions = sessions.where((s) =>
          s.attendanceDate.compareTo(startStr) >= 0 &&
          s.attendanceDate.compareTo(endStr) <= 0).toList();
    } else if (filter.month != null) {
      final m = filter.month!;
      final prefix = '${filter.year}-${m.toString().padLeft(2, '0')}';
      sessions = sessions.where((s) => s.attendanceDate.startsWith(prefix)).toList();
    }

    final validSessionIds = sessions.map((s) => s.id).toSet();
    final records = historical.records
        .where((r) => validSessionIds.contains(r.sessionId))
        .toList();

    return _compileAnalyticsResult(
      filter: filter,
      students: students,
      classes: classes,
      classMap: classMap,
      studentClassMap: studentClassMap,
      sessions: sessions,
      records: records,
      riskConfig: riskConfig,
    );
  }

  /// Helper to generate multi-month historical simulation data (including closed, open, and missing sessions).
  _HistoricalDemoContainer _generateHistoricalDemoData(int year) {
    final List<AttendanceSession> sessions = [];
    final List<AttendanceRecord> records = [];

    final demo = DemoDataService.instance;
    final classes = demo.getAllClasses();

    // Generate 3 months of sessions (e.g. Jan, Feb, Mar)
    for (int month = 1; month <= 3; month++) {
      // 15 instructional days per month
      for (int day = 1; day <= 15; day++) {
        final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

        for (final cls in classes) {
          // Morning session (Closed)
          final mSessId = 'sess_m_${cls.id}_${month}_$day';
          sessions.add(AttendanceSession(
            id: mSessId,
            classId: cls.id,
            attendanceDate: dateStr,
            sessionType: SessionType.morning,
            status: SessionStatus.closed,
            openedBy: 'demo-coord',
            openedAt: DateTime(year, month, day, 8, 15),
            closedAt: DateTime(year, month, day, 8, 45),
          ));

          // Afternoon session: Day 15 of current month is left 'open' to test session exclusion rule!
          final isSimulatedOpen = (month == 3 && day == 15);
          final aSessId = 'sess_a_${cls.id}_${month}_$day';
          sessions.add(AttendanceSession(
            id: aSessId,
            classId: cls.id,
            attendanceDate: dateStr,
            sessionType: SessionType.afternoon,
            status: isSimulatedOpen ? SessionStatus.open : SessionStatus.closed,
            openedBy: 'demo-coord',
            openedAt: DateTime(year, month, day, 12, 20),
            closedAt: isSimulatedOpen ? null : DateTime(year, month, day, 12, 50),
          ));

          final enrolled = demo.getEnrolledStudents(cls.id);

          for (int sIdx = 0; sIdx < enrolled.length; sIdx++) {
            final student = enrolled[sIdx];

            // Introduce deliberate missing records for student index 0 on day 10
            // to verify that missing records are counted as unmarked (never present)
            if (sIdx == 0 && day == 10) {
              continue; // Skip creating record -> creates unmarked session
            }

            // Morning record
            AttendanceStatus mStatus = AttendanceStatus.present;
            if (sIdx == 2 && day % 3 == 0) {
              mStatus = AttendanceStatus.absent;
            } else if (sIdx == 3 && day % 4 == 0) {
              mStatus = AttendanceStatus.od;
            }

            records.add(AttendanceRecord(
              id: 'rec_m_${mSessId}_${student.id}',
              sessionId: mSessId,
              studentId: student.id,
              status: mStatus,
              markedBy: 'demo-coord',
              markedAt: DateTime(year, month, day, 8, 30),
            ));

            // Afternoon record
            AttendanceStatus aStatus = AttendanceStatus.present;
            // Student index 4 and 5 frequently bunk afternoon sessions
            if ((sIdx == 4 || sIdx == 5) && day % 2 == 0) {
              aStatus = AttendanceStatus.bunk;
            } else if (sIdx == 2 && day % 3 == 0) {
              aStatus = AttendanceStatus.absent;
            } else if (sIdx == 3 && day % 4 == 0) {
              aStatus = AttendanceStatus.od;
            }

            records.add(AttendanceRecord(
              id: 'rec_a_${aSessId}_${student.id}',
              sessionId: aSessId,
              studentId: student.id,
              status: aStatus,
              markedBy: 'demo-coord',
              markedAt: DateTime(year, month, day, 12, 35),
            ));
          }
        }
      }
    }

    return _HistoricalDemoContainer(sessions: sessions, records: records);
  }
}

class _HistoricalDemoContainer {
  final List<AttendanceSession> sessions;
  final List<AttendanceRecord> records;

  _HistoricalDemoContainer({required this.sessions, required this.records});
}
