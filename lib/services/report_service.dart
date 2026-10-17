import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/models/daily_report.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';

class ReportService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Fetch daily report for a specific class and date
  Future<DailyReport?> getDailyReport({
    required String classId,
    required String date,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getDailyReport(classId, date);
    }

    final response = await _supabase!
        .from('daily_reports')
        .select()
        .eq('class_id', classId)
        .eq('attendance_date', date)
        .maybeSingle();

    if (response == null) return null;
    return DailyReport.fromJson(response);
  }

  // Fetch report by ID
  Future<DailyReport?> getReportById(String reportId) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getReportById(reportId);
    }

    final response = await _supabase!
        .from('daily_reports')
        .select()
        .eq('id', reportId)
        .maybeSingle();

    if (response == null) return null;
    return DailyReport.fromJson(response);
  }

  // Fetch reports list for staff/admin
  Future<List<DailyReport>> getDailyReportsForDate(String date) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getDailyReportsForDate(date);
    }

    final response = await _supabase!
        .from('daily_reports')
        .select()
        .eq('attendance_date', date)
        .order('generated_at', ascending: false);

    return (response as List)
        .map((json) => DailyReport.fromJson(json))
        .toList();
  }
}

