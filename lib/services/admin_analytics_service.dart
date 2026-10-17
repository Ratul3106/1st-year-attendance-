import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnalyticsData {
  final int totalStudents;
  final int morningPresent;
  final int morningAbsent;
  final int morningOd;
  final int afternoonPresent;
  final int afternoonAbsent;
  final int afternoonOd;
  final int afternoonBunk;
  final double morningPercentage;
  final double afternoonPercentage;
  final int studentsPresentBoth;
  final int studentsPresentMorningAbsentAfternoon;
  final bool hasRecords;
  final int totalClassesFiltered;

  AdminAnalyticsData({
    required this.totalStudents,
    required this.morningPresent,
    required this.morningAbsent,
    required this.morningOd,
    required this.afternoonPresent,
    required this.afternoonAbsent,
    required this.afternoonOd,
    required this.afternoonBunk,
    required this.morningPercentage,
    required this.afternoonPercentage,
    required this.studentsPresentBoth,
    required this.studentsPresentMorningAbsentAfternoon,
    required this.hasRecords,
    required this.totalClassesFiltered,
  });

  factory AdminAnalyticsData.empty({int totalStudents = 0, int totalClasses = 0}) {
    return AdminAnalyticsData(
      totalStudents: totalStudents,
      morningPresent: 0,
      morningAbsent: 0,
      morningOd: 0,
      afternoonPresent: 0,
      afternoonAbsent: 0,
      afternoonOd: 0,
      afternoonBunk: 0,
      morningPercentage: 0.0,
      afternoonPercentage: 0.0,
      studentsPresentBoth: 0,
      studentsPresentMorningAbsentAfternoon: 0,
      hasRecords: false,
      totalClassesFiltered: totalClasses,
    );
  }
}

