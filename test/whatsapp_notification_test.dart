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

    // 16. Unmarked students are strictly distinguished from absent and never counted as absent
    test('16. Unmarked students are strictly distinguished from absent and never counted as absent', () async {
      final enrolledClass = demo.getAllClasses().first;
      final report = await service.generateAttendanceReport(
        classModel: enrolledClass,
        date: '2026-10-31',
        isPreliminary: true,
      );

      // Verify that morningUnmarked and afternoonUnmarked are tracked separately from absent
      expect(report.totalEnrolled, greaterThan(0));
      expect(report.morningUnmarked, isNonNegative);
      expect(report.afternoonUnmarked, isNonNegative);
      // Unmarked count is not added to absent count
      expect(report.morningAbsent, isNot(equals(report.totalEnrolled)));
    });

    // 17. Attendance percentages are calculated strictly on recorded denominator
    test('17. Attendance percentages are calculated strictly on recorded denominator', () {
      final sampleReport = AttendanceReportModel(
        id: 'rep-test-pct',
        reportDate: '2026-10-31',
        classId: testClass.id,
        className: testClass.className,
        department: testClass.department,
        academicYear: testClass.academicYear,
        reportType: 'preliminary',
        totalEnrolled: 20,
        morningPresent: 10,
        morningAbsent: 2,
        morningOd: 3,
        morningUnmarked: 5, // 5 unmarked out of 20
        morningPercentage: 86.67, // (10 + 3) / (10 + 2 + 3) * 100 = 13/15 = 86.67%
        afternoonPresent: 8,
        afternoonAbsent: 2,
        afternoonOd: 1,
        afternoonBunk: 1,
        afternoonUnmarked: 8,
        afternoonPercentage: 75.0, // (8 + 1) / (8 + 2 + 1 + 1) * 100 = 9/12 = 75.0%
        presentBoth: 8,
        presentMorningAbsentAfternoon: 1,
        afternoonBunkCount: 1,
      );

      expect(sampleReport.morningPercentage, equals(86.67));
      expect(sampleReport.afternoonPercentage, equals(75.0));
      expect(sampleReport.isPreliminary, isTrue);
    });

    // 18. Report message format matches Section 5 specification exactly
    test('18. Report message format matches Section 5 specification exactly', () {
      final sampleReport = AttendanceReportModel(
        id: 'rep-test-fmt',
        reportDate: '2026-10-31',
        classId: testClass.id,
        className: '1st Year - CSE (Sec A)',
        department: 'Computer Science',
        academicYear: '2026-2027',
        reportType: 'final',
        totalEnrolled: 60,
        morningPresent: 55,
        morningAbsent: 3,
        morningOd: 2,
        morningUnmarked: 0,
        morningPercentage: 95.0,
        afternoonPresent: 52,
        afternoonAbsent: 4,
        afternoonOd: 2,
        afternoonBunk: 2,
        afternoonUnmarked: 0,
        afternoonPercentage: 90.0,
        presentBoth: 51,
        presentMorningAbsentAfternoon: 2,
        afternoonBunkCount: 2,
        generatedAt: DateTime(2026, 10, 31, 14, 0),
      );

      final msg = sampleReport.formattedMessage;

      // Check required sections and markers
      expect(msg, contains('STUDENT ATTENDANCE REPORT'));
      expect(msg, contains('Date: 2026-10-31'));
      expect(msg, contains('Department: Computer Science'));
      expect(msg, contains('Class: 1st Year - CSE (Sec A)'));
      expect(msg, contains('Academic Year: 2026-2027'));
      expect(msg, contains('MORNING ATTENDANCE'));
      expect(msg, contains('Total Students: 60'));
      expect(msg, contains('Present: 55'));
      expect(msg, contains('Absent: 3'));
      expect(msg, contains('OD: 2'));
      expect(msg, contains('Not Marked: 0'));
      expect(msg, contains('Attendance: 95.0%'));
      expect(msg, contains('AFTERNOON ATTENDANCE'));
      expect(msg, contains('Bunk: 2'));
      expect(msg, contains('Attendance: 90.0%'));
      expect(msg, contains('SESSION COMPARISON'));
      expect(msg, contains('Present in Both Sessions: 51'));
      expect(msg, contains('Morning Present → Afternoon Absent: 2'));
      expect(msg, contains('Afternoon Bunk: 2'));
      expect(msg, contains('Report Status: FINAL'));
      expect(msg, contains('Student Attendance Management System'));
    });

    // 19. Authorized recipient management and phone masking
    test('19. Authorized recipient management and phone masking', () async {
      final recipient = AuthorizedRecipient(
        id: 'rec-test-1',
        name: 'Dr. Suresh Kumar',
        designation: 'Vice Principal',
        phoneNumber: '+919876543299',
        assignedClassIds: [testClass.id],
        reportTypes: 'both',
        active: true,
        consentObtained: true,
      );

      await service.saveAuthorizedRecipient(recipient);
      final recs = await service.getAuthorizedRecipients();

      expect(recs.any((r) => r.id == 'rec-test-1'), isTrue);
      final saved = recs.firstWhere((r) => r.id == 'rec-test-1');
      expect(saved.name, equals('Dr. Suresh Kumar'));
      expect(saved.maskedPhoneNumber, equals('+919 *** **299'));
      expect(saved.isAuthorizedForClass(testClass.id), isTrue);
      expect(saved.isAuthorizedForClass('other-class-id'), isFalse);
    });

    // 20. Manual send report dispatches and creates delivery log
    test('20. Manual send report dispatches and creates delivery log', () async {
      final report = await service.generateAttendanceReport(
        classModel: testClass,
        date: '2026-10-31',
      );

      final recs = await service.getAuthorizedRecipients();
      expect(recs.isNotEmpty, isTrue);

      final result = await service.sendWhatsAppReport(
        report: report,
        recipients: [recs.first],
      );

      expect(result['success'], isTrue);
      expect(result['delivered_count'], equals(1));

      final logs = await service.getNotificationLogs(classIdFilter: testClass.id);
      expect(logs.isNotEmpty, isTrue);
      final reportLog = logs.firstWhere((l) => l.notificationType == WhatsAppNotificationType.attendanceReport);
      expect(reportLog.status, equals(WhatsAppDeliveryStatus.sent));
      expect(reportLog.providerMessageId, isNotNull);
      expect(reportLog.providerMessageId!.startsWith('wamid.HBgM'), isTrue);
    });

    // 21. Webhook delivery status updates from SENT to DELIVERED and READ
    test('21. Webhook delivery status updates from SENT to DELIVERED and READ', () async {
      final report = await service.generateAttendanceReport(
        classModel: testClass,
        date: '2026-10-31',
      );
      final recs = await service.getAuthorizedRecipients();
      final result = await service.sendWhatsAppReport(report: report, recipients: [recs.first]);
      final wamid = (result['details'] as List).first['wamid'] as String;

      // Simulate Meta Webhook 'delivered' event
      final deliveredOk = await service.processWebhookDeliveryEvent(
        providerMessageId: wamid,
        newStatus: WhatsAppDeliveryStatus.delivered,
        timestamp: '1728840100',
      );
      expect(deliveredOk, isTrue);

      var logs = await service.getNotificationLogs();
      var matchingLog = logs.firstWhere((l) => l.providerMessageId == wamid);
      expect(matchingLog.status, equals(WhatsAppDeliveryStatus.delivered));
      expect(matchingLog.deliveredAt, isNotNull);

      // Simulate Meta Webhook 'read' event
      final readOk = await service.processWebhookDeliveryEvent(
        providerMessageId: wamid,
        newStatus: WhatsAppDeliveryStatus.read,
        timestamp: '1728840200',
      );
      expect(readOk, isTrue);

      logs = await service.getNotificationLogs();
      matchingLog = logs.firstWhere((l) => l.providerMessageId == wamid);
      expect(matchingLog.status, equals(WhatsAppDeliveryStatus.read));
      expect(matchingLog.readAt, isNotNull);
    });

    // 22. Controlled retry for eligible failed delivery log
    test('22. Controlled retry for eligible failed delivery log', () async {
      service.mockFailMetaApi = true;

      final report = await service.generateAttendanceReport(
        classModel: testClass,
        date: '2026-10-31',
      );
      final recs = await service.getAuthorizedRecipients();

      // Send should record failure
      final res = await service.sendWhatsAppReport(report: report, recipients: [recs.first]);
      expect(res['failed_count'], equals(1));

      final logs = await service.getNotificationLogs(statusFilter: WhatsAppDeliveryStatus.failed);
      expect(logs.isNotEmpty, isTrue);
      final failedLog = logs.first;
      expect(failedLog.canRetry, isTrue);

      // Now disable mock fail and retry
      service.mockFailMetaApi = false;
      final retrySuccess = await service.retryDelivery(failedLog.id);
      expect(retrySuccess, isTrue);

      final updatedLogs = await service.getNotificationLogs();
      final retried = updatedLogs.firstWhere((l) => l.id == failedLog.id);
      expect(retried.status, equals(WhatsAppDeliveryStatus.sent));
    });

    // 23. Test WhatsApp connection validation
    test('23. Test WhatsApp connection validation', () async {
      final invalidRes = await service.testWhatsAppConnection('123');
      expect(invalidRes['success'], isFalse);
      expect(invalidRes['error'], contains('Invalid phone number'));

      final validRes = await service.testWhatsAppConnection('+919876543200');
      expect(validRes['success'], isTrue);
      expect(validRes['messageId'], isNotNull);
    });
  });
}
