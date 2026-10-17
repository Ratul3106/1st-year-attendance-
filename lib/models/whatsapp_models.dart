import 'package:flutter/foundation.dart';

enum WhatsAppDeliveryStatus {
  queued,
  processing,
  sent,
  delivered,
  read,
  failed;

  static WhatsAppDeliveryStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'processing':
        return WhatsAppDeliveryStatus.processing;
      case 'sent':
        return WhatsAppDeliveryStatus.sent;
      case 'delivered':
        return WhatsAppDeliveryStatus.delivered;
      case 'read':
        return WhatsAppDeliveryStatus.read;
      case 'failed':
        return WhatsAppDeliveryStatus.failed;
      case 'queued':
      default:
        return WhatsAppDeliveryStatus.queued;
    }
  }

  String get displayName {
    switch (this) {
      case WhatsAppDeliveryStatus.queued:
        return 'Queued';
      case WhatsAppDeliveryStatus.processing:
        return 'Processing';
      case WhatsAppDeliveryStatus.sent:
        return 'Sent';
      case WhatsAppDeliveryStatus.delivered:
        return 'Delivered';
      case WhatsAppDeliveryStatus.read:
        return 'Read';
      case WhatsAppDeliveryStatus.failed:
        return 'Failed';
    }
  }
}

enum WhatsAppNotificationType {
  immediateAbsence,
  repeatedAbsenceSummary,
  manualAlert;

  static WhatsAppNotificationType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'repeated_absence_summary':
      case 'repeatedabsencesummary':
        return WhatsAppNotificationType.repeatedAbsenceSummary;
      case 'manual_alert':
      case 'manualalert':
        return WhatsAppNotificationType.manualAlert;
      case 'immediate_absence':
      case 'immediateabsence':
      default:
        return WhatsAppNotificationType.immediateAbsence;
    }
  }

  String get displayName {
    switch (this) {
      case WhatsAppNotificationType.immediateAbsence:
        return 'Immediate Absence Alert';
      case WhatsAppNotificationType.repeatedAbsenceSummary:
        return 'Repeated-Absence Summary';
      case WhatsAppNotificationType.manualAlert:
        return 'Manual Alert';
    }
  }
}

class WhatsAppRecipient {
  final String id;
  final String name;
  final String role;
  final String phoneNumber;
  final bool active;

  WhatsAppRecipient({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneNumber,
    this.active = true,
  });

