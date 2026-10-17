import 'package:flutter/material.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';

class StudentAttendanceTile extends StatelessWidget {
  final Student student;
  final AttendanceStatus? status;
  final ValueChanged<AttendanceStatus> onStatusChanged;
  final List<AttendanceStatus> allowedStatuses;

  const StudentAttendanceTile({
    super.key,
    required this.student,
    required this.status,
    required this.onStatusChanged,
    this.allowedStatuses = const [
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.od,
    ],
  });

  Color _getStatusColor(AttendanceStatus st) {
    switch (st) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.od:
        return AppColors.od;
      case AttendanceStatus.bunk:
        return AppColors.bunk;
    }
  }

  Color _getStatusBgColor(AttendanceStatus st) {
    switch (st) {
      case AttendanceStatus.present:
        return AppColors.presentLight;
      case AttendanceStatus.absent:
        return AppColors.absentLight;
      case AttendanceStatus.od:
        return AppColors.odLight;
      case AttendanceStatus.bunk:
        return AppColors.bunkLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status != null
              ? _getStatusColor(status!).withValues(alpha: 0.3)
              : AppColors.border,
          width: status != null ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: status != null
                    ? _getStatusBgColor(status!)
                    : AppColors.primaryLight.withValues(alpha: 0.1),
                child: Text(
                  student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                  style: TextStyle(
                    color: status != null ? _getStatusColor(status!) : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (status == null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.unmarked,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Student Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      student.registerNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (status != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(status!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status!.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status!),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.unmarkedLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Unmarked",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.unmarked,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Segmented Status Action Buttons
          Wrap(
            spacing: 6,
            children: allowedStatuses.map((st) {
              final isSelected = status == st;
              final color = _getStatusColor(st);
              final isBunk = st == AttendanceStatus.bunk;

              return InkWell(
                onTap: () => onStatusChanged(st),
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: isBunk ? 10 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? color : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    st.shortCode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
