enum SessionType { morning, afternoon }
enum SessionStatus { open, closed }

class AttendanceSession {
  final String id;
  final String classId;
  final String attendanceDate; // YYYY-MM-DD
  final SessionType sessionType;
  final SessionStatus status;
  final String openedBy;
  final DateTime openedAt;
  final DateTime? closedAt;

  AttendanceSession({
    required this.id,
    required this.classId,
    required this.attendanceDate,
    required this.sessionType,
    required this.status,
    required this.openedBy,
    required this.openedAt,
    this.closedAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      attendanceDate: json['attendance_date'] as String,
      sessionType: (json['session_type'] as String? ?? 'morning') == 'morning'
          ? SessionType.morning
          : SessionType.afternoon,
      status: (json['status'] as String? ?? 'open') == 'open'
          ? SessionStatus.open
          : SessionStatus.closed,
      openedBy: json['opened_by'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
    );
  }
}
