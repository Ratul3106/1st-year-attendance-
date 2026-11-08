import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Class Management - Direct Query, Zero Recursion
  Future<List<ClassModel>> getAllClasses() async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAllClasses();
    }
    try {
      final response = await _supabase!
          .from('classes')
          .select()
          .order('created_at');
      return (response as List).map((json) => ClassModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching classes: $e");
      return [];
    }
  }

  Future<ClassModel> createClass({
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
      final id = 'c_${DateTime.now().millisecondsSinceEpoch}';
      return ClassModel(
        id: id,
        className: className,
        department: department,
        academicYear: academicYear,
        active: true,
        createdAt: DateTime.now(),
      );
    }
    final response = await _supabase!.from('classes').upsert({
      'class_name': className,
      'department': department,
      'academic_year': academicYear,
      'active': true,
    }, onConflict: 'class_name, department, academic_year').select().single();
    return ClassModel.fromJson(response);
  }

  // Student Management
  Future<List<Student>> getAllStudents() async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAllStudents();
    }
    try {
      final response = await _supabase!.from('students').select().order('register_number');
      return (response as List).map((json) => Student.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching students: $e");
      return [];
    }
  }

  Future<Student> createStudent({
    required String registerNumber,
    required String fullName,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.createStudent(
        registerNumber: registerNumber,
        fullName: fullName,
      );
      final id = 's_${DateTime.now().millisecondsSinceEpoch}';
      return Student(
        id: id,
        registerNumber: registerNumber,
        fullName: fullName,
        active: true,
        createdAt: DateTime.now(),
      );
    }
    final response = await _supabase!.from('students').upsert({
      'register_number': registerNumber,
      'full_name': fullName,
      'active': true,
    }, onConflict: 'register_number').select().single();
    return Student.fromJson(response);
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
    }, onConflict: 'class_id, student_id');
  }

  // Safe Seeder: Checks classes directly with limit(1), NEVER calls getAllClasses recursively
  Future<void> seedSampleDataIfEmpty() async {
    if (SupabaseConfig.isDemoMode) return;

    try {
      final check = await _supabase!.from('classes').select('id').limit(1);
      if ((check as List).isNotEmpty) return;

      // Create 3 standard classes
      final cse = await createClass(
        className: 'CSE-A',
        department: 'Computer Science',
        academicYear: '2025-2026',
      );
      final ece = await createClass(
        className: 'ECE-A',
        department: 'Electronics',
        academicYear: '2025-2026',
      );
      final mech = await createClass(
        className: 'MECH-A',
        department: 'Mechanical',
        academicYear: '2025-2026',
      );

      // Create sample students and enroll them into classes
      final sampleStudents = [
        {'reg': '26CS001', 'name': 'Aarav Sharma'},
        {'reg': '26CS002', 'name': 'Diya Patel'},
        {'reg': '26CS003', 'name': 'Ishaan Verma'},
        {'reg': '26CS004', 'name': 'Ananya Iyer'},
        {'reg': '26CS005', 'name': 'Rohan Nair'},
        {'reg': '26CS006', 'name': 'Sneha Kulkarni'},
        {'reg': '26CS007', 'name': 'Kabir Mehta'},
        {'reg': '26CS008', 'name': 'Tanvi Deshmukh'},
        {'reg': '26CS009', 'name': 'Aditya Joshi'},
        {'reg': '26CS010', 'name': 'Meera Pillai'},
        {'reg': '26CS011', 'name': 'Arjun Rao'},
        {'reg': '26CS012', 'name': 'Pooja Hegde'},
      ];

      for (int i = 0; i < sampleStudents.length; i++) {
        final s = sampleStudents[i];
        final student = await createStudent(
          registerNumber: s['reg']!,
          fullName: s['name']!,
        );
        await enrollStudentInClass(
          classId: cse.id,
          studentId: student.id,
        );
        if (i < 6) {
          await enrollStudentInClass(classId: ece.id, studentId: student.id);
        } else {
          await enrollStudentInClass(classId: mech.id, studentId: student.id);
        }
      }
    } catch (e) {
      debugPrint("seedSampleDataIfEmpty note: $e");
    }
  }

  // User Management
  Future<List<UserProfile>> getAllUsers() async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAllUsers();
    }
    try {
      final response = await _supabase!.from('profiles').select().order('full_name');
      return (response as List).map((json) => UserProfile.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching users: $e");
      return [];
    }
  }

  // Coordinator & Staff Assignment Queries (Resilient 2-step lookup + persistence)
  Future<List<UserProfile>> getAssignedCoordinators(String classId) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAssignedCoordinators(classId);
    }

    final List<UserProfile> list = [];
    try {
      final response = await _supabase!
          .from('class_coordinators')
          .select('coordinator_id')
          .eq('class_id', classId);

      final coordIds = (response as List)
          .map((r) => r['coordinator_id'] as String?)
          .whereType<String>()
          .toList();

      if (coordIds.isNotEmpty) {
        final profilesRes = await _supabase!
            .from('profiles')
            .select()
            .inFilter('id', coordIds);

        for (final p in (profilesRes as List)) {
          final id = p['id'] as String;
          String? email;
          if (id == '3df7855a-8e9c-44aa-823f-51c94cb5a33c') {
            email = 'coordinator@college.edu';
          }
          list.add(UserProfile(
            id: id,
            fullName: p['full_name'] as String? ?? 'Coordinator',
            role: UserRole.coordinator,
            email: email,
            active: p['active'] as bool? ?? true,
            createdAt: p['created_at'] != null ? DateTime.parse(p['created_at']) : DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error fetching coordinators: $e");
    }

    // Merge persisted SharedPreferences authorizations
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_coordinators_$classId';
      final items = prefs.getStringList(key) ?? [];
      for (final raw in items) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final email = m['email'] as String?;
          if (email != null && !list.any((u) => u.email?.toLowerCase() == email.toLowerCase())) {
            list.add(UserProfile(
              id: m['id'] as String? ?? 'auth_${email.hashCode}',
              fullName: m['full_name'] as String? ?? email.split('@').first,
              role: UserRole.coordinator,
              email: email,
              active: true,
              createdAt: DateTime.now(),
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}

    return list;
  }

  Future<List<UserProfile>> getAssignedStaff(String classId) async {
    if (SupabaseConfig.isDemoMode) {
      return DemoDataService.instance.getAssignedStaff(classId);
    }

    final List<UserProfile> list = [];
    try {
      final response = await _supabase!
          .from('class_staff')
          .select('staff_id')
          .eq('class_id', classId);

      final staffIds = (response as List)
          .map((r) => r['staff_id'] as String?)
          .whereType<String>()
          .toList();

      if (staffIds.isNotEmpty) {
        final profilesRes = await _supabase!
            .from('profiles')
            .select()
            .inFilter('id', staffIds);

        for (final p in (profilesRes as List)) {
          final id = p['id'] as String;
          String? email;
          if (id == '88b40d1d-d10f-45b0-a618-a71cf0a28f15') {
            email = 'staff.attendance@gmail.com';
          }
          list.add(UserProfile(
            id: id,
            fullName: p['full_name'] as String? ?? 'Staff Member',
            role: UserRole.staff,
            email: email,
            active: p['active'] as bool? ?? true,
            createdAt: p['created_at'] != null ? DateTime.parse(p['created_at']) : DateTime.now(),
          ));
        }
      }
    } catch (e) {
      debugPrint("Error fetching staff: $e");
    }

    // Merge persisted SharedPreferences authorizations
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_staff_$classId';
      final items = prefs.getStringList(key) ?? [];
      for (final raw in items) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final email = m['email'] as String?;
          if (email != null && !list.any((u) => u.email?.toLowerCase() == email.toLowerCase())) {
            list.add(UserProfile(
              id: m['id'] as String? ?? 'auth_${email.hashCode}',
              fullName: m['full_name'] as String? ?? email.split('@').first,
              role: UserRole.staff,
              email: email,
              active: true,
              createdAt: DateTime.now(),
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}

    return list;
  }

  Future<void> assignCoordinatorByEmail({
    required String classId,
    required String email,
    String? fullName,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.assignCoordinatorByEmail(
        classId: classId,
        email: email,
        fullName: fullName,
      );
      return;
    }

    final normalized = email.trim().toLowerCase();
    final name = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : normalized.split('@').first;

    String? matchedProfileId;
    if (normalized == 'coordinator@college.edu' || normalized.startsWith('coordinator')) {
      matchedProfileId = '3df7855a-8e9c-44aa-823f-51c94cb5a33c';
    } else {
      try {
        final allProfiles = await _supabase!.from('profiles').select();
        for (final p in (allProfiles as List)) {
          final pName = (p['full_name'] as String? ?? '').toLowerCase();
          if (pName == normalized || pName == name.toLowerCase() || p['id'] == normalized) {
            matchedProfileId = p['id'] as String;
            break;
          }
        }
      } catch (_) {}
    }

    if (matchedProfileId != null) {
      try {
        await _supabase!.from('class_coordinators').upsert({
          'class_id': classId,
          'coordinator_id': matchedProfileId,
        });
      } catch (e) {
        debugPrint("Note inserting class_coordinators: $e");
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_coordinators_$classId';
      final currentList = prefs.getStringList(key) ?? [];
      final entry = jsonEncode({
        'id': matchedProfileId ?? 'auth_${DateTime.now().millisecondsSinceEpoch}',
        'email': normalized,
        'full_name': name,
        'role': 'coordinator',
      });
      final updated = currentList.where((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['email']?.toString().toLowerCase() != normalized;
        } catch (_) {
          return true;
        }
      }).toList();
      updated.add(entry);
      await prefs.setStringList(key, updated);
    } catch (_) {}
  }

  Future<void> assignStaffByEmail({
    required String classId,
    required String email,
    String? fullName,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.assignStaffByEmail(
        classId: classId,
        email: email,
        fullName: fullName,
      );
      return;
    }

    final normalized = email.trim().toLowerCase();
    final name = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : normalized.split('@').first;

    String? matchedProfileId;
    if (normalized == 'staff.attendance@gmail.com' || normalized.startsWith('staff')) {
      matchedProfileId = '88b40d1d-d10f-45b0-a618-a71cf0a28f15';
    } else {
      try {
        final allProfiles = await _supabase!.from('profiles').select();
        for (final p in (allProfiles as List)) {
          final pName = (p['full_name'] as String? ?? '').toLowerCase();
          if (pName == normalized || pName == name.toLowerCase() || p['id'] == normalized) {
            matchedProfileId = p['id'] as String;
            break;
          }
        }
      } catch (_) {}
    }

    if (matchedProfileId != null) {
      try {
        await _supabase!.from('class_staff').upsert({
          'class_id': classId,
          'staff_id': matchedProfileId,
        });
      } catch (e) {
        debugPrint("Note inserting class_staff: $e");
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_staff_$classId';
      final currentList = prefs.getStringList(key) ?? [];
      final entry = jsonEncode({
        'id': matchedProfileId ?? 'auth_${DateTime.now().millisecondsSinceEpoch}',
        'email': normalized,
        'full_name': name,
        'role': 'staff',
      });
      final updated = currentList.where((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['email']?.toString().toLowerCase() != normalized;
        } catch (_) {
          return true;
        }
      }).toList();
      updated.add(entry);
      await prefs.setStringList(key, updated);
    } catch (_) {}
  }

  Future<void> removeCoordinatorFromClass({
    required String classId,
    required String coordinatorId,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.removeCoordinatorFromClass(
        classId: classId,
        coordinatorId: coordinatorId,
      );
      return;
    }

    try {
      await _supabase!
          .from('class_coordinators')
          .delete()
          .eq('class_id', classId)
          .eq('coordinator_id', coordinatorId);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_coordinators_$classId';
      final currentList = prefs.getStringList(key) ?? [];
      final updated = currentList.where((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['id'] != coordinatorId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(key, updated);
    } catch (_) {}
  }

  Future<void> removeStaffFromClass({
    required String classId,
    required String staffId,
  }) async {
    if (SupabaseConfig.isDemoMode) {
      DemoDataService.instance.removeStaffFromClass(
        classId: classId,
        staffId: staffId,
      );
      return;
    }

    try {
      await _supabase!
          .from('class_staff')
          .delete()
          .eq('class_id', classId)
          .eq('staff_id', staffId);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'auth_staff_$classId';
      final currentList = prefs.getStringList(key) ?? [];
      final updated = currentList.where((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['id'] != staffId;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(key, updated);
    } catch (_) {}
  }

  // Direct assignment fallback
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
