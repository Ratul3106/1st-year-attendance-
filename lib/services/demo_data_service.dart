import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/models/app_notification.dart';
import 'package:student_attendance_system/services/attendance_comparison_service.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';

class DemoDataService {
  static final DemoDataService instance = DemoDataService._internal();

  DemoDataService._internal() {
    _initDemoData();
  }

  // Active simulated user
  User? _currentDemoUser;
  UserProfile? _currentDemoProfile;

  User? get currentDemoUser => _currentDemoUser;
  UserProfile? get currentDemoProfile => _currentDemoProfile;

  // In-memory data collections
  final List<UserProfile> _users = [];
  final List<ClassModel> _classes = [];
  final List<Student> _students = [];
  final Map<String, List<String>> _classStudentsMap = {}; // classId -> list of studentIds
  final Map<String, List<String>> _coordinatorClassesMap = {}; // coordinatorId -> list of classIds
  final Map<String, List<String>> _staffClassesMap = {}; // staffId -> list of classIds
  final List<AttendanceSession> _sessions = [];
  final List<AttendanceRecord> _records = [];
  final List<DailyReport> _reports = [];
  final List<AppNotification> _notifications = [];

  void _initDemoData() {
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // 1. Demo Profiles
    final adminProfile = UserProfile(
      id: 'demo-admin-id',
      fullName: 'Dr. Ramesh Sharma (Admin)',
      role: UserRole.admin,
      active: true,
      createdAt: now.subtract(const Duration(days: 30)),
    );

    final coordProfile = UserProfile(
      id: 'demo-coord-id',
      fullName: 'Prof. Priya Nair (Coordinator)',
      role: UserRole.coordinator,
      active: true,
      createdAt: now.subtract(const Duration(days: 30)),
    );

    final staffProfile = UserProfile(
      id: 'demo-staff-id',
      fullName: 'Prof. Amit Patel (HOD / Staff)',
      role: UserRole.staff,
      active: true,
      createdAt: now.subtract(const Duration(days: 30)),
    );

    _users.addAll([adminProfile, coordProfile, staffProfile]);

    // 2. Demo Classes
    final class1 = ClassModel(
      id: 'class-cse-1a',
      className: '1st Year - CSE (Sec A)',
      department: 'Computer Science & Engineering',
      academicYear: '2026-2027',
      active: true,
      createdAt: now.subtract(const Duration(days: 10)),
    );

    final class2 = ClassModel(
      id: 'class-ece-1b',
      className: '1st Year - ECE (Sec B)',
      department: 'Electronics & Communication',
      academicYear: '2026-2027',
      active: true,
      createdAt: now.subtract(const Duration(days: 9)),
    );

    final class3 = ClassModel(
      id: 'class-mech-1a',
      className: '1st Year - MECH (Sec A)',
      department: 'Mechanical Engineering',
      academicYear: '2026-2027',
      active: true,
      createdAt: now.subtract(const Duration(days: 8)),
    );

    _classes.addAll([class1, class2, class3]);

    // 3. Demo Students
    final studentList = [
      Student(id: 'std-1', registerNumber: '26CS001', fullName: 'Aarav Patel', active: true, createdAt: now),
      Student(id: 'std-2', registerNumber: '26CS002', fullName: 'Ananya Sharma', active: true, createdAt: now),
      Student(id: 'std-3', registerNumber: '26CS003', fullName: 'Rohan Verma', active: true, createdAt: now),
      Student(id: 'std-4', registerNumber: '26CS004', fullName: 'Sneha Kulkarni', active: true, createdAt: now),
      Student(id: 'std-5', registerNumber: '26CS005', fullName: 'Vikram Aditya', active: true, createdAt: now),
      Student(id: 'std-6', registerNumber: '26CS006', fullName: 'Diya Sen', active: true, createdAt: now),
      Student(id: 'std-7', registerNumber: '26CS007', fullName: 'Karthik Sundaram', active: true, createdAt: now),
      Student(id: 'std-8', registerNumber: '26CS008', fullName: 'Meera Iyer', active: true, createdAt: now),
      Student(id: 'std-9', registerNumber: '26CS009', fullName: 'Rahul Menon', active: true, createdAt: now),
      Student(id: 'std-10', registerNumber: '26CS010', fullName: 'Tanvi Deshmukh', active: true, createdAt: now),
      Student(id: 'std-11', registerNumber: '26CS011', fullName: 'Yash Singhania', active: true, createdAt: now),
      Student(id: 'std-12', registerNumber: '26CS012', fullName: 'Ishita Roy', active: true, createdAt: now),
    ];
    _students.addAll(studentList);

    // Enroll students in class1 (CSE-1A)
    _classStudentsMap['class-cse-1a'] = studentList.map((s) => s.id).toList();
    // Enroll first 6 students in class2 (ECE-1B)
    _classStudentsMap['class-ece-1b'] = studentList.take(6).map((s) => s.id).toList();
    // Enroll remaining in class3 (MECH-1A)
    _classStudentsMap['class-mech-1a'] = studentList.skip(6).map((s) => s.id).toList();

    // Assign Coordinator & Staff
    _coordinatorClassesMap['demo-coord-id'] = ['class-cse-1a', 'class-ece-1b'];
    _staffClassesMap['demo-staff-id'] = ['class-cse-1a', 'class-ece-1b', 'class-mech-1a'];

    // 4. Sample Sessions for Today
    final morningSession = AttendanceSession(
      id: 'sess-morning-today',
      classId: 'class-cse-1a',
      attendanceDate: todayStr,
      sessionType: SessionType.morning,
      status: SessionStatus.closed,
      openedBy: 'demo-coord-id',
      openedAt: now.subtract(const Duration(hours: 3)),
      closedAt: now.subtract(const Duration(hours: 2)),
    );

    final afternoonSession = AttendanceSession(
      id: 'sess-afternoon-today',
      classId: 'class-cse-1a',
      attendanceDate: todayStr,
      sessionType: SessionType.afternoon,
      status: SessionStatus.open,
      openedBy: 'demo-coord-id',
      openedAt: now.subtract(const Duration(hours: 1)),
    );

    _sessions.addAll([morningSession, afternoonSession]);

    // 5. Sample Attendance Records for CSE-1A
    // Morning:
    // - std-3 (Rohan): Absent
    // - std-4 (Sneha): OD (On Duty)
    // - others: Present
    for (var s in studentList) {
      AttendanceStatus status = AttendanceStatus.present;
      if (s.id == 'std-3') {
        status = AttendanceStatus.absent;
      } else if (s.id == 'std-4') {
        status = AttendanceStatus.od;
      }

      _records.add(AttendanceRecord(
        id: 'rec-m-${s.id}',
        sessionId: 'sess-morning-today',
        studentId: s.id,
        status: status,
        markedBy: 'demo-coord-id',
        markedAt: now.subtract(const Duration(hours: 2, minutes: 30)),
      ));
    }

    // Afternoon:
    // - std-3 (Rohan): Absent
    // - std-4 (Sneha): OD
    // - std-5 (Vikram): Bunk (coordinator-recorded afternoon status)
    // - std-8 (Meera): OD
    // - others: Present
    for (var s in studentList) {
      AttendanceStatus status = AttendanceStatus.present;
      if (s.id == 'std-3') {
        status = AttendanceStatus.absent;
      } else if (s.id == 'std-4') {
        status = AttendanceStatus.od;
      } else if (s.id == 'std-5') {
        status = AttendanceStatus.bunk;
      } else if (s.id == 'std-8') {
        status = AttendanceStatus.od;
      }

      _records.add(AttendanceRecord(
        id: 'rec-a-${s.id}',
        sessionId: 'sess-afternoon-today',
        studentId: s.id,
        status: status,
        markedBy: 'demo-coord-id',
        markedAt: now.subtract(const Duration(minutes: 30)),
      ));
    }

    // Seed class2 (ECE-1B) morning session as well
    final eceMorningSession = AttendanceSession(
      id: 'sess-morning-ece',
      classId: 'class-ece-1b',
      attendanceDate: todayStr,
      sessionType: SessionType.morning,
      status: SessionStatus.closed,
      openedBy: 'demo-coord-id',
      openedAt: now.subtract(const Duration(hours: 4)),
      closedAt: now.subtract(const Duration(hours: 3)),
    );
    _sessions.add(eceMorningSession);

    for (var s in studentList.take(6)) {
      _records.add(AttendanceRecord(
        id: 'rec-ece-m-${s.id}',
        sessionId: 'sess-morning-ece',
        studentId: s.id,
        status: s.id == 'std-2' ? AttendanceStatus.absent : AttendanceStatus.present,
        markedBy: 'demo-coord-id',
        markedAt: now.subtract(const Duration(hours: 3, minutes: 30)),
      ));
    }

    // 6. Pre-generate Daily Report for CSE-1A
    _recalculateDailyReport('class-cse-1a', todayStr);

    // 7. Sample Notifications
    _notifications.add(AppNotification(
      id: 'notif-1',
      recipientId: 'demo-staff-id',
      reportId: 'report-class-cse-1a-$todayStr',
      title: 'Daily Attendance Report (Preliminary 2:00 PM IST)',
      message: 'Scheduled 2:00 PM report for 1st Year - CSE (Sec A). Total: 12. Morning: 10/12 Present, 1 Absent, 1 OD. Afternoon: 8/12 Present, 1 Absent, 2 OD, 1 Bunk.',
      createdAt: now.subtract(const Duration(minutes: 20)),
    ));
    _notifications.add(AppNotification(
      id: 'notif-2',
      recipientId: 'demo-staff-id',
      title: 'Faculty Notice',
      message: 'Afternoon attendance reconciliation completed for all 1st year batches. Please review Bunk and OD records.',
      readAt: now.subtract(const Duration(hours: 1)),
      createdAt: now.subtract(const Duration(hours: 5)),
    ));
  }

