class StudentDiscrepancy {
  final String studentId;
  final String registerNumber;
  final String fullName;
  final String? morningStatus;
  final String? afternoonStatus;
  final String discrepancyType;

  StudentDiscrepancy({
    required this.studentId,
    required this.registerNumber,
    required this.fullName,
    this.morningStatus,
    this.afternoonStatus,
    required this.discrepancyType,
  });

  factory StudentDiscrepancy.fromJson(Map<String, dynamic> json) {
    return StudentDiscrepancy(
      studentId: json['student_id'] as String? ?? '',
      registerNumber: json['register_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      morningStatus: json['morning_status'] as String?,
      afternoonStatus: json['afternoon_status'] as String?,
      discrepancyType: json['discrepancy_type'] as String? ?? 'Normal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'register_number': registerNumber,
      'full_name': fullName,
      'morning_status': morningStatus,
      'afternoon_status': afternoonStatus,
      'discrepancy_type': discrepancyType,
    };
  }
}

class DailyReport {
  final String id;
  final String classId;
  final String attendanceDate;
  final String reportType; // preliminary or final
  final int totalEnrolled;
  final int morningPresent;
  final int morningAbsent;
  final int morningOd;
  final int afternoonPresent;
  final int afternoonAbsent;
  final int afternoonOd;
  final int afternoonBunk;
  final int bothPresent;
  final int bothAbsent;
  final int morningPresentAfternoonAbsent;
  final int morningAbsentAfternoonPresent;
  final int morningPresentAfternoonBunk;
  final int morningPresentAfternoonOd;
  final int morningOdAfternoonPresent;
  final int incompleteCount;
  final List<StudentDiscrepancy> discrepancies;
  final String status;
  final DateTime generatedAt;

  DailyReport({
    required this.id,
    required this.classId,
    required this.attendanceDate,
    required this.reportType,
    required this.totalEnrolled,
    required this.morningPresent,
    required this.morningAbsent,
    this.morningOd = 0,
    required this.afternoonPresent,
    required this.afternoonAbsent,
    this.afternoonOd = 0,
    this.afternoonBunk = 0,
    required this.bothPresent,
    required this.bothAbsent,
    required this.morningPresentAfternoonAbsent,
    required this.morningAbsentAfternoonPresent,
    this.morningPresentAfternoonBunk = 0,
    this.morningPresentAfternoonOd = 0,
    this.morningOdAfternoonPresent = 0,
    required this.incompleteCount,
    required this.discrepancies,
    required this.status,
    required this.generatedAt,
  });

  double get morningPercentage {
    final marked = morningPresent + morningAbsent + morningOd;
    if (marked == 0) return 0.0;
    return (morningPresent / marked) * 100.0;
  }

  double get afternoonPercentage {
    final marked = afternoonPresent + afternoonAbsent + afternoonOd + afternoonBunk;
    if (marked == 0) return 0.0;
    return (afternoonPresent / marked) * 100.0;
  }

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final reportData = json['report_data'] as Map<String, dynamic>? ?? {};
    final rawDiscrepancies = (reportData['discrepancies'] as List<dynamic>?) ?? [];

    return DailyReport(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      attendanceDate: json['attendance_date'] as String,
      reportType: json['report_type'] as String? ?? 'preliminary',
      totalEnrolled: reportData['total_enrolled'] as int? ?? 0,
      morningPresent: reportData['morning_present'] as int? ?? 0,
      morningAbsent: reportData['morning_absent'] as int? ?? 0,
      morningOd: reportData['morning_od'] as int? ?? 0,
      afternoonPresent: reportData['afternoon_present'] as int? ?? 0,
      afternoonAbsent: reportData['afternoon_absent'] as int? ?? 0,
      afternoonOd: reportData['afternoon_od'] as int? ?? 0,
      afternoonBunk: reportData['afternoon_bunk'] as int? ?? 0,
      bothPresent: reportData['both_present'] as int? ?? 0,
      bothAbsent: reportData['both_absent'] as int? ?? 0,
      morningPresentAfternoonAbsent: reportData['morning_present_afternoon_absent'] as int? ?? 0,
      morningAbsentAfternoonPresent: reportData['morning_absent_afternoon_present'] as int? ?? 0,
      morningPresentAfternoonBunk: reportData['morning_present_afternoon_bunk'] as int? ?? 0,
      morningPresentAfternoonOd: reportData['morning_present_afternoon_od'] as int? ?? 0,
      morningOdAfternoonPresent: reportData['morning_od_afternoon_present'] as int? ?? 0,
      incompleteCount: reportData['incomplete_count'] as int? ?? 0,
      discrepancies: rawDiscrepancies
          .map((item) => StudentDiscrepancy.fromJson(item as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'generated',
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'attendance_date': attendanceDate,
      'report_type': reportType,
      'status': status,
      'generated_at': generatedAt.toIso8601String(),
      'report_data': {
        'total_enrolled': totalEnrolled,
        'morning_present': morningPresent,
        'morning_absent': morningAbsent,
        'morning_od': morningOd,
        'afternoon_present': afternoonPresent,
        'afternoon_absent': afternoonAbsent,
        'afternoon_od': afternoonOd,
        'afternoon_bunk': afternoonBunk,
        'both_present': bothPresent,
        'both_absent': bothAbsent,
        'morning_present_afternoon_absent': morningPresentAfternoonAbsent,
        'morning_absent_afternoon_present': morningAbsentAfternoonPresent,
        'morning_present_afternoon_bunk': morningPresentAfternoonBunk,
        'morning_present_afternoon_od': morningPresentAfternoonOd,
        'morning_od_afternoon_present': morningOdAfternoonPresent,
        'incomplete_count': incompleteCount,
        'discrepancies': discrepancies.map((d) => d.toJson()).toList(),
      },
    };
  }
}
