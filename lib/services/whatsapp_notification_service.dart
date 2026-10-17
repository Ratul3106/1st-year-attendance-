import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/models/whatsapp_models.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/attendance_record.dart';

class WhatsAppNotificationService {
  static final WhatsAppNotificationService instance = WhatsAppNotificationService._internal();

  WhatsAppNotificationService._internal();

  final _uuid = const Uuid();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // In-memory demo state for when Supabase is in demo mode or for test mocking
  WhatsAppSettingsModel _settings = WhatsAppSettingsModel();
  final List<WhatsAppOutboxItem> _demoOutbox = [];
  final List<WhatsAppNotificationLog> _demoLogs = [];
  final Set<String> _processedWebhookEvents = {};

  // Mock control for testing API failures or network drops
  bool mockFailMetaApi = false;
  bool mockCredentialMissing = false;

  WhatsAppSettingsModel get currentSettings => _settings;

  // 1. Settings Management
  Future<WhatsAppSettingsModel> getSettings() async {
    if (SupabaseConfig.isDemoMode) {
      return _settings;
    }

    try {
      final res = await _supabase!
          .from('whatsapp_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (res != null) {
        _settings = WhatsAppSettingsModel.fromJson(res);
      }
    } catch (e) {
      debugPrint('[WhatsAppService] Error fetching settings from DB: $e');
    }
    return _settings;
  }

  Future<void> updateSettings(WhatsAppSettingsModel newSettings) async {
    _settings = newSettings;
    if (SupabaseConfig.isDemoMode) return;

    try {
      await _supabase!
          .from('whatsapp_settings')
          .update(newSettings.toJson())
          .eq('id', '00000000-0000-0000-0000-000000000001');
    } catch (e) {
      debugPrint('[WhatsAppService] Error saving settings to DB: $e');
    }
  }

