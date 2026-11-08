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
  manualAlert,
  dailyReportPreliminary,
  dailyReportFinal,
  attendanceReport;

  static WhatsAppNotificationType fromString(String val) {
    switch (val.toLowerCase().replaceAll('_', '').replaceAll(' ', '')) {
      case 'repeatedabsencesummary':
        return WhatsAppNotificationType.repeatedAbsenceSummary;
      case 'manualalert':
        return WhatsAppNotificationType.manualAlert;
      case 'dailyreportpreliminary':
        return WhatsAppNotificationType.dailyReportPreliminary;
      case 'dailyreportfinal':
        return WhatsAppNotificationType.dailyReportFinal;
      case 'attendancereport':
        return WhatsAppNotificationType.attendanceReport;
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
      case WhatsAppNotificationType.dailyReportPreliminary:
        return 'Preliminary Daily Report';
      case WhatsAppNotificationType.dailyReportFinal:
        return 'Final Daily Report';
      case WhatsAppNotificationType.attendanceReport:
        return 'Attendance Report';
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

/// Comprehensive model for Authorized WhatsApp Report Recipients
class AuthorizedRecipient {
  final String id;
  final String name;
  final String designation;
  final String phoneNumber;
  final List<String> assignedClassIds; // Empty list = all authorized classes
  final List<String> assignedClassNames;
  final String reportTypes; // 'preliminary', 'final', 'both'
  final String sessionPreferences; // 'morning', 'afternoon', 'combined'
  final bool active;
  final bool consentObtained;
  final DateTime createdAt;

  AuthorizedRecipient({
    required this.id,
    required this.name,
    required this.designation,
    required this.phoneNumber,
    this.assignedClassIds = const [],
    this.assignedClassNames = const [],
    this.reportTypes = 'both',
    this.sessionPreferences = 'combined',
    this.active = true,
    this.consentObtained = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get maskedPhoneNumber {
    final clean = phoneNumber.replaceAll(' ', '');
    if (clean.length < 8) return clean;
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 3);
    return '$prefix *** **$suffix';
  }

  bool isAuthorizedForClass(String classId) {
    if (assignedClassIds.isEmpty) return true; // All classes
    return assignedClassIds.contains(classId);
  }

  AuthorizedRecipient copyWith({
    String? id,
    String? name,
    String? designation,
    String? phoneNumber,
    List<String>? assignedClassIds,
    List<String>? assignedClassNames,
    String? reportTypes,
    String? sessionPreferences,
    bool? active,
    bool? consentObtained,
    DateTime? createdAt,
  }) {
    return AuthorizedRecipient(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      assignedClassIds: assignedClassIds ?? this.assignedClassIds,
      assignedClassNames: assignedClassNames ?? this.assignedClassNames,
      reportTypes: reportTypes ?? this.reportTypes,
      sessionPreferences: sessionPreferences ?? this.sessionPreferences,
      active: active ?? this.active,
      consentObtained: consentObtained ?? this.consentObtained,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AuthorizedRecipient.fromJson(Map<String, dynamic> json) {
    List<String> classes = [];
    if (json['assigned_class_ids'] is List) {
      classes = (json['assigned_class_ids'] as List).map((e) => e.toString()).toList();
    }
    List<String> classNames = [];
    if (json['assigned_class_names'] is List) {
      classNames = (json['assigned_class_names'] as List).map((e) => e.toString()).toList();
    }

    return AuthorizedRecipient(
      id: json['id'] as String? ?? UniqueKey().toString(),
      name: json['name'] as String? ?? '',
      designation: json['designation'] as String? ?? json['role'] as String? ?? 'Authorized Staff',
      phoneNumber: json['phone_number'] as String? ?? '',
      assignedClassIds: classes,
      assignedClassNames: classNames,
      reportTypes: json['report_types'] as String? ?? 'both',
      sessionPreferences: json['session_preferences'] as String? ?? 'combined',
      active: json['active'] as bool? ?? true,
      consentObtained: json['consent_obtained'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'designation': designation,
    'phone_number': phoneNumber,
    'assigned_class_ids': assignedClassIds,
    'assigned_class_names': assignedClassNames,
    'report_types': reportTypes,
    'session_preferences': sessionPreferences,
    'active': active,
    'consent_obtained': consentObtained,
    'created_at': createdAt.toIso8601String(),
  };
}

class WhatsAppSettingsModel {
  final bool immediateAlertsEnabled;
  final bool summaryAlertsEnabled;
  final bool reportsEnabled;
  final String reportTime;
  final String timezone;
  final String reportFrequency;
  final String targetClasses;
  final bool includeMorning;
  final bool includeAfternoon;
  final bool includeCombined;
  final bool sendPreliminary;
  final bool sendFinalOnCompletion;
  final int absenceThreshold;
  final int reportingWindowDays;
  final String phoneNumberId;
  final String businessAccountId;
  final String apiVersion;
  final String reportTemplateName;
  final String reportTemplateLang;
  final String absenceTemplateName;
  final String absenceTemplateLang;
  final String summaryTemplateName;
  final String summaryTemplateLang;
  final String deanPlacementPhone;
  final String deanPlacementName;
  final String adminName;
  final String adminPhone;
  final String reportScope; // 'all' or 'selected'
  final List<String> selectedClassIds;
  final bool includeComparisons;
  final DateTime? lastReportGeneratedAt;
  final DateTime? lastSendAttemptAt;
  final String? lastDeliveryStatus;
  final String apiStatus;
  final bool isTokenConfigured;
  final List<WhatsAppRecipient> additionalRecipients;
  final List<AuthorizedRecipient> authorizedRecipients;

  WhatsAppSettingsModel({
    this.immediateAlertsEnabled = true,
    this.summaryAlertsEnabled = true,
    this.reportsEnabled = true,
    this.reportTime = '14:00',
    this.timezone = 'Asia/Kolkata',
    this.reportFrequency = 'daily',
    this.targetClasses = 'all',
    this.includeMorning = true,
    this.includeAfternoon = true,
    this.includeCombined = true,
    this.sendPreliminary = true,
    this.sendFinalOnCompletion = true,
    this.absenceThreshold = 3,
    this.reportingWindowDays = 7,
    this.phoneNumberId = '100000000000000',
    this.businessAccountId = '200000000000000',
    this.apiVersion = 'v21.0',
    this.reportTemplateName = 'attendance_daily_report',
    this.reportTemplateLang = 'en_US',
    this.absenceTemplateName = 'attendance_absence_alert',
    this.absenceTemplateLang = 'en_US',
    this.summaryTemplateName = 'attendance_repeat_summary',
    this.summaryTemplateLang = 'en_US',
    this.deanPlacementPhone = '+919876543200',
    this.deanPlacementName = 'Dean of Placement and Training',
    this.adminName = 'Dr. Ramesh Sharma (Administrator)',
    this.adminPhone = '+918072459331',
    this.reportScope = 'all',
    this.selectedClassIds = const [],
    this.includeComparisons = true,
    this.lastReportGeneratedAt,
    this.lastSendAttemptAt,
    this.lastDeliveryStatus = 'Delivered',
    this.apiStatus = 'Connected',
    this.isTokenConfigured = true,
    this.additionalRecipients = const [],
    this.authorizedRecipients = const [],
  });

  String get maskedAdminPhone {
    final clean = adminPhone.replaceAll(' ', '');
    if (clean.length < 8) return clean;
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 3);
    return '$prefix *** **$suffix';
  }

  WhatsAppSettingsModel copyWith({
    bool? immediateAlertsEnabled,
    bool? summaryAlertsEnabled,
    bool? reportsEnabled,
    String? reportTime,
    String? timezone,
    String? reportFrequency,
    String? targetClasses,
    bool? includeMorning,
    bool? includeAfternoon,
    bool? includeCombined,
    bool? sendPreliminary,
    bool? sendFinalOnCompletion,
    int? absenceThreshold,
    int? reportingWindowDays,
    String? phoneNumberId,
    String? businessAccountId,
    String? apiVersion,
    String? reportTemplateName,
    String? reportTemplateLang,
    String? absenceTemplateName,
    String? absenceTemplateLang,
    String? summaryTemplateName,
    String? summaryTemplateLang,
    String? deanPlacementPhone,
    String? deanPlacementName,
    String? adminName,
    String? adminPhone,
    String? reportScope,
    List<String>? selectedClassIds,
    bool? includeComparisons,
    DateTime? lastReportGeneratedAt,
    DateTime? lastSendAttemptAt,
    String? lastDeliveryStatus,
    String? apiStatus,
    bool? isTokenConfigured,
    List<WhatsAppRecipient>? additionalRecipients,
    List<AuthorizedRecipient>? authorizedRecipients,
  }) {
    return WhatsAppSettingsModel(
      immediateAlertsEnabled: immediateAlertsEnabled ?? this.immediateAlertsEnabled,
      summaryAlertsEnabled: summaryAlertsEnabled ?? this.summaryAlertsEnabled,
      reportsEnabled: reportsEnabled ?? this.reportsEnabled,
      reportTime: reportTime ?? this.reportTime,
      timezone: timezone ?? this.timezone,
      reportFrequency: reportFrequency ?? this.reportFrequency,
      targetClasses: targetClasses ?? this.targetClasses,
      includeMorning: includeMorning ?? this.includeMorning,
      includeAfternoon: includeAfternoon ?? this.includeAfternoon,
      includeCombined: includeCombined ?? this.includeCombined,
      sendPreliminary: sendPreliminary ?? this.sendPreliminary,
      sendFinalOnCompletion: sendFinalOnCompletion ?? this.sendFinalOnCompletion,
      absenceThreshold: absenceThreshold ?? this.absenceThreshold,
      reportingWindowDays: reportingWindowDays ?? this.reportingWindowDays,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      businessAccountId: businessAccountId ?? this.businessAccountId,
      apiVersion: apiVersion ?? this.apiVersion,
      reportTemplateName: reportTemplateName ?? this.reportTemplateName,
      reportTemplateLang: reportTemplateLang ?? this.reportTemplateLang,
      absenceTemplateName: absenceTemplateName ?? this.absenceTemplateName,
      absenceTemplateLang: absenceTemplateLang ?? this.absenceTemplateLang,
      summaryTemplateName: summaryTemplateName ?? this.summaryTemplateName,
      summaryTemplateLang: summaryTemplateLang ?? this.summaryTemplateLang,
      deanPlacementPhone: deanPlacementPhone ?? this.deanPlacementPhone,
      deanPlacementName: deanPlacementName ?? this.deanPlacementName,
      adminName: adminName ?? this.adminName,
      adminPhone: adminPhone ?? this.adminPhone,
      reportScope: reportScope ?? this.reportScope,
      selectedClassIds: selectedClassIds ?? this.selectedClassIds,
      includeComparisons: includeComparisons ?? this.includeComparisons,
      lastReportGeneratedAt: lastReportGeneratedAt ?? this.lastReportGeneratedAt,
      lastSendAttemptAt: lastSendAttemptAt ?? this.lastSendAttemptAt,
      lastDeliveryStatus: lastDeliveryStatus ?? this.lastDeliveryStatus,
      apiStatus: apiStatus ?? this.apiStatus,
      isTokenConfigured: isTokenConfigured ?? this.isTokenConfigured,
      additionalRecipients: additionalRecipients ?? this.additionalRecipients,
      authorizedRecipients: authorizedRecipients ?? this.authorizedRecipients,
    );
  }

  factory WhatsAppSettingsModel.fromJson(Map<String, dynamic> json) {
    var addRecipients = <WhatsAppRecipient>[];
    if (json['additional_recipients'] != null) {
      final list = json['additional_recipients'] as List;
      addRecipients = list.map((e) => WhatsAppRecipient.fromJson(e as Map<String, dynamic>)).toList();
    }

    var authRecipients = <AuthorizedRecipient>[];
    if (json['authorized_recipients'] != null) {
      final list = json['authorized_recipients'] as List;
      authRecipients = list.map((e) => AuthorizedRecipient.fromJson(e as Map<String, dynamic>)).toList();
    }

    List<String> selClassIds = [];
    if (json['selected_class_ids'] != null && json['selected_class_ids'] is List) {
      selClassIds = (json['selected_class_ids'] as List).map((e) => e.toString()).toList();
    }

    return WhatsAppSettingsModel(
      immediateAlertsEnabled: json['immediate_alerts_enabled'] as bool? ?? true,
      summaryAlertsEnabled: json['summary_alerts_enabled'] as bool? ?? true,
      reportsEnabled: json['reports_enabled'] as bool? ?? true,
      reportTime: json['report_time'] as String? ?? '14:00',
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      reportFrequency: json['report_frequency'] as String? ?? 'daily',
      targetClasses: json['target_classes'] as String? ?? 'all',
      includeMorning: json['include_morning'] as bool? ?? true,
      includeAfternoon: json['include_afternoon'] as bool? ?? true,
      includeCombined: json['include_combined'] as bool? ?? true,
      sendPreliminary: json['send_preliminary'] as bool? ?? true,
      sendFinalOnCompletion: json['send_final_on_completion'] as bool? ?? true,
      absenceThreshold: json['absence_threshold'] as int? ?? 3,
      reportingWindowDays: json['reporting_window_days'] as int? ?? 7,
      phoneNumberId: json['phone_number_id'] as String? ?? '100000000000000',
      businessAccountId: json['business_account_id'] as String? ?? '200000000000000',
      apiVersion: json['api_version'] as String? ?? 'v21.0',
      reportTemplateName: json['report_template_name'] as String? ?? 'attendance_daily_report',
      reportTemplateLang: json['report_template_lang'] as String? ?? 'en_US',
      absenceTemplateName: json['absence_template_name'] as String? ?? 'attendance_absence_alert',
      absenceTemplateLang: json['absence_template_lang'] as String? ?? 'en_US',
      summaryTemplateName: json['summary_template_name'] as String? ?? 'attendance_repeat_summary',
      summaryTemplateLang: json['summary_template_lang'] as String? ?? 'en_US',
      deanPlacementPhone: json['dean_placement_phone'] as String? ?? '+919876543200',
      deanPlacementName: json['dean_placement_name'] as String? ?? 'Dean of Placement and Training',
      adminName: json['admin_name'] as String? ?? 'Dr. Ramesh Sharma (Administrator)',
      adminPhone: json['admin_phone'] as String? ?? '+919876543200',
      reportScope: json['report_scope'] as String? ?? 'all',
      selectedClassIds: selClassIds,
      includeComparisons: json['include_comparisons'] as bool? ?? true,
      lastReportGeneratedAt: json['last_report_generated_at'] != null ? DateTime.parse(json['last_report_generated_at'] as String) : null,
      lastSendAttemptAt: json['last_send_attempt_at'] != null ? DateTime.parse(json['last_send_attempt_at'] as String) : null,
      lastDeliveryStatus: json['last_delivery_status'] as String? ?? 'Delivered',
      apiStatus: json['api_status'] as String? ?? 'Connected',
      isTokenConfigured: json['is_token_configured'] as bool? ?? true,
      additionalRecipients: addRecipients,
      authorizedRecipients: authRecipients,
    );
  }

  Map<String, dynamic> toJson() => {
    'immediate_alerts_enabled': immediateAlertsEnabled,
    'summary_alerts_enabled': summaryAlertsEnabled,
    'reports_enabled': reportsEnabled,
    'report_time': reportTime,
    'timezone': timezone,
    'report_frequency': reportFrequency,
    'target_classes': targetClasses,
    'include_morning': includeMorning,
    'include_afternoon': includeAfternoon,
    'include_combined': includeCombined,
    'send_preliminary': sendPreliminary,
    'send_final_on_completion': sendFinalOnCompletion,
    'absence_threshold': absenceThreshold,
    'reporting_window_days': reportingWindowDays,
    'phone_number_id': phoneNumberId,
    'business_account_id': businessAccountId,
    'api_version': apiVersion,
    'report_template_name': reportTemplateName,
    'report_template_lang': reportTemplateLang,
    'absence_template_name': absenceTemplateName,
    'absence_template_lang': absenceTemplateLang,
    'summary_template_name': summaryTemplateName,
    'summary_template_lang': summaryTemplateLang,
    'dean_placement_phone': deanPlacementPhone,
    'dean_placement_name': deanPlacementName,
    'admin_name': adminName,
    'admin_phone': adminPhone,
    'report_scope': reportScope,
    'selected_class_ids': selectedClassIds,
    'include_comparisons': includeComparisons,
    'last_report_generated_at': lastReportGeneratedAt?.toIso8601String(),
    'last_send_attempt_at': lastSendAttemptAt?.toIso8601String(),
    'last_delivery_status': lastDeliveryStatus,
    'api_status': apiStatus,
    'is_token_configured': isTokenConfigured,
    'additional_recipients': additionalRecipients.map((r) => r.toJson()).toList(),
    'authorized_recipients': authorizedRecipients.map((r) => r.toJson()).toList(),
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

/// Comprehensive model for WhatsApp Attendance Reports
class AttendanceReportModel {
  final String id;
  final String reportDate;
  final String classId;
  final String className;
  final String department;
  final String academicYear;
  final String reportType; // 'preliminary', 'final'
  final String sessionType; // 'morning', 'afternoon', 'combined'
  final int totalEnrolled;
  final int morningPresent;
  final int morningAbsent;
  final int morningOd;
  final int morningUnmarked;
  final double morningPercentage;
  final int afternoonPresent;
  final int afternoonAbsent;
  final int afternoonOd;
  final int afternoonBunk;
  final int afternoonUnmarked;
  final double afternoonPercentage;
  final int presentBoth;
  final int presentMorningAbsentAfternoon;
  final int afternoonBunkCount;
  final String status;
  final DateTime generatedAt;

  AttendanceReportModel({
    required this.id,
    required this.reportDate,
    required this.classId,
    required this.className,
    required this.department,
    required this.academicYear,
    required this.reportType,
    this.sessionType = 'combined',
    required this.totalEnrolled,
    required this.morningPresent,
    required this.morningAbsent,
    required this.morningOd,
    required this.morningUnmarked,
    required this.morningPercentage,
    required this.afternoonPresent,
    required this.afternoonAbsent,
    required this.afternoonOd,
    required this.afternoonBunk,
    required this.afternoonUnmarked,
    required this.afternoonPercentage,
    required this.presentBoth,
    required this.presentMorningAbsentAfternoon,
    required this.afternoonBunkCount,
    this.status = 'generated',
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  bool get isPreliminary => reportType.toLowerCase() == 'preliminary';
  bool get isFinal => reportType.toLowerCase() == 'final';
  bool get isMorningComplete => morningUnmarked == 0 && (morningPresent + morningAbsent + morningOd) > 0;
  bool get isAfternoonComplete => afternoonUnmarked == 0 && (afternoonPresent + afternoonAbsent + afternoonOd + afternoonBunk) > 0;

  /// Generates concise, professional report formatted exactly per Section 5 specification
  String get formattedMessage {
    final statusUpper = isFinal ? 'FINAL' : 'PRELIMINARY';
    final timestamp = _formatTimestamp(generatedAt);

    return '''STUDENT ATTENDANCE REPORT

Date: $reportDate
Department: $department
Class: $className
Academic Year: $academicYear

MORNING ATTENDANCE
Total Students: $totalEnrolled
Present: $morningPresent
Absent: $morningAbsent
OD: $morningOd
Not Marked: $morningUnmarked
Attendance: ${morningPercentage.toStringAsFixed(1)}%

AFTERNOON ATTENDANCE
Total Students: $totalEnrolled
Present: $afternoonPresent
Absent: $afternoonAbsent
OD: $afternoonOd
Bunk: $afternoonBunk
Not Marked: $afternoonUnmarked
Attendance: ${afternoonPercentage.toStringAsFixed(1)}%

SESSION COMPARISON
Present in Both Sessions: $presentBoth
Morning Present → Afternoon Absent: $presentMorningAbsentAfternoon
Afternoon Bunk: $afternoonBunkCount

Report Status: $statusUpper

Generated At: $timestamp

Student Attendance Management System''';
  }

  static String _formatTimestamp(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, ${hour.toString().padLeft(2, '0')}:$min $ampm IST";
  }

  factory AttendanceReportModel.fromJson(Map<String, dynamic> json) {
    return AttendanceReportModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      reportDate: json['report_date'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? 'Class',
      department: json['department'] as String? ?? 'General',
      academicYear: json['academic_year'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'preliminary',
      sessionType: json['session_type'] as String? ?? 'combined',
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      morningPresent: json['morning_present'] as int? ?? 0,
      morningAbsent: json['morning_absent'] as int? ?? 0,
      morningOd: json['morning_od'] as int? ?? 0,
      morningUnmarked: json['morning_unmarked'] as int? ?? 0,
      morningPercentage: (json['morning_percentage'] as num?)?.toDouble() ?? 0.0,
      afternoonPresent: json['afternoon_present'] as int? ?? 0,
      afternoonAbsent: json['afternoon_absent'] as int? ?? 0,
      afternoonOd: json['afternoon_od'] as int? ?? 0,
      afternoonBunk: json['afternoon_bunk'] as int? ?? 0,
      afternoonUnmarked: json['afternoon_unmarked'] as int? ?? 0,
      afternoonPercentage: (json['afternoon_percentage'] as num?)?.toDouble() ?? 0.0,
      presentBoth: json['present_both'] as int? ?? 0,
      presentMorningAbsentAfternoon: json['present_morning_absent_afternoon'] as int? ?? 0,
      afternoonBunkCount: json['afternoon_bunk_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'generated',
      generatedAt: json['generated_at'] != null ? DateTime.parse(json['generated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'report_date': reportDate,
    'class_id': classId,
    'class_name': className,
    'department': department,
    'academic_year': academicYear,
    'report_type': reportType,
    'session_type': sessionType,
    'total_enrolled': totalEnrolled,
    'morning_present': morningPresent,
    'morning_absent': morningAbsent,
    'morning_od': morningOd,
    'morning_unmarked': morningUnmarked,
    'morning_percentage': morningPercentage,
    'afternoon_present': afternoonPresent,
    'afternoon_absent': afternoonAbsent,
    'afternoon_od': afternoonOd,
    'afternoon_bunk': afternoonBunk,
    'afternoon_unmarked': afternoonUnmarked,
    'afternoon_percentage': afternoonPercentage,
    'present_both': presentBoth,
    'present_morning_absent_afternoon': presentMorningAbsentAfternoon,
    'afternoon_bunk_count': afternoonBunkCount,
    'status': status,
    'generated_at': generatedAt.toIso8601String(),
    'formatted_message': formattedMessage,
  };
}

class WhatsAppNotificationLog {
  final String id;
  final String? outboxId;
  final String? reportId;
  final String? reportDate;
  final String? reportTypeLabel;
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
  final int retryCount;
  final int maxRetries;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime createdAt;

  WhatsAppNotificationLog({
    required this.id,
    this.outboxId,
    this.reportId,
    this.reportDate,
    this.reportTypeLabel,
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
    this.retryCount = 0,
    this.maxRetries = 5,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    required this.createdAt,
  });

  String get deliveryId => id;
  String? get failureReason => errorMessage;
  DateTime get attemptTimestamp => createdAt;
  DateTime? get deliveryTimestamp => deliveredAt;
  DateTime? get readTimestamp => readAt;
  bool get canRetry => status == WhatsAppDeliveryStatus.failed && retryCount < maxRetries;

  String get maskedPhone {
    final clean = recipientPhone.replaceAll(' ', '');
    if (clean.length < 8) return clean;
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 3);
    return '$prefix *** **$suffix';
  }

  WhatsAppNotificationLog copyWith({
    WhatsAppDeliveryStatus? status,
    String? providerMessageId,
    String? errorCode,
    String? errorMessage,
    int? retryCount,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return WhatsAppNotificationLog(
      id: id,
      outboxId: outboxId,
      reportId: reportId,
      reportDate: reportDate,
      reportTypeLabel: reportTypeLabel,
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
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
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
      reportId: json['report_id'] as String?,
      reportDate: json['report_date'] as String?,
      reportTypeLabel: json['report_type_label'] as String? ?? json['report_type'] as String?,
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
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 5,
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