  // --- Auth Simulation ---
  bool loginAsDemo(String email, {UserRole? requestedRole}) {
    final lower = email.trim().toLowerCase();
    UserProfile? matched;

    if (lower.contains('admin')) {
      matched = _users.firstWhere((u) => u.role == UserRole.admin);
    } else if (lower.contains('coord')) {
      matched = _users.firstWhere((u) => u.role == UserRole.coordinator);
    } else if (lower.contains('staff')) {
      matched = _users.firstWhere((u) => u.role == UserRole.staff);
    } else {
      matched = _users.firstWhere((u) => u.role == UserRole.coordinator);
    }

    // If requestedRole is provided, verify against matched profile role
    if (requestedRole != null && matched.role != requestedRole) {
      _currentDemoProfile = matched;
      return false; // Role mismatch rejected!
    }

    _currentDemoProfile = matched;
    _currentDemoUser = User(
      id: matched.id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    return true;
  }

  void signOut() {
    _currentDemoUser = null;
    _currentDemoProfile = null;
  }

  // --- Coordinator / Attendance Service Methods ---
  List<ClassModel> getAssignedClassesForCoordinator(String coordinatorId) {
    final classIds = _coordinatorClassesMap[coordinatorId] ?? _classes.map((c) => c.id).toList();
    return _classes.where((c) => classIds.contains(c.id)).toList();
  }

  List<ClassModel> getAssignedClassesForStaff(String staffId) {
    final classIds = _staffClassesMap[staffId] ?? _classes.map((c) => c.id).toList();
    return _classes.where((c) => classIds.contains(c.id)).toList();
  }

  List<Student> getEnrolledStudents(String classId) {
    final studentIds = _classStudentsMap[classId] ?? [];
    return _students.where((s) => studentIds.contains(s.id) && s.active).toList();
  }

  AttendanceSession getOrCreateSession(String classId, String date, SessionType type) {
    final existing = _sessions.where(
      (s) => s.classId == classId && s.attendanceDate == date && s.sessionType == type,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final newSession = AttendanceSession(
      id: 'sess-${type.name}-$classId-$date',
      classId: classId,
      attendanceDate: date,
      sessionType: type,
      status: SessionStatus.open,
      openedBy: _currentDemoUser?.id ?? 'demo-coord-id',
      openedAt: DateTime.now(),
    );
    _sessions.add(newSession);
    return newSession;
  }

  AttendanceSession? getSession(String classId, String date, SessionType type) {
    return _sessions.where(
      (s) => s.classId == classId && s.attendanceDate == date && s.sessionType == type,
    ).firstOrNull;
  }

  List<AttendanceRecord> getSessionRecords(String sessionId) {
    return _records.where((r) => r.sessionId == sessionId).toList();
  }

  void saveAttendanceRecords(String sessionId, Map<String, AttendanceStatus> map) {
    final now = DateTime.now();
    final userId = _currentDemoUser?.id ?? 'demo-coord-id';

    // Map existing records to detect previous status for duplicate / changed detection
    final Map<String, AttendanceStatus> prevStatusMap = {};
    for (final r in _records.where((r) => r.sessionId == sessionId)) {
      prevStatusMap[r.studentId] = r.status;
    }

    // Remove existing records for this session
    _records.removeWhere((r) => r.sessionId == sessionId && map.containsKey(r.studentId));

    map.forEach((studentId, status) {
      _records.add(AttendanceRecord(
        id: 'rec-${DateTime.now().millisecondsSinceEpoch}-$studentId',
        sessionId: sessionId,
        studentId: studentId,
        status: status,
        markedBy: userId,
        markedAt: now,
      ));
    });

    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session != null) {
      _recalculateDailyReport(session.classId, session.attendanceDate);

      // Trigger WhatsApp Attendance Notification for newly absent students
      final cls = _classes.where((c) => c.id == session.classId).firstOrNull;
      if (cls != null) {
        final coordId = _coordinatorClassesMap.entries
            .firstWhere((e) => e.value.contains(session.classId), orElse: () => const MapEntry('', []))
            .key;
        final coordinator = _users.where((u) => u.id == coordId).firstOrNull ??
            _users.firstWhere((u) => u.role == UserRole.coordinator, orElse: () => _users.first);

        for (final entry in map.entries) {
          final studentId = entry.key;
          final newStatus = entry.value;
          final prevStatus = prevStatusMap[studentId];

          final student = _students.where((s) => s.id == studentId).firstOrNull;
          if (student != null) {
            try {
              WhatsAppNotificationService.instance.handleAttendanceRecordSaved(
                session: session,
                classModel: cls,
                student: student,
                newStatus: newStatus,
                previousStatus: prevStatus,
                markedByUserId: userId,
                advisorName: coordinator.fullName,
                advisorPhone: '+919876543211',
              );
            } catch (e) {
              // Notification errors must never prevent saving attendance
            }
          }
        }
      }
    }
  }

  // Evaluate repeated absences for all demo classes
  Future<List<WhatsAppAbsenceSummaryResult>> evaluateRepeatedAbsences({
    DateTime? asOfDate,
    int? windowDays,
    int? threshold,
  }) async {
    return WhatsAppNotificationService.instance.evaluateRepeatedAbsences(
      classes: _classes,
      allStudents: _students,
      allSessions: _sessions,
      allRecords: _records,
      asOfDate: asOfDate,
      customWindowDays: windowDays,
      customThreshold: threshold,
    );
  }

  void _recalculateDailyReport(String classId, String date) {
    final students = getEnrolledStudents(classId);

    final morningSession = _sessions.where(
      (s) => s.classId == classId && s.attendanceDate == date && s.sessionType == SessionType.morning,
    ).firstOrNull;

    final afternoonSession = _sessions.where(
      (s) => s.classId == classId && s.attendanceDate == date && s.sessionType == SessionType.afternoon,
    ).firstOrNull;

    final Map<String, AttendanceStatus> mMap = {};
    if (morningSession != null) {
      for (final r in _records.where((r) => r.sessionId == morningSession.id)) {
        mMap[r.studentId] = r.status;
      }
    }

    final Map<String, AttendanceStatus> aMap = {};
    if (afternoonSession != null) {
      for (final r in _records.where((r) => r.sessionId == afternoonSession.id)) {
        aMap[r.studentId] = r.status;
      }
    }

    final report = AttendanceComparisonEngine.buildDailyReport(
      classId: classId,
      date: date,
      students: students,
      morningRecords: mMap,
      afternoonRecords: aMap,
      hasMorningSession: morningSession != null,
      hasAfternoonSession: afternoonSession != null,
    );

    _reports.removeWhere((r) => r.classId == classId && r.attendanceDate == date);
    _reports.add(report);
  }

  // --- Reports Service Methods ---
  DailyReport? getDailyReport(String classId, String date) {
    // If not generated, attempt to recalculate from existing records
    final existing = _reports.where((r) => r.classId == classId && r.attendanceDate == date).firstOrNull;
    if (existing != null) return existing;

    _recalculateDailyReport(classId, date);
    return _reports.where((r) => r.classId == classId && r.attendanceDate == date).firstOrNull;
  }

  DailyReport? getReportById(String reportId) {
    return _reports.where((r) => r.id == reportId).firstOrNull;
  }

  List<DailyReport> getDailyReportsForDate(String date) {
    return _reports.where((r) => r.attendanceDate == date).toList();
  }

  List<DailyReport> getAllReports() => List.unmodifiable(_reports);

  // --- Attendance Retrieval for Student Table / Comparison ---
  Map<String, AttendanceRecord?> getStudentRecordsForDate({
    required String classId,
    required String date,
    required String studentId,
  }) {
    final mSess = _sessions.where(
      (s) => s.classId == classId && s.attendanceDate == date && s.sessionType == SessionType.morning,
    ).firstOrNull;

    final aSess = _sessions.where(
      (s) => s.classId == classId && s.attendanceDate == date && s.sessionType == SessionType.afternoon,
    ).firstOrNull;

    final mRec = mSess != null
        ? _records.where((r) => r.sessionId == mSess.id && r.studentId == studentId).firstOrNull
        : null;

    final aRec = aSess != null
        ? _records.where((r) => r.sessionId == aSess.id && r.studentId == studentId).firstOrNull
        : null;

    return {
      'morning': mRec,
      'afternoon': aRec,
    };
  }

  // --- Admin Service Methods ---
  List<ClassModel> getAllClasses() => List.unmodifiable(_classes);

  void createClass({required String className, required String department, required String academicYear}) {
    final newClass = ClassModel(
      id: 'class-${DateTime.now().millisecondsSinceEpoch}',
      className: className,
      department: department,
      academicYear: academicYear,
      active: true,
      createdAt: DateTime.now(),
    );
    _classes.add(newClass);
  }

  List<Student> getAllStudents() => List.unmodifiable(_students);

  void createStudent({required String registerNumber, required String fullName}) {
    final newStudent = Student(
      id: 'std-${DateTime.now().millisecondsSinceEpoch}',
      registerNumber: registerNumber,
      fullName: fullName,
      active: true,
      createdAt: DateTime.now(),
    );
    _students.add(newStudent);
  }

  void enrollStudentInClass({required String classId, required String studentId}) {
    final list = _classStudentsMap.putIfAbsent(classId, () => []);
    if (!list.contains(studentId)) {
      list.add(studentId);
    }
  }

  List<UserProfile> getAllUsers() => List.unmodifiable(_users);

  void assignCoordinatorToClass({required String classId, required String coordinatorId}) {
    final list = _coordinatorClassesMap.putIfAbsent(coordinatorId, () => []);
    if (!list.contains(classId)) list.add(classId);
  }

  void assignStaffToClass({required String classId, required String staffId}) {
    final list = _staffClassesMap.putIfAbsent(staffId, () => []);
    if (!list.contains(classId)) list.add(classId);
  }

  // --- Notifications Service Methods ---
  List<AppNotification> getNotificationsForUser(String userId) {
    return _notifications.where((n) => n.recipientId == userId || n.recipientId == 'demo-staff-id').toList();
  }

  void markNotificationAsRead(String notificationId) {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      final notif = _notifications[idx];
      _notifications[idx] = AppNotification(
        id: notif.id,
        recipientId: notif.recipientId,
        reportId: notif.reportId,
        title: notif.title,
        message: notif.message,
        readAt: DateTime.now(),
        createdAt: notif.createdAt,
      );
    }
  }

  // --- Scheduled Report Trigger Simulation (2:00 PM IST) ---
  void triggerScheduled2PmReport() {
    final now = DateTime.now();
    final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    for (final cls in _classes) {
      _recalculateDailyReport(cls.id, todayStr);
      final report = getDailyReport(cls.id, todayStr);
      if (report != null) {
        _notifications.insert(
          0,
          AppNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${cls.id}',
            recipientId: 'demo-staff-id',
            reportId: report.id,
            title: 'Scheduled 2:00 PM IST Report (${cls.className})',
            message: 'Preliminary attendance report for ${cls.className}. Morning: ${report.morningPresent}/${report.totalEnrolled}. Afternoon: ${report.afternoonPresent}/${report.totalEnrolled}.',
            createdAt: now,
          ),
        );
      }
    }
  }
}
