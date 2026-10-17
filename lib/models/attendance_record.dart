enum AttendanceStatus {
  present,
  absent,
  od,
  bunk;

  static AttendanceStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'present':
      case 'p':
        return AttendanceStatus.present;
      case 'absent':
      case 'a':
        return AttendanceStatus.absent;
      case 'od':
        return AttendanceStatus.od;
      case 'bunk':
      case 'b':
        return AttendanceStatus.bunk;
      default:
        return AttendanceStatus.present;
    }
  }

  String get dbValue {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.od:
        return 'od';
      case AttendanceStatus.bunk:
        return 'bunk';
    }
  }

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.od:
        return 'OD';
      case AttendanceStatus.bunk:
        return 'Bunk';
    }
  }

  String get shortCode {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.od:
        return 'OD';
      case AttendanceStatus.bunk:
        return 'B';
    }
  }
}

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final AttendanceStatus status;
  final String markedBy;
  final DateTime markedAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.markedBy,
    required this.markedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      studentId: json['student_id'] as String,
      status: AttendanceStatus.fromString(json['status'] as String?),
      markedBy: json['marked_by'] as String? ?? '',
      markedAt: json['marked_at'] != null
          ? DateTime.parse(json['marked_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'status': status.dbValue,
      'marked_by': markedBy,
      'marked_at': markedAt.toIso8601String(),
    };
  }
}