  // 2. Immediate Absence Notification Queueing
  // Called when faculty/coordinator marks a student as ABSENT
  Future<void> handleAttendanceRecordSaved({
    required AttendanceSession session,
    required ClassModel classModel,
    required Student student,
    required AttendanceStatus newStatus,
    required AttendanceStatus? previousStatus,
    required String markedByUserId,
    String? advisorName,
    String? advisorPhone,
  }) async {
    // Immediate notification triggers ONLY when status is ABSENT
    if (newStatus != AttendanceStatus.absent) {
      return;
    }

    // Duplicate protection: If the student was ALREADY marked absent in this session, do not resend
    if (previousStatus == AttendanceStatus.absent) {
      return;
    }

    // Check if immediate alerts are enabled
    if (!_settings.immediateAlertsEnabled) {
      return;
    }

    try {
      final recipientName = advisorName ?? 'Class Advisor';
      final recipientPhone = normalizePhoneNumber(advisorPhone ?? '+919876543211');

      // Deterministic idempotency key: session_id + student_id + 'absent'
      final idempotencyKey = 'imm_abs_${session.id}_${student.id}_absent';

      // Verify no duplicate queued/sent message with this idempotency key
      final alreadyQueued = await hasIdempotencyKey(idempotencyKey);
      if (alreadyQueued) {
        debugPrint('[WhatsAppService] Duplicate notification prevented for $idempotencyKey');
        return;
      }

      // Format Meta WhatsApp approved template parameters
      // Parameter placeholders: {{1}} Advisor, {{2}} Student Name, {{3}} Reg No, {{4}} Class, {{5}} Date, {{6}} Session/Period, {{7}} Subject
      final periodName = session.sessionType == SessionType.morning ? 'Morning' : 'Afternoon';
      final templateParams = [
        recipientName,
        student.fullName,
        student.registerNumber,
        classModel.className,
        session.attendanceDate,
        periodName,
        'Daily Class Session',
      ];

      final outboxItem = WhatsAppOutboxItem(
        id: _uuid.v4(),
        notificationType: WhatsAppNotificationType.immediateAbsence,
        recipientPhone: recipientPhone,
        recipientName: recipientName,
        recipientRole: 'Class Advisor',
        templateName: _settings.absenceTemplateName,
        templateLanguage: _settings.absenceTemplateLang,
        templateParameters: templateParams,
        payload: {
          'session_id': session.id,
          'student_id': student.id,
          'class_id': classModel.id,
          'attendance_date': session.attendanceDate,
          'session_type': periodName,
        },
        status: WhatsAppDeliveryStatus.queued,
        nextRetryAt: DateTime.now(),
        idempotencyKey: idempotencyKey,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final logItem = WhatsAppNotificationLog(
        id: _uuid.v4(),
        outboxId: outboxItem.id,
        studentId: student.id,
        studentName: student.fullName,
        registerNumber: student.registerNumber,
        classId: classModel.id,
        className: classModel.className,
        sessionId: session.id,
        notificationType: WhatsAppNotificationType.immediateAbsence,
        recipientPhone: recipientPhone,
        recipientName: recipientName,
        recipientRole: 'Class Advisor',
        status: WhatsAppDeliveryStatus.queued,
        createdAt: DateTime.now(),
      );

      await saveToOutboxAndLogs(outboxItem, logItem);

      // Trigger background processing asynchronously (Never blocks attendance)
      processQueue();
    } catch (e) {
      // Must NOT fail attendance save if WhatsApp service throws
      debugPrint('[WhatsAppService] Error queuing immediate absence notification: $e');
    }
  }

  // 3. Repeated-Absence Summary Evaluation
  // Evaluates attendance records over configurable window (e.g., 7 days)
  // Identifies students with qualifying absences >= threshold (default 3)
  // Strictly excludes OD (On Duty) / approved leave and corrected records
  Future<List<WhatsAppAbsenceSummaryResult>> evaluateRepeatedAbsences({
    required List<ClassModel> classes,
    required List<Student> allStudents,
    required List<AttendanceSession> allSessions,
    required List<AttendanceRecord> allRecords,
    DateTime? asOfDate,
    int? customWindowDays,
    int? customThreshold,
  }) async {
    final windowDays = customWindowDays ?? _settings.reportingWindowDays;
    final threshold = customThreshold ?? _settings.absenceThreshold;
    final targetDate = asOfDate ?? DateTime.now();
    final startDate = targetDate.subtract(Duration(days: windowDays - 1));

    final results = <WhatsAppAbsenceSummaryResult>[];

    for (final cls in classes) {
      // Filter sessions within window for this class (finalized / closed sessions only)
      final classSessions = allSessions.where((s) {
        if (s.classId != cls.id) return false;
        if (s.status != SessionStatus.closed) return false;
        try {
          final sDate = DateTime.parse(s.attendanceDate);
          return sDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
              sDate.isBefore(targetDate.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();

      final sessionIds = classSessions.map((s) => s.id).toSet();

      // Count distinct unexcused absent/bunk sessions per student, EXCLUDING 'od' (approved leave) and 'present'
      final studentAbsenceCounts = <String, int>{};

      for (final rec in allRecords) {
        if (!sessionIds.contains(rec.sessionId)) continue;
        // Qualifying unexcused absence: 'absent' or 'bunk'. 'od' and 'present' are strictly excluded
        if (rec.status == AttendanceStatus.absent || rec.status == AttendanceStatus.bunk) {
          studentAbsenceCounts[rec.studentId] = (studentAbsenceCounts[rec.studentId] ?? 0) + 1;
        }
      }

      final qualifyingStudents = <Map<String, dynamic>>[];
      for (final entry in studentAbsenceCounts.entries) {
        if (entry.value >= threshold) {
          final studentObj = allStudents.firstWhere(
            (s) => s.id == entry.key,
            orElse: () => Student(id: entry.key, registerNumber: 'N/A', fullName: 'Student', active: true, createdAt: DateTime.now()),
          );
          if (studentObj.active) {
            qualifyingStudents.add({
              'student_id': studentObj.id,
              'full_name': studentObj.fullName,
              'register_number': studentObj.registerNumber,
              'absences': entry.value,
            });
          }
        }
      }

      if (qualifyingStudents.isNotEmpty) {
        final startStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
        final endStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
        final idempotencyKey = 'rep_abs_${cls.id}_${startStr}_${endStr}_th$threshold';

        bool deanNotified = false;

        if (_settings.summaryAlertsEnabled) {
          final alreadyQueued = await hasIdempotencyKey(idempotencyKey);
          if (!alreadyQueued) {
            final deanPhone = normalizePhoneNumber(_settings.deanPlacementPhone);
            final deanName = _settings.deanPlacementName;

            final templateParams = [
              deanName,
              cls.className,
              qualifyingStudents.length.toString(),
              startStr,
              endStr,
            ];

            final outboxItem = WhatsAppOutboxItem(
              id: _uuid.v4(),
              notificationType: WhatsAppNotificationType.repeatedAbsenceSummary,
              recipientPhone: deanPhone,
              recipientName: deanName,
              recipientRole: 'Dean of Placement & Training',
              templateName: _settings.summaryTemplateName,
              templateLanguage: _settings.summaryTemplateLang,
              templateParameters: templateParams,
              payload: {
                'class_id': cls.id,
                'class_name': cls.className,
                'qualifying_students': qualifyingStudents,
                'start_date': startStr,
                'end_date': endStr,
                'threshold': threshold,
              },
              status: WhatsAppDeliveryStatus.queued,
              nextRetryAt: DateTime.now(),
              idempotencyKey: idempotencyKey,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final logItem = WhatsAppNotificationLog(
              id: _uuid.v4(),
              outboxId: outboxItem.id,
              classId: cls.id,
              className: cls.className,
              notificationType: WhatsAppNotificationType.repeatedAbsenceSummary,
              recipientPhone: deanPhone,
              recipientName: deanName,
              recipientRole: 'Dean of Placement & Training',
              status: WhatsAppDeliveryStatus.queued,
              createdAt: DateTime.now(),
            );

            await saveToOutboxAndLogs(outboxItem, logItem);
            deanNotified = true;
            processQueue();
          }
        }

        results.add(WhatsAppAbsenceSummaryResult(
          classId: cls.id,
          className: cls.className,
          department: cls.department,
          qualifyingCount: qualifyingStudents.length,
          qualifyingStudents: qualifyingStudents,
          periodStart: startStr,
          periodEnd: endStr,
          deanNotified: deanNotified,
          idempotencyKey: idempotencyKey,
        ));
      }
    }

    return results;
  }

  // 4. Background Queue Worker (Authoritative production sending delegated to Edge Function; In-memory simulation in Demo mode)
  Future<void> processQueue() async {
    if (!SupabaseConfig.isDemoMode) {
      // In live Supabase production mode, Flutter MUST NOT mutate outbox records with fake WAMIDs.
      // Instead, invoke the authoritative server-side Edge Function 'whatsapp-worker'.
      try {
        if (_supabase != null) {
          await _supabase!.functions.invoke('whatsapp-worker');
        }
      } catch (e) {
        debugPrint('[WhatsAppService] Error triggering server-side whatsapp-worker Edge Function: $e');
      }
      return;
    }

    // --- In-Memory Demo Mode Simulation (Offline & Widget/Unit Tests) ---
    if (mockCredentialMissing) {
      debugPrint('[WhatsAppWorker] Error: Missing WhatsApp credentials. Messages remain queued.');
      return;
    }

    final pending = await getPendingOutboxItems();
    if (pending.isEmpty) return;

    for (final item in pending) {
      try {
        if (mockFailMetaApi) {
          throw Exception("Meta WhatsApp Cloud API HTTP 503: Service temporarily unavailable");
        }

        // Simulate accepted Meta API Cloud sending in demo/test mode
        final fakeWamid = 'wamid.HBgM${DateTime.now().millisecondsSinceEpoch}${item.id.substring(0, 8)}';

        await updateOutboxStatus(
          id: item.id,
          status: WhatsAppDeliveryStatus.sent,
          providerMessageId: fakeWamid,
          errorMessage: null,
          sentAt: DateTime.now(),
        );
      } catch (err) {
        final newRetry = item.retryCount + 1;
        final backoffSeconds = (1 << newRetry) * 2; // exponential backoff
        final nextRetry = DateTime.now().add(Duration(seconds: backoffSeconds));
        final finalStatus = newRetry >= item.maxRetries ? WhatsAppDeliveryStatus.failed : WhatsAppDeliveryStatus.queued;

        await updateOutboxStatus(
          id: item.id,
          status: finalStatus,
          retryCount: newRetry,
          nextRetryAt: nextRetry,
          errorMessage: err.toString(),
        );
      }
    }
  }

  // 5. Webhook Signature Verification and Delivery Status Processing
  bool verifyWebhookSignature({
    required String rawPayload,
    required String? signatureHeader,
    required String appSecret,
  }) {
    if (signatureHeader == null || !signatureHeader.startsWith('sha256=')) {
      return false;
    }
    final expectedSignature = signatureHeader.substring(7);

    final hmac = Hmac(sha256, utf8.encode(appSecret));
    final digest = hmac.convert(utf8.encode(rawPayload));
    final calculated = digest.toString();

    return calculated.toLowerCase() == expectedSignature.toLowerCase();
  }

  // Webhook Delivery Event Processor with Deduplication
  Future<bool> processWebhookDeliveryEvent({
    required String providerMessageId,
    required WhatsAppDeliveryStatus newStatus,
    required String timestamp,
    String? errorCode,
    String? errorMessage,
  }) async {
    final eventKey = '${providerMessageId}_${newStatus.name}_$timestamp';

    // Deduplication check: prevent processing the exact same status event twice
    if (_processedWebhookEvents.contains(eventKey)) {
      debugPrint('[WhatsAppWebhook] Skipped duplicate webhook event: $eventKey');
      return false;
    }
    _processedWebhookEvents.add(eventKey);

    await updateOutboxAndLogStatusByWamid(
      wamid: providerMessageId,
      status: newStatus,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );

    return true;
  }

  // 6. Persistence Helpers (Demo vs Live Supabase)
  Future<bool> hasIdempotencyKey(String key) async {
    if (SupabaseConfig.isDemoMode) {
      return _demoOutbox.any((item) => item.idempotencyKey == key);
    }

    try {
      final res = await _supabase!
          .from('whatsapp_outbox')
          .select('id')
          .eq('idempotency_key', key)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveToOutboxAndLogs(WhatsAppOutboxItem outboxItem, WhatsAppNotificationLog logItem) async {
    if (SupabaseConfig.isDemoMode) {
      _demoOutbox.add(outboxItem);
      _demoLogs.add(logItem);
      return;
    }

    try {
      await _supabase!.from('whatsapp_outbox').insert({
        'id': outboxItem.id,
        'notification_type': outboxItem.notificationType.name,
        'recipient_phone': outboxItem.recipientPhone,
        'recipient_name': outboxItem.recipientName,
        'recipient_role': outboxItem.recipientRole,
        'template_name': outboxItem.templateName,
        'template_language': outboxItem.templateLanguage,
        'template_parameters': outboxItem.templateParameters,
        'payload': outboxItem.payload,
        'status': outboxItem.status.name,
        'idempotency_key': outboxItem.idempotencyKey,
      });

      await _supabase!.from('whatsapp_notification_logs').insert({
        'id': logItem.id,
        'outbox_id': logItem.outboxId,
        'student_id': logItem.studentId,
        'class_id': logItem.classId,
        'session_id': logItem.sessionId,
        'notification_type': logItem.notificationType.name,
        'recipient_phone': logItem.recipientPhone,
        'recipient_name': logItem.recipientName,
        'recipient_role': logItem.recipientRole,
        'status': logItem.status.name,
      });
    } catch (e) {
      debugPrint('[WhatsAppService] Error saving outbox record: $e');
    }
  }

  Future<List<WhatsAppOutboxItem>> getPendingOutboxItems() async {
    if (SupabaseConfig.isDemoMode) {
      final now = DateTime.now();
      return _demoOutbox.where((i) =>
        i.status == WhatsAppDeliveryStatus.queued ||
        (i.status == WhatsAppDeliveryStatus.failed && i.retryCount < i.maxRetries && i.nextRetryAt.isBefore(now))
      ).toList();
    }

    try {
      final nowIso = DateTime.now().toIso8601String();
      final res = await _supabase!
          .from('whatsapp_outbox')
          .select()
          .or('status.eq.queued,and(status.eq.failed,next_retry_at.lte.$nowIso)')
          .lt('retry_count', 5)
          .limit(20);

      return (res as List).map((j) => WhatsAppOutboxItem.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateOutboxStatus({
    required String id,
    required WhatsAppDeliveryStatus status,
    String? providerMessageId,
    String? errorMessage,
    int? retryCount,
    DateTime? nextRetryAt,
    DateTime? sentAt,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      final idx = _demoOutbox.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _demoOutbox[idx] = _demoOutbox[idx].copyWith(
          status: status,
          providerMessageId: providerMessageId,
          errorMessage: errorMessage,
          retryCount: retryCount,
          nextRetryAt: nextRetryAt,
          updatedAt: DateTime.now(),
        );
      }
      final logIdx = _demoLogs.indexWhere((l) => l.outboxId == id);
      if (logIdx != -1) {
        _demoLogs[logIdx] = _demoLogs[logIdx].copyWith(
          status: status,
          providerMessageId: providerMessageId,
          errorMessage: errorMessage,
          sentAt: sentAt,
        );
      }
      return;
    }

    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (providerMessageId != null) updateData['provider_message_id'] = providerMessageId;
      if (errorMessage != null) updateData['error_message'] = errorMessage;
      if (retryCount != null) updateData['retry_count'] = retryCount;
      if (nextRetryAt != null) updateData['next_retry_at'] = nextRetryAt.toIso8601String();

      await _supabase!.from('whatsapp_outbox').update(updateData).eq('id', id);

      if (sentAt != null) {
        await _supabase!.from('whatsapp_notification_logs').update({
          'status': status.name,
          'provider_message_id': providerMessageId,
          'sent_at': sentAt.toIso8601String(),
        }).eq('outbox_id', id);
      }
    } catch (e) {
      debugPrint('[WhatsAppService] DB error in updateOutboxStatus: $e');
    }
  }

  Future<void> updateOutboxAndLogStatusByWamid({
    required String wamid,
    required WhatsAppDeliveryStatus status,
    String? errorCode,
    String? errorMessage,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      final outboxIdx = _demoOutbox.indexWhere((i) => i.providerMessageId == wamid);
      if (outboxIdx != -1) {
        _demoOutbox[outboxIdx] = _demoOutbox[outboxIdx].copyWith(
          status: status,
          errorMessage: errorMessage,
          updatedAt: DateTime.now(),
        );
      }
      final logIdx = _demoLogs.indexWhere((l) => l.providerMessageId == wamid);
      if (logIdx != -1) {
        _demoLogs[logIdx] = _demoLogs[logIdx].copyWith(
          status: status,
          errorCode: errorCode,
          errorMessage: errorMessage,
          deliveredAt: status == WhatsAppDeliveryStatus.delivered ? DateTime.now() : null,
          readAt: status == WhatsAppDeliveryStatus.read ? DateTime.now() : null,
        );
      }
      return;
    }

    try {
      await _supabase!
          .from('whatsapp_outbox')
          .update({'status': status.name, 'error_message': errorMessage, 'updated_at': DateTime.now().toIso8601String()})
          .eq('provider_message_id', wamid);

      final logData = <String, dynamic>{'status': status.name};
      if (errorCode != null) logData['error_code'] = errorCode;
      if (errorMessage != null) logData['error_message'] = errorMessage;
      if (status == WhatsAppDeliveryStatus.delivered) logData['delivered_at'] = DateTime.now().toIso8601String();
      if (status == WhatsAppDeliveryStatus.read) logData['read_at'] = DateTime.now().toIso8601String();

      await _supabase!
          .from('whatsapp_notification_logs')
          .update(logData)
          .eq('provider_message_id', wamid);
    } catch (e) {
      debugPrint('[WhatsAppService] DB error updating by wamid: $e');
    }
  }

  // 7. Notification History Fetching for Admin Screen
  Future<List<WhatsAppNotificationLog>> getNotificationLogs({
    String? classIdFilter,
    WhatsAppDeliveryStatus? statusFilter,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      var list = List<WhatsAppNotificationLog>.from(_demoLogs);
      if (classIdFilter != null && classIdFilter != 'All') {
        list = list.where((l) => l.classId == classIdFilter).toList();
      }
      if (statusFilter != null) {
        list = list.where((l) => l.status == statusFilter).toList();
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    try {
      var query = _supabase!.from('whatsapp_notification_logs').select();
      if (classIdFilter != null && classIdFilter != 'All') {
        query = query.eq('class_id', classIdFilter);
      }
      if (statusFilter != null) {
        query = query.eq('status', statusFilter.name);
      }

      final res = await query.order('created_at', ascending: false).limit(100);
      return (res as List).map((j) => WhatsAppNotificationLog.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  // E.164 phone cleaner
  static String normalizePhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91$clean';
    }
    if (!phone.startsWith('+')) {
      return '+$clean';
    }
    return phone;
  }

  // Testing helpers
  void resetDemoState() {
    _demoOutbox.clear();
    _demoLogs.clear();
    _processedWebhookEvents.clear();
    _settings = WhatsAppSettingsModel();
    mockFailMetaApi = false;
    mockCredentialMissing = false;
  }

  List<WhatsAppOutboxItem> get demoOutbox => List.unmodifiable(_demoOutbox);
  List<WhatsAppNotificationLog> get demoLogs => List.unmodifiable(_demoLogs);
}
