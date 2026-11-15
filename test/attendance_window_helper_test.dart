import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/core/utils/attendance_window_helper.dart';
import 'package:student_attendance_system/models/attendance_session.dart';

void main() {
  group('AttendanceWindowHelper', () {
    test('Morning window is strictly open from 8:15 AM to 8:45 AM IST', () {
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 14, 59),
        ),
        isFalse,
      );
      expect(
        AttendanceWindowHelper.getWindowStatus(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 14, 59),
        ).phase,
        SessionWindowPhase.upcoming,
      );

      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 15, 0),
        ),
        isTrue,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 30, 0),
        ),
        isTrue,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 44, 59),
        ),
        isTrue,
      );

      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 45, 0),
        ),
        isFalse,
      );
      expect(
        AttendanceWindowHelper.getWindowStatus(
          SessionType.morning,
          DateTime(2026, 11, 10, 8, 45, 0),
        ).phase,
        SessionWindowPhase.closed,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.morning,
          DateTime(2026, 11, 10, 12, 30, 0),
        ),
        isFalse,
      );
    });

    test('Afternoon window is strictly open from 12:20 PM to 12:50 PM IST', () {
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 8, 30, 0),
        ),
        isFalse,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 19, 59),
        ),
        isFalse,
      );
      expect(
        AttendanceWindowHelper.getWindowStatus(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 19, 59),
        ).phase,
        SessionWindowPhase.upcoming,
      );

      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 20, 0),
        ),
        isTrue,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 35, 0),
        ),
        isTrue,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 49, 59),
        ),
        isTrue,
      );

      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 50, 0),
        ),
        isFalse,
      );
      expect(
        AttendanceWindowHelper.getWindowStatus(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 12, 50, 0),
        ).phase,
        SessionWindowPhase.closed,
      );
      expect(
        AttendanceWindowHelper.isSessionOpen(
          SessionType.afternoon,
          DateTime(2026, 11, 10, 22, 52, 0),
        ),
        isFalse,
      );
    });
  });
}

