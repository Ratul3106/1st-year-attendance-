import 'package:student_attendance_system/models/attendance_session.dart';

enum SessionWindowPhase { upcoming, open, closed }

class AttendanceWindowStatus {
  final SessionType sessionType;
  final SessionWindowPhase phase;
  final String timeRangeLabel;
  final Duration remaining;
  final DateTime windowStart;
  final DateTime windowEnd;

  const AttendanceWindowStatus({
    required this.sessionType,
    required this.phase,
    required this.timeRangeLabel,
    required this.remaining,
    required this.windowStart,
    required this.windowEnd,
  });

  bool get isOpen => phase == SessionWindowPhase.open;

  String get formattedRemaining {
    final totalSecs = remaining.inSeconds;
    if (totalSecs <= 0) return '0s';
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
  }

  String get shortLabel {
    switch (phase) {
      case SessionWindowPhase.open:
        return 'OPEN • Closes in $formattedRemaining';
      case SessionWindowPhase.upcoming:
        final startLabel = sessionType == SessionType.morning ? '8:15 AM' : '12:20 PM';
        return 'LOCKED • Opens at $startLabel ($formattedRemaining)';
      case SessionWindowPhase.closed:
        final endLabel = sessionType == SessionType.morning ? '8:45 AM' : '12:50 PM';
        return 'CLOSED • Ended at $endLabel';
    }
  }
}

/// Enforces strict daily attendance marking windows in IST (UTC+05:30):
/// - Morning Attendance: 8:15 AM to 8:45 AM IST
/// - Afternoon Attendance: 12:20 PM to 12:50 PM IST
/// Outside these timings, attendance marking is closed.
class AttendanceWindowHelper {
  static const int morningStartHour = 8;
  static const int morningStartMinute = 15;
  static const int morningEndHour = 8;
  static const int morningEndMinute = 45;

  static const int afternoonStartHour = 12;
  static const int afternoonStartMinute = 20;
  static const int afternoonEndHour = 12;
  static const int afternoonEndMinute = 50;

  static const String morningRangeLabel = '8:15 AM – 8:45 AM IST';
  static const String afternoonRangeLabel = '12:20 PM – 12:50 PM IST';

  /// Returns current date & time in IST (UTC+05:30) regardless of device timezone.
  static DateTime nowIst() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  static String todayIstString([DateTime? istTime]) {
    final t = istTime ?? nowIst();
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static AttendanceWindowStatus getWindowStatus(
    SessionType sessionType, [
    DateTime? istTime,
  ]) {
    final now = istTime ?? nowIst();
    final bool isMorning = sessionType == SessionType.morning;

    final windowStart = DateTime(
      now.year,
      now.month,
      now.day,
      isMorning ? morningStartHour : afternoonStartHour,
      isMorning ? morningStartMinute : afternoonStartMinute,
    );

    final windowEnd = DateTime(
      now.year,
      now.month,
      now.day,
      isMorning ? morningEndHour : afternoonEndHour,
      isMorning ? morningEndMinute : afternoonEndMinute,
    );

    final rangeLabel = isMorning ? morningRangeLabel : afternoonRangeLabel;

    if (now.isBefore(windowStart)) {
      return AttendanceWindowStatus(
        sessionType: sessionType,
        phase: SessionWindowPhase.upcoming,
        timeRangeLabel: rangeLabel,
        remaining: windowStart.difference(now),
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    if (now.isBefore(windowEnd)) {
      return AttendanceWindowStatus(
        sessionType: sessionType,
        phase: SessionWindowPhase.open,
        timeRangeLabel: rangeLabel,
        remaining: windowEnd.difference(now),
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    return AttendanceWindowStatus(
      sessionType: sessionType,
      phase: SessionWindowPhase.closed,
      timeRangeLabel: rangeLabel,
      remaining: Duration.zero,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  static bool isSessionOpen(SessionType sessionType, [DateTime? istTime]) {
    return getWindowStatus(sessionType, istTime).isOpen;
  }

  static String closedReason(SessionType sessionType, [DateTime? istTime]) {
    final status = getWindowStatus(sessionType, istTime);
    final name = sessionType == SessionType.morning ? 'Morning' : 'Afternoon';
    switch (status.phase) {
      case SessionWindowPhase.upcoming:
        return '$name attendance is not open yet. Marking window is ${status.timeRangeLabel} (opens in ${status.formattedRemaining}).';
      case SessionWindowPhase.closed:
        return '$name attendance marking window (${status.timeRangeLabel}) has closed for today.';
      case SessionWindowPhase.open:
        return '$name attendance is currently open (${status.timeRangeLabel}).';
    }
  }
}

