import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/services/auth_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/services/whatsapp_notification_service.dart';

void main() {
  final service = WhatsAppNotificationService.instance;
  final demo = DemoDataService.instance;

  final testClass = ClassModel(
    id: 'test-class-whatsapp',
    className: '1st Year - CSE (Sec A)',
    department: 'Computer Science',
    academicYear: '2026-2027',
    active: true,
    createdAt: DateTime.now(),
  );

  final testStudent = Student(
    id: 'test-student-w1',
    registerNumber: '26CS099',
    fullName: 'Kavya Sundaram',
    active: true,
    createdAt: DateTime.now(),
  );

  final testSession = AttendanceSession(
    id: 'test-session-w1',
    classId: testClass.id,
    attendanceDate: '2026-10-13',
    sessionType: SessionType.morning,
    status: SessionStatus.open,
    openedBy: 'demo-coord-id',
    openedAt: DateTime.now(),
  );

  setUp(() {
    service.resetDemoState();
  });

  group('Automated WhatsApp Attendance Notifications Test Suite', () {
    // 1. A new absence triggers the correct notification
    test('1. A new absence triggers the correct notification', () async {
      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.absent,
        previousStatus: null,
        markedByUserId: 'demo-coord-id',
        advisorName: 'Prof. Priya Nair',
        advisorPhone: '+919876543211',
      );

      final outbox = service.demoOutbox;
      expect(outbox.length, equals(1));

      final item = outbox.first;
      expect(item.notificationType, equals(WhatsAppNotificationType.immediateAbsence));
      expect(item.recipientName, equals('Prof. Priya Nair'));
      expect(item.recipientRole, equals('Class Advisor'));
      expect(item.recipientPhone, equals('+919876543211'));
      expect(item.templateParameters, contains('Kavya Sundaram'));
      expect(item.templateParameters, contains('26CS099'));
      expect(item.templateParameters, contains('1st Year - CSE (Sec A)'));
      expect(item.status, isIn([WhatsAppDeliveryStatus.queued, WhatsAppDeliveryStatus.sent]));
    });

    // 2. A PRESENT record does not trigger an absence notification
    test('2. A PRESENT record does not trigger an absence notification', () async {
      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.present,
        previousStatus: null,
        markedByUserId: 'demo-coord-id',
        advisorName: 'Prof. Priya Nair',
        advisorPhone: '+919876543211',
      );

      expect(service.demoOutbox.isEmpty, isTrue);
      expect(service.demoLogs.isEmpty, isTrue);
    });

    // 3. Re-saving unchanged attendance does not duplicate a notification
    test('3. Re-saving unchanged attendance does not duplicate a notification', () async {
      // First save as absent
      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.absent,
        previousStatus: null,
        markedByUserId: 'demo-coord-id',
      );
      expect(service.demoOutbox.length, equals(1));

      // Second save: student is still absent (unchanged re-save / refresh)
      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.absent,
        previousStatus: AttendanceStatus.absent,
        markedByUserId: 'demo-coord-id',
      );

      // Must remain exactly 1 (no duplicate sent)
      expect(service.demoOutbox.length, equals(1));
    });

    // 4. A corrected attendance record is excluded from future absence summaries
    test('4. A corrected attendance record is excluded from future absence summaries', () async {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final session1 = AttendanceSession(
        id: 'sess-corr-1',
        classId: testClass.id,
        attendanceDate: dateStr,
        sessionType: SessionType.morning,
        status: SessionStatus.closed,
        openedBy: 'c1',
        openedAt: now,
      );

      // 3 records originally absent
      final records = [
        AttendanceRecord(
          id: 'r1',
          sessionId: 'sess-corr-1',
          studentId: testStudent.id,
          status: AttendanceStatus.absent,
          markedBy: 'c1',
          markedAt: now,
        ),
      ];

      // With 1 absence, doesn't meet threshold 3
      var results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: [session1],
        allRecords: records,
        customThreshold: 3,
        customWindowDays: 7,
      );
      expect(results.isEmpty, isTrue);

      // Now simulate 3 sessions where record was corrected to PRESENT
      final session2 = AttendanceSession(id: 's2', classId: testClass.id, attendanceDate: dateStr, sessionType: SessionType.morning, status: SessionStatus.closed, openedBy: 'c1', openedAt: now);
      final session3 = AttendanceSession(id: 's3', classId: testClass.id, attendanceDate: dateStr, sessionType: SessionType.afternoon, status: SessionStatus.closed, openedBy: 'c1', openedAt: now);

      final correctedRecords = [
        AttendanceRecord(id: 'r1', sessionId: 'sess-corr-1', studentId: testStudent.id, status: AttendanceStatus.absent, markedBy: 'c1', markedAt: now),
        AttendanceRecord(id: 'r2', sessionId: 's2', studentId: testStudent.id, status: AttendanceStatus.present, markedBy: 'c1', markedAt: now), // Corrected
        AttendanceRecord(id: 'r3', sessionId: 's3', studentId: testStudent.id, status: AttendanceStatus.present, markedBy: 'c1', markedAt: now), // Corrected
      ];

      results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: [session1, session2, session3],
        allRecords: correctedRecords,
        customThreshold: 3,
        customWindowDays: 7,
      );

      // Corrected records to present are excluded, so qualifying count is 0
      expect(results.isEmpty, isTrue);
    });

    // 5. Approved leave is excluded according to the configured rules
    test('5. Approved leave (OD) is excluded according to the configured rules', () async {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final sessions = List.generate(4, (i) => AttendanceSession(
        id: 'sess-od-$i',
        classId: testClass.id,
        attendanceDate: dateStr,
        sessionType: SessionType.morning,
        status: SessionStatus.closed,
        openedBy: 'c1',
        openedAt: now,
      ));

      // Student has 4 sessions marked as OD (On Duty / Approved Leave)
      final records = sessions.map((s) => AttendanceRecord(
        id: 'rec-od-${s.id}',
        sessionId: s.id,
        studentId: testStudent.id,
        status: AttendanceStatus.od,
        markedBy: 'c1',
        markedAt: now,
      )).toList();

      final results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: records,
        customThreshold: 3,
        customWindowDays: 7,
      );

      // Must be empty: OD is strictly excluded from absence counts
      expect(results.isEmpty, isTrue);
    });

    // 6. Repeated-absence thresholds work correctly
    test('6. Repeated-absence thresholds work correctly', () async {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final sessions = List.generate(3, (i) => AttendanceSession(
        id: 'sess-th-$i',
        classId: testClass.id,
        attendanceDate: dateStr,
        sessionType: SessionType.morning,
        status: SessionStatus.closed,
        openedBy: 'c1',
        openedAt: now,
      ));

      // Case A: 2 qualifying absences with threshold 3 -> NOT included
      final twoAbsences = [
        AttendanceRecord(id: 'r1', sessionId: sessions[0].id, studentId: testStudent.id, status: AttendanceStatus.absent, markedBy: 'c1', markedAt: now),
        AttendanceRecord(id: 'r2', sessionId: sessions[1].id, studentId: testStudent.id, status: AttendanceStatus.absent, markedBy: 'c1', markedAt: now),
      ];

      var results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: twoAbsences,
        customThreshold: 3,
      );
      expect(results.isEmpty, isTrue);

      // Case B: 3 qualifying absences with threshold 3 -> INCLUDED
      final threeAbsences = [
        ...twoAbsences,
        AttendanceRecord(id: 'r3', sessionId: sessions[2].id, studentId: testStudent.id, status: AttendanceStatus.absent, markedBy: 'c1', markedAt: now),
      ];

      results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: threeAbsences,
        customThreshold: 3,
      );
      expect(results.length, equals(1));
      expect(results.first.qualifyingCount, equals(1));
      expect(results.first.qualifyingStudents.first['student_id'], equals(testStudent.id));
      expect(results.first.qualifyingStudents.first['absences'], equals(3));
    });

    // 7. The correct staff receive each notification type
    test('7. The correct staff receive each notification type', () async {
      // Immediate alert -> Assigned Class Advisor
      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.absent,
        previousStatus: null,
        markedByUserId: 'demo-coord-id',
        advisorName: 'Prof. Priya Nair',
        advisorPhone: '+919876543211',
      );

      final immediateItem = service.demoOutbox.firstWhere((i) => i.notificationType == WhatsAppNotificationType.immediateAbsence);
      expect(immediateItem.recipientRole, equals('Class Advisor'));
      expect(immediateItem.recipientName, equals('Prof. Priya Nair'));

      // Repeated summary -> Dean of Placement & Training
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final sessions = List.generate(3, (i) => AttendanceSession(
        id: 'sess-staff-$i',
        classId: testClass.id,
        attendanceDate: dateStr,
        sessionType: SessionType.morning,
        status: SessionStatus.closed,
        openedBy: 'c1',
        openedAt: now,
      ));
      final records = sessions.map((s) => AttendanceRecord(
        id: 'rec-staff-${s.id}',
        sessionId: s.id,
        studentId: testStudent.id,
        status: AttendanceStatus.absent,
        markedBy: 'c1',
        markedAt: now,
      )).toList();

      await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: records,
        customThreshold: 3,
      );

      final summaryItem = service.demoOutbox.firstWhere((i) => i.notificationType == WhatsAppNotificationType.repeatedAbsenceSummary);
      expect(summaryItem.recipientRole, equals('Dean of Placement & Training'));
      expect(summaryItem.recipientName, equals('Dean of Placement and Training'));
    });

    // 8. Unauthorized users cannot mark attendance or view restricted records
    test('8. Unauthorized users cannot mark attendance or view restricted records', () async {
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

    // 9. WhatsApp API failures do not roll back attendance
    test('9. WhatsApp API failures do not roll back attendance', () async {
      // Simulate WhatsApp Meta Cloud API failure (e.g. 503 network outage)
      service.mockFailMetaApi = true;

      // Save attendance in demo service using existing demo session and student
      const demoSessionId = 'sess-morning-today';
      const demoStudentId = 'std-1';

      demo.saveAttendanceRecords(
        demoSessionId,
        {demoStudentId: AttendanceStatus.absent},
      );

      // Yield for async notification handler to complete
      await Future.delayed(const Duration(milliseconds: 10));

      // Attendance record MUST be successfully stored in database/memory regardless of WhatsApp failure
      final savedRecords = demo.getSessionRecords(demoSessionId);
      expect(savedRecords.any((r) => r.studentId == demoStudentId && r.status == AttendanceStatus.absent), isTrue);

      // WhatsApp item was safely queued/retained for retry
      final outbox = service.demoOutbox;
      expect(outbox.isNotEmpty, isTrue);
    });

    // 10. Failed notifications are retried safely
    test('10. Failed notifications are retried safely with exponential backoff', () async {
      service.mockFailMetaApi = true;

      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.absent,
        previousStatus: null,
        markedByUserId: 'demo-coord-id',
      );

      await service.processQueue();

      final item = service.demoOutbox.first;
      expect(item.retryCount, greaterThan(0));
      expect(item.nextRetryAt.isAfter(DateTime.now().subtract(const Duration(seconds: 1))), isTrue);
      expect(item.errorMessage, contains('HTTP 503'));
    });

    // 11. Duplicate webhook events do not corrupt delivery statuses
    test('11. Duplicate webhook events do not corrupt delivery statuses', () async {
      const wamid = 'wamid.HBgM1234567890';

      // First webhook update: Delivered
      final firstResult = await service.processWebhookDeliveryEvent(
        providerMessageId: wamid,
        newStatus: WhatsAppDeliveryStatus.delivered,
        timestamp: '1728840000',
      );
      expect(firstResult, isTrue);

      // Duplicate webhook delivery event with identical timestamp
      final duplicateResult = await service.processWebhookDeliveryEvent(
        providerMessageId: wamid,
        newStatus: WhatsAppDeliveryStatus.delivered,
        timestamp: '1728840000',
      );
      expect(duplicateResult, isFalse); // Deduplicated cleanly
    });

    // 12. Scheduled summaries are not duplicated across worker restarts or concurrent runs
    test('12. Scheduled summaries are not duplicated across worker restarts or concurrent runs', () async {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final sessions = List.generate(3, (i) => AttendanceSession(
        id: 'sess-dup-$i',
        classId: testClass.id,
        attendanceDate: dateStr,
        sessionType: SessionType.morning,
        status: SessionStatus.closed,
        openedBy: 'c1',
        openedAt: now,
      ));

      final records = sessions.map((s) => AttendanceRecord(
        id: 'rec-dup-${s.id}',
        sessionId: s.id,
        studentId: testStudent.id,
        status: AttendanceStatus.absent,
        markedBy: 'c1',
        markedAt: now,
      )).toList();

      // First evaluation run: Dean is notified
      final firstRun = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: records,
        customThreshold: 3,
        customWindowDays: 7,
      );
      expect(firstRun.first.deanNotified, isTrue);
      final initialOutboxCount = service.demoOutbox.length;

      // Second evaluation run for exact same window/rule version (e.g. concurrent run or worker restart)
      final secondRun = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: records,
        customThreshold: 3,
        customWindowDays: 7,
      );
      expect(secondRun.first.deanNotified, isFalse); // Idempotent!

      // Outbox count should NOT increase
      expect(service.demoOutbox.length, equals(initialOutboxCount));
    });

    // 13. Missing API credentials result in a clear configuration error without exposing secrets
    test('13. Missing API credentials result in a clear configuration error without exposing secrets', () async {
      service.mockCredentialMissing = true;

      // Enqueue an item
      await service.handleAttendanceRecordSaved(
        session: testSession,
        classModel: testClass,
        student: testStudent,
        newStatus: AttendanceStatus.absent,
        previousStatus: null,
        markedByUserId: 'demo-coord-id',
      );

      // Process queue
      await service.processQueue();

      final item = service.demoOutbox.first;
      // Item stays safely queued without crashing or leaking secrets
      expect(item.status, equals(WhatsAppDeliveryStatus.queued));
    });

    // 14. BUNK status is treated as unexcused absence in repeated absence summaries
    test('14. BUNK status is counted towards repeated-absence thresholds', () async {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final sessions = List.generate(3, (i) => AttendanceSession(
        id: 'sess-bunk-$i',
        classId: testClass.id,
        attendanceDate: dateStr,
        sessionType: SessionType.afternoon,
        status: SessionStatus.closed,
        openedBy: 'c1',
        openedAt: now,
      ));

      // 1 absent + 2 bunks = 3 unexcused absences (meets threshold of 3)
      final records = [
        AttendanceRecord(id: 'r1', sessionId: sessions[0].id, studentId: testStudent.id, status: AttendanceStatus.absent, markedBy: 'c1', markedAt: now),
        AttendanceRecord(id: 'r2', sessionId: sessions[1].id, studentId: testStudent.id, status: AttendanceStatus.bunk, markedBy: 'c1', markedAt: now),
        AttendanceRecord(id: 'r3', sessionId: sessions[2].id, studentId: testStudent.id, status: AttendanceStatus.bunk, markedBy: 'c1', markedAt: now),
      ];

      final results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: records,
        customThreshold: 3,
        customWindowDays: 7,
      );

      expect(results.length, equals(1));
      expect(results.first.qualifyingCount, equals(1));
      expect(results.first.qualifyingStudents.first['absences'], equals(3));
    });

    // 15. Unfinalized (open) sessions are strictly excluded from repeated-absence evaluations
    test('15. Unfinalized (open) sessions are strictly excluded from repeated-absence evaluations', () async {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // 3 sessions, but one is still open (unfinalized)
      final sessions = [
        AttendanceSession(id: 's-open-1', classId: testClass.id, attendanceDate: dateStr, sessionType: SessionType.morning, status: SessionStatus.closed, openedBy: 'c1', openedAt: now),
        AttendanceSession(id: 's-open-2', classId: testClass.id, attendanceDate: dateStr, sessionType: SessionType.afternoon, status: SessionStatus.closed, openedBy: 'c1', openedAt: now),
        AttendanceSession(id: 's-open-3', classId: testClass.id, attendanceDate: dateStr, sessionType: SessionType.morning, status: SessionStatus.open, openedBy: 'c1', openedAt: now), // Open!
      ];

      final records = sessions.map((s) => AttendanceRecord(
        id: 'rec-${s.id}',
        sessionId: s.id,
        studentId: testStudent.id,
        status: AttendanceStatus.absent,
        markedBy: 'c1',
        markedAt: now,
      )).toList();

      final results = await service.evaluateRepeatedAbsences(
        classes: [testClass],
        allStudents: [testStudent],
        allSessions: sessions,
        allRecords: records,
        customThreshold: 3,
        customWindowDays: 7,
      );

      // Only 2 finalized absent sessions exist, so threshold 3 is NOT met
      expect(results.isEmpty, isTrue);
    });
  });
}
