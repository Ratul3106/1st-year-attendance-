import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';

class AttendanceService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Get assigned classes for coordinator
  Future<List<ClassModel>> getAssignedClassesForCoordinator(String coordinatorId) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAssignedClassesForCoordinator(coordinatorId);
    }

    try {
      final response = await _supabase!
          .from('class_coordinators')
          .select('class_id')
          .eq('coordinator_id', coordinatorId);

      final classIds = (response as List)
          .map((row) => row['class_id'] as String?)
          .whereType<String>()
          .toList();

      if (classIds.isEmpty) return [];

      final classesRes = await _supabase!
          .from('classes')
          .select()
          .inFilter('id', classIds)
          .eq('active', true)
          .order('created_at');

      return (classesRes as List).map((row) => ClassModel.fromJson(row)).toList();
    } catch (e) {
      debugPrint("Error fetching assigned classes: $e");
      return [];
    }
  }

  // Fetch active enrolled students for a class
  Future<List<Student>> getEnrolledStudents(String classId) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getEnrolledStudents(classId);
    }

    try {
      final response = await _supabase!
          .from('class_enrollments')
          .select('student_id')
          .eq('class_id', classId);

      final studentIds = (response as List)
          .map((row) => row['student_id'] as String?)
          .whereType<String>()
          .toList();

      if (studentIds.isEmpty) return [];

      final studentsRes = await _supabase!
          .from('students')
          .select()
          .inFilter('id', studentIds)
          .eq('active', true)
          .order('register_number');

      return (studentsRes as List)
          .map((row) => Student.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching enrolled students: $e");
      return [];
    }
  }

  // Get attendance records for both morning and afternoon sessions for a class on a date
  Future<Map<String, Map<String, AttendanceRecord?>>> getClassAttendanceForDate({
    required String classId,
    required String date,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      final demo = DemoDataService.instance;
      final students = demo.getEnrolledStudents(classId);
      final Map<String, AttendanceRecord?> morning = {};
      final Map<String, AttendanceRecord?> afternoon = {};
      for (final s in students) {
        final recMap = demo.getStudentRecordsForDate(
          classId: classId,
          date: date,
          studentId: s.id,
        );
        morning[s.id] = recMap['morning'];
        afternoon[s.id] = recMap['afternoon'];
      }
      return {'morning': morning, 'afternoon': afternoon};
    }

    final Map<String, AttendanceRecord?> morning = {};
    final Map<String, AttendanceRecord?> afternoon = {};

    try {
      final sessions = await _supabase!
          .from('attendance_sessions')
          .select('id, session_type')
          .eq('class_id', classId)
          .eq('attendance_date', date);

      String? morningSessionId;
      String? afternoonSessionId;

      for (final s in (sessions as List)) {
        if (s['session_type'] == 'morning') {
          morningSessionId = s['id'] as String;
        } else if (s['session_type'] == 'afternoon') {
          afternoonSessionId = s['id'] as String;
        }
      }

      final sessionIds = [
        if (morningSessionId != null) morningSessionId,
        if (afternoonSessionId != null) afternoonSessionId,
      ];

      if (sessionIds.isNotEmpty) {
        final records = await _supabase!
            .from('attendance_records')
            .select()
            .inFilter('session_id', sessionIds);

        for (final r in (records as List)) {
          final rec = AttendanceRecord.fromJson(r as Map<String, dynamic>);
          if (r['session_id'] == morningSessionId) {
            morning[rec.studentId] = rec;
          } else if (r['session_id'] == afternoonSessionId) {
            afternoon[rec.studentId] = rec;
          }
        }
      }
    } catch (e) {
      debugPrint("Error in getClassAttendanceForDate: $e");
    }

    return {'morning': morning, 'afternoon': afternoon};
  }

  // Get or Create Attendance Session (morning/afternoon) for a class and date
  Future<AttendanceSession> getOrCreateSession({
    required String classId,
    required String date,
    required SessionType sessionType,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getOrCreateSession(classId, date, sessionType);
    }

    final userId = _supabase!.auth.currentUser!.id;
    final typeStr = sessionType == SessionType.morning ? 'morning' : 'afternoon';

    final existing = await _supabase!
        .from('attendance_sessions')
        .select()
        .eq('class_id', classId)
        .eq('attendance_date', date)
        .eq('session_type', typeStr)
        .maybeSingle();

    if (existing != null) {
      return AttendanceSession.fromJson(existing);
    }

    // Create new open session
    final inserted = await _supabase!
        .from('attendance_sessions')
        .insert({
          'class_id': classId,
          'attendance_date': date,
          'session_type': typeStr,
          'status': 'open',
          'opened_by': userId,
        })
        .select()
        .single();

    return AttendanceSession.fromJson(inserted);
  }

  // Fetch existing attendance records for a session
  Future<List<AttendanceRecord>> getSessionRecords(String sessionId) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getSessionRecords(sessionId);
    }

    final response = await _supabase!
        .from('attendance_records')
        .select()
        .eq('session_id', sessionId);

    return (response as List)
        .map((json) => AttendanceRecord.fromJson(json))
        .toList();
  }

  // Save bulk attendance records for a session
  Future<void> saveAttendanceRecords({
    required String sessionId,
    required Map<String, AttendanceStatus> studentStatusMap,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.saveAttendanceRecords(sessionId, studentStatusMap);
      return;
    }

    final userId = _supabase!.auth.currentUser!.id;

    final recordsToUpsert = studentStatusMap.entries.map((entry) {
      return {
        'session_id': sessionId,
        'student_id': entry.key,
        'status': entry.value.dbValue,
        'marked_by': userId,
        'marked_at': DateTime.now().toIso8601String(),
      };
    }).toList();

    await _supabase!
        .from('attendance_records')
        .upsert(recordsToUpsert, onConflict: 'session_id, student_id');

    // Automatically trigger daily report recalculation for this class/date
    final sessionRes = await _supabase!
        .from('attendance_sessions')
        .select('class_id, attendance_date')
        .eq('id', sessionId)
        .single();

    await _supabase!.rpc('generate_daily_attendance_report', params: {
      'p_class_id': sessionRes['class_id'],
      'p_date': sessionRes['attendance_date'],
    });

    // Safely trigger WhatsApp outbox queue processing (non-blocking)
    try {
      WhatsAppNotificationService.instance.processQueue();
    } catch (_) {}
  }

  // Close session
  Future<void> closeSession(String sessionId) async {
    if (SupabaseConfig.isDemoMode) return;
    await _supabase!
        .from('attendance_sessions')
        .update({
          'status': 'closed',
          'closed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }
}
