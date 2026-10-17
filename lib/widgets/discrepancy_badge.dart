import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';

class DiscrepancyBadge extends StatelessWidget {
  final String discrepancyType;

  const DiscrepancyBadge({
    super.key,
    required this.discrepancyType,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    if (discrepancyType.contains('Bunk')) {
      bg = AppColors.bunkLight;
      fg = AppColors.bunk;
    } else if (discrepancyType.contains('OD')) {
      bg = AppColors.odLight;
      fg = AppColors.od;
    } else if (discrepancyType.contains('Incomplete')) {
      bg = AppColors.absentLight;
      fg = AppColors.absent;
    } else if (discrepancyType.contains('Morning Present')) {
      bg = AppColors.warningLight;
      fg = AppColors.warning;
    } else {
      bg = AppColors.infoLight;
      fg = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        discrepancyType,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