  factory WhatsAppRecipient.fromJson(Map<String, dynamic> json) {
    return WhatsAppRecipient(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'Authorized Staff',
      phoneNumber: json['phone_number'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'phone_number': phoneNumber,
    'active': active,
  };
}

class WhatsAppSettingsModel {
  final bool immediateAlertsEnabled;
  final bool summaryAlertsEnabled;
  final int absenceThreshold;
  final int reportingWindowDays;
  final String timezone;
  final String phoneNumberId;
  final String apiVersion;
  final String absenceTemplateName;
  final String absenceTemplateLang;
  final String summaryTemplateName;
  final String summaryTemplateLang;
  final String deanPlacementPhone;
  final String deanPlacementName;
  final List<WhatsAppRecipient> additionalRecipients;

  WhatsAppSettingsModel({
    this.immediateAlertsEnabled = true,
    this.summaryAlertsEnabled = true,
    this.absenceThreshold = 3,
    this.reportingWindowDays = 7,
    this.timezone = 'Asia/Kolkata',
    this.phoneNumberId = '100000000000000',
    this.apiVersion = 'v21.0',
    this.absenceTemplateName = 'attendance_absence_alert',
    this.absenceTemplateLang = 'en_US',
    this.summaryTemplateName = 'attendance_repeat_summary',
    this.summaryTemplateLang = 'en_US',
    this.deanPlacementPhone = '+919876543200',
    this.deanPlacementName = 'Dean of Placement and Training',
    this.additionalRecipients = const [],
  });

  WhatsAppSettingsModel copyWith({
    bool? immediateAlertsEnabled,
    bool? summaryAlertsEnabled,
    int? absenceThreshold,
    int? reportingWindowDays,
    String? timezone,
    String? phoneNumberId,
    String? apiVersion,
    String? absenceTemplateName,
    String? absenceTemplateLang,
    String? summaryTemplateName,
    String? summaryTemplateLang,
    String? deanPlacementPhone,
    String? deanPlacementName,
    List<WhatsAppRecipient>? additionalRecipients,
  }) {
    return WhatsAppSettingsModel(
      immediateAlertsEnabled: immediateAlertsEnabled ?? this.immediateAlertsEnabled,
      summaryAlertsEnabled: summaryAlertsEnabled ?? this.summaryAlertsEnabled,
      absenceThreshold: absenceThreshold ?? this.absenceThreshold,
      reportingWindowDays: reportingWindowDays ?? this.reportingWindowDays,
      timezone: timezone ?? this.timezone,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      apiVersion: apiVersion ?? this.apiVersion,
      absenceTemplateName: absenceTemplateName ?? this.absenceTemplateName,
      absenceTemplateLang: absenceTemplateLang ?? this.absenceTemplateLang,
      summaryTemplateName: summaryTemplateName ?? this.summaryTemplateName,
      summaryTemplateLang: summaryTemplateLang ?? this.summaryTemplateLang,
      deanPlacementPhone: deanPlacementPhone ?? this.deanPlacementPhone,
      deanPlacementName: deanPlacementName ?? this.deanPlacementName,
      additionalRecipients: additionalRecipients ?? this.additionalRecipients,
    );
  }

  factory WhatsAppSettingsModel.fromJson(Map<String, dynamic> json) {
    var addRecipients = <WhatsAppRecipient>[];
    if (json['additional_recipients'] != null) {
      final list = json['additional_recipients'] as List;
      addRecipients = list.map((e) => WhatsAppRecipient.fromJson(e as Map<String, dynamic>)).toList();
    }
    return WhatsAppSettingsModel(
      immediateAlertsEnabled: json['immediate_alerts_enabled'] as bool? ?? true,
      summaryAlertsEnabled: json['summary_alerts_enabled'] as bool? ?? true,
      absenceThreshold: json['absence_threshold'] as int? ?? 3,
      reportingWindowDays: json['reporting_window_days'] as int? ?? 7,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      phoneNumberId: json['phone_number_id'] as String? ?? '100000000000000',
      apiVersion: json['api_version'] as String? ?? 'v21.0',
      absenceTemplateName: json['absence_template_name'] as String? ?? 'attendance_absence_alert',
      absenceTemplateLang: json['absence_template_lang'] as String? ?? 'en_US',
      summaryTemplateName: json['summary_template_name'] as String? ?? 'attendance_repeat_summary',
      summaryTemplateLang: json['summary_template_lang'] as String? ?? 'en_US',
      deanPlacementPhone: json['dean_placement_phone'] as String? ?? '+919876543200',
      deanPlacementName: json['dean_placement_name'] as String? ?? 'Dean of Placement and Training',
      additionalRecipients: addRecipients,
    );
  }

  Map<String, dynamic> toJson() => {
    'immediate_alerts_enabled': immediateAlertsEnabled,
    'summary_alerts_enabled': summaryAlertsEnabled,
    'absence_threshold': absenceThreshold,
    'reporting_window_days': reportingWindowDays,
    'timezone': timezone,
    'phone_number_id': phoneNumberId,
    'api_version': apiVersion,
    'absence_template_name': absenceTemplateName,
    'absence_template_lang': absenceTemplateLang,
    'summary_template_name': summaryTemplateName,
    'summary_template_lang': summaryTemplateLang,
    'dean_placement_phone': deanPlacementPhone,
    'dean_placement_name': deanPlacementName,
    'additional_recipients': additionalRecipients.map((r) => r.toJson()).toList(),
  };
}

class WhatsAppOutboxItem {
  final String id;
  final WhatsAppNotificationType notificationType;
  final String recipientPhone;
  final String recipientName;
  final String recipientRole;
  final String templateName;
  final String templateLanguage;
  final List<String> templateParameters;
  final Map<String, dynamic> payload;
  final WhatsAppDeliveryStatus status;
  final int retryCount;
  final int maxRetries;
  final DateTime nextRetryAt;
  final String? providerMessageId;
  final String? errorMessage;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  WhatsAppOutboxItem({
    required this.id,
    required this.notificationType,
    required this.recipientPhone,
    required this.recipientName,
    required this.recipientRole,
    required this.templateName,
    this.templateLanguage = 'en_US',
    required this.templateParameters,
    required this.payload,
    this.status = WhatsAppDeliveryStatus.queued,
    this.retryCount = 0,
    this.maxRetries = 5,
    required this.nextRetryAt,
    this.providerMessageId,
    this.errorMessage,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
  });

  WhatsAppOutboxItem copyWith({
    WhatsAppDeliveryStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    String? providerMessageId,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return WhatsAppOutboxItem(
      id: id,
      notificationType: notificationType,
      recipientPhone: recipientPhone,
      recipientName: recipientName,
      recipientRole: recipientRole,
      templateName: templateName,
      templateLanguage: templateLanguage,
      templateParameters: templateParameters,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      providerMessageId: providerMessageId ?? this.providerMessageId,
      errorMessage: errorMessage ?? this.errorMessage,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WhatsAppOutboxItem.fromJson(Map<String, dynamic> json) {
    List<String> params = [];
    if (json['template_parameters'] is List) {
      params = (json['template_parameters'] as List).map((e) => e.toString()).toList();
    }
    return WhatsAppOutboxItem(
      id: json['id'] as String,
      notificationType: WhatsAppNotificationType.fromString(json['notification_type'] as String? ?? 'immediate_absence'),
      recipientPhone: json['recipient_phone'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? '',
      recipientRole: json['recipient_role'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      templateLanguage: json['template_language'] as String? ?? 'en_US',
      templateParameters: params,
      payload: json['payload'] as Map<String, dynamic>? ?? {},
      status: WhatsAppDeliveryStatus.fromString(json['status'] as String? ?? 'queued'),
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 5,
      nextRetryAt: json['next_retry_at'] != null ? DateTime.parse(json['next_retry_at'] as String) : DateTime.now(),
      providerMessageId: json['provider_message_id'] as String?,
      errorMessage: json['error_message'] as String?,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }
}

class WhatsAppNotificationLog {
  final String id;
  final String? outboxId;
  final String? studentId;
  final String? studentName;
  final String? registerNumber;
  final String? classId;
  final String? className;
  final String? sessionId;
  final WhatsAppNotificationType notificationType;
  final String recipientPhone;
  final String recipientName;
  final String recipientRole;
  final String? providerMessageId;
  final WhatsAppDeliveryStatus status;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime createdAt;

  WhatsAppNotificationLog({
    required this.id,
    this.outboxId,
    this.studentId,
    this.studentName,
    this.registerNumber,
    this.classId,
    this.className,
    this.sessionId,
    required this.notificationType,
    required this.recipientPhone,
    required this.recipientName,
    required this.recipientRole,
    this.providerMessageId,
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    required this.createdAt,
  });

  WhatsAppNotificationLog copyWith({
    WhatsAppDeliveryStatus? status,
    String? providerMessageId,
    String? errorCode,
    String? errorMessage,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return WhatsAppNotificationLog(
      id: id,
      outboxId: outboxId,
      studentId: studentId,
      studentName: studentName,
      registerNumber: registerNumber,
      classId: classId,
      className: className,
      sessionId: sessionId,
      notificationType: notificationType,
      recipientPhone: recipientPhone,
      recipientName: recipientName,
      recipientRole: recipientRole,
      providerMessageId: providerMessageId ?? this.providerMessageId,
      status: status ?? this.status,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory WhatsAppNotificationLog.fromJson(Map<String, dynamic> json) {
    return WhatsAppNotificationLog(
      id: json['id'] as String,
      outboxId: json['outbox_id'] as String?,
      studentId: json['student_id'] as String?,
      studentName: json['student_name'] as String?,
      registerNumber: json['register_number'] as String?,
      classId: json['class_id'] as String?,
      className: json['class_name'] as String?,
      sessionId: json['session_id'] as String?,
      notificationType: WhatsAppNotificationType.fromString(json['notification_type'] as String? ?? 'immediate_absence'),
      recipientPhone: json['recipient_phone'] as String? ?? '',
      recipientName: json['recipient_name'] as String? ?? '',
      recipientRole: json['recipient_role'] as String? ?? '',
      providerMessageId: json['provider_message_id'] as String?,
      status: WhatsAppDeliveryStatus.fromString(json['status'] as String? ?? 'queued'),
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }
}

class WhatsAppAbsenceSummaryResult {
  final String classId;
  final String className;
  final String department;
  final int qualifyingCount;
  final List<Map<String, dynamic>> qualifyingStudents;
  final String periodStart;
  final String periodEnd;
  final bool deanNotified;
  final String idempotencyKey;

  WhatsAppAbsenceSummaryResult({
    required this.classId,
    required this.className,
    required this.department,
    required this.qualifyingCount,
    required this.qualifyingStudents,
    required this.periodStart,
    required this.periodEnd,
    required this.deanNotified,
    required this.idempotencyKey,
  });
}