class AdminAnalyticsService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Calculates aggregated metrics based on applied filters
  Future<AdminAnalyticsData> fetchAnalytics({
    String? academicYear,
    String? department,
    String? classId,
    required String date,
    String sessionFilter = 'All', // 'All', 'Morning', 'Afternoon'
  }) async {
    if (SupabaseConfig.isDemoMode) {
      return _calculateDemoAnalytics(
        academicYear: academicYear,
        department: department,
        classId: classId,
        date: date,
        sessionFilter: sessionFilter,
      );
    }

    try {
      // 1. Get filtered classes
      var classQuery = _supabase!.from('classes').select().eq('active', true);
      if (academicYear != null && academicYear.isNotEmpty && academicYear != 'All') {
        classQuery = classQuery.eq('academic_year', academicYear);
      }
      if (department != null && department.isNotEmpty && department != 'All') {
        classQuery = classQuery.eq('department', department);
      }
      if (classId != null && classId.isNotEmpty && classId != 'All') {
        classQuery = classQuery.eq('id', classId);
      }

      final classList = await classQuery;
      final filteredClassIds = (classList as List).map((c) => c['id'] as String).toList();

      if (filteredClassIds.isEmpty) {
        return AdminAnalyticsData.empty();
      }

      // 2. Fetch distinct enrolled students across filtered classes
      final enrollments = await _supabase!
          .from('class_enrollments')
          .select('student_id')
          .inFilter('class_id', filteredClassIds);

      final uniqueStudentIds = (enrollments as List)
          .map((e) => e['student_id'] as String)
          .toSet()
          .toList();

      if (uniqueStudentIds.isEmpty) {
        return AdminAnalyticsData.empty(totalClasses: filteredClassIds.length);
      }

      // 3. Fetch sessions for the date
      final sessions = await _supabase!
          .from('attendance_sessions')
          .select('id, session_type')
          .inFilter('class_id', filteredClassIds)
          .eq('attendance_date', date);

      final morningSessionIds = (sessions as List)
          .where((s) => s['session_type'] == 'morning')
          .map((s) => s['id'] as String)
          .toList();

      final afternoonSessionIds = sessions
          .where((s) => s['session_type'] == 'afternoon')
          .map((s) => s['id'] as String)
          .toList();

      if (morningSessionIds.isEmpty && afternoonSessionIds.isEmpty) {
        return AdminAnalyticsData.empty(
          totalStudents: uniqueStudentIds.length,
          totalClasses: filteredClassIds.length,
        );
      }

      // 4. Fetch records for these sessions
      final allSessionIds = [...morningSessionIds, ...afternoonSessionIds];
      final records = await _supabase!
          .from('attendance_records')
          .select('session_id, student_id, status')
          .inFilter('session_id', allSessionIds);

      final Map<String, AttendanceStatus> morningRecords = {};
      final Map<String, AttendanceStatus> afternoonRecords = {};

      for (var r in (records as List)) {
        final sessId = r['session_id'] as String;
        final stuId = r['student_id'] as String;
        final status = AttendanceStatus.fromString(r['status'] as String?);

        if (morningSessionIds.contains(sessId)) {
          morningRecords[stuId] = status;
        } else if (afternoonSessionIds.contains(sessId)) {
          afternoonRecords[stuId] = status;
        }
      }

      return _aggregateRecords(
        studentIds: uniqueStudentIds,
        morningRecords: morningRecords,
        afternoonRecords: afternoonRecords,
        sessionFilter: sessionFilter,
        totalClasses: filteredClassIds.length,
      );
    } catch (_) {
      return _calculateDemoAnalytics(
        academicYear: academicYear,
        department: department,
        classId: classId,
        date: date,
        sessionFilter: sessionFilter,
      );
    }
  }

  AdminAnalyticsData _calculateDemoAnalytics({
    String? academicYear,
    String? department,
    String? classId,
    required String date,
    required String sessionFilter,
  }) {
    final demo = DemoDataService.instance;
    List<ClassModel> classes = demo.getAllClasses();

    if (academicYear != null && academicYear.isNotEmpty && academicYear != 'All') {
      classes = classes.where((c) => c.academicYear == academicYear).toList();
    }
    if (department != null && department.isNotEmpty && department != 'All') {
      classes = classes.where((c) => c.department == department).toList();
    }
    if (classId != null && classId.isNotEmpty && classId != 'All') {
      classes = classes.where((c) => c.id == classId).toList();
    }

    if (classes.isEmpty) {
      return AdminAnalyticsData.empty();
    }

    final Set<String> uniqueStudentIds = {};
    for (var cls in classes) {
      final enrolled = demo.getEnrolledStudents(cls.id);
      uniqueStudentIds.addAll(enrolled.map((s) => s.id));
    }

    final Map<String, AttendanceStatus> morningRecords = {};
    final Map<String, AttendanceStatus> afternoonRecords = {};

    for (var cls in classes) {
      final mSess = demo.getSession(cls.id, date, SessionType.morning);
      if (mSess != null) {
        final recs = demo.getSessionRecords(mSess.id);
        for (var r in recs) {
          // Keep first or consolidated record per student
          morningRecords.putIfAbsent(r.studentId, () => r.status);
        }
      }

      final aSess = demo.getSession(cls.id, date, SessionType.afternoon);
      if (aSess != null) {
        final recs = demo.getSessionRecords(aSess.id);
        for (var r in recs) {
          afternoonRecords.putIfAbsent(r.studentId, () => r.status);
        }
      }
    }

    return _aggregateRecords(
      studentIds: uniqueStudentIds.toList(),
      morningRecords: morningRecords,
      afternoonRecords: afternoonRecords,
      sessionFilter: sessionFilter,
      totalClasses: classes.length,
    );
  }

  AdminAnalyticsData _aggregateRecords({
    required List<String> studentIds,
    required Map<String, AttendanceStatus> morningRecords,
    required Map<String, AttendanceStatus> afternoonRecords,
    required String sessionFilter,
    required int totalClasses,
  }) {
    if (morningRecords.isEmpty && afternoonRecords.isEmpty) {
      return AdminAnalyticsData.empty(
        totalStudents: studentIds.length,
        totalClasses: totalClasses,
      );
    }

    int mP = 0, mA = 0, mOd = 0;
    int aP = 0, aA = 0, aOd = 0, aBunk = 0;
    int bothP = 0;
    int mP_aA = 0;

    for (final sid in studentIds) {
      final m = morningRecords[sid];
      final a = afternoonRecords[sid];

      if (m == AttendanceStatus.present) mP++;
      if (m == AttendanceStatus.absent) mA++;
      if (m == AttendanceStatus.od) mOd++;

      if (a == AttendanceStatus.present) aP++;
      if (a == AttendanceStatus.absent) aA++;
      if (a == AttendanceStatus.od) aOd++;
      if (a == AttendanceStatus.bunk) aBunk++;

      if (m == AttendanceStatus.present && a == AttendanceStatus.present) bothP++;
      if (m == AttendanceStatus.present && a == AttendanceStatus.absent) mP_aA++;
    }

    // Apply session filter masking if specific session selected
    if (sessionFilter == 'Morning') {
      aP = 0;
      aA = 0;
      aOd = 0;
      aBunk = 0;
      bothP = 0;
      mP_aA = 0;
    } else if (sessionFilter == 'Afternoon') {
      mP = 0;
      mA = 0;
      mOd = 0;
      bothP = 0;
      mP_aA = 0;
    }

    final mMarked = mP + mA + mOd;
    final morningPercentage = mMarked > 0 ? (mP / mMarked) * 100.0 : 0.0;

    final aMarked = aP + aA + aOd + aBunk;
    final afternoonPercentage = aMarked > 0 ? (aP / aMarked) * 100.0 : 0.0;

    return AdminAnalyticsData(
      totalStudents: studentIds.length,
      morningPresent: mP,
      morningAbsent: mA,
      morningOd: mOd,
      afternoonPresent: aP,
      afternoonAbsent: aA,
      afternoonOd: aOd,
      afternoonBunk: aBunk,
      morningPercentage: morningPercentage,
      afternoonPercentage: afternoonPercentage,
      studentsPresentBoth: bothP,
      studentsPresentMorningAbsentAfternoon: mP_aA,
      hasRecords: (mMarked > 0 || aMarked > 0),
      totalClassesFiltered: totalClasses,
    );
  }
}
