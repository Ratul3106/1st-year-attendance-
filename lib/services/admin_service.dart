import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/models/user_profile.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';

class AdminService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Class Management
  Future<List<ClassModel>> getAllClasses() async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAllClasses();
    }
    final response = await _supabase!.from('classes').select().order('created_at');
    return (response as List).map((json) => ClassModel.fromJson(json)).toList();
  }

  Future<void> createClass({
    required String className,
    required String department,
    required String academicYear,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.createClass(
        className: className,
        department: department,
        academicYear: academicYear,
      );
      return;
    }
    await _supabase!.from('classes').insert({
      'class_name': className,
      'department': department,
      'academic_year': academicYear,
      'active': true,
    });
  }

  // Student Management
  Future<List<Student>> getAllStudents() async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAllStudents();
    }
    final response = await _supabase!.from('students').select().order('register_number');
    return (response as List).map((json) => Student.fromJson(json)).toList();
  }

  Future<void> createStudent({
    required String registerNumber,
    required String fullName,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.createStudent(
        registerNumber: registerNumber,
        fullName: fullName,
      );
      return;
    }
    await _supabase!.from('students').insert({
      'register_number': registerNumber,
      'full_name': fullName,
      'active': true,
    });
  }

  Future<void> enrollStudentInClass({
    required String classId,
    required String studentId,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.enrollStudentInClass(
        classId: classId,
        studentId: studentId,
      );
      return;
    }
    await _supabase!.from('class_enrollments').upsert({
      'class_id': classId,
      'student_id': studentId,
    });
  }

  // User Management
  Future<List<UserProfile>> getAllUsers() async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAllUsers();
    }
    final response = await _supabase!.from('profiles').select().order('full_name');
    return (response as List).map((json) => UserProfile.fromJson(json)).toList();
  }

  // Assignment Management
  Future<void> assignCoordinatorToClass({
    required String classId,
    required String coordinatorId,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.assignCoordinatorToClass(
        classId: classId,
        coordinatorId: coordinatorId,
      );
      return;
    }
    await _supabase!.from('class_coordinators').upsert({
      'class_id': classId,
      'coordinator_id': coordinatorId,
    });
  }

  Future<void> assignStaffToClass({
    required String classId,
    required String staffId,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.assignStaffToClass(
        classId: classId,
        staffId: staffId,
      );
      return;
    }
    await _supabase!.from('class_staff').upsert({
      'class_id': classId,
      'staff_id': staffId,
    });
  }
}

