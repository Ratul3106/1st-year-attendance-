import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_attendance_system/core/config/supabase_config.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/utils/file_download_helper.dart';

class NoAttendanceDataException implements Exception {
  final String message;
  NoAttendanceDataException(this.message);

  @override
  String toString() => message;
}

class AttendanceReportConfig {
  final ClassModel? selectedClass; // null = All Classes
  final DateTime startDate;
  final DateTime endDate;
  final String sessionFilter; // 'Both', 'Morning', 'Afternoon'
  final String format; // 'pdf' or 'excel'

  AttendanceReportConfig({
    this.selectedClass,
    required this.startDate,
    required this.endDate,
    required this.sessionFilter,
    required this.format,
  });

  String get classNameDisplay =>
      selectedClass != null ? selectedClass!.className : 'All Classes';
}

class StudentReportItem {
  final int sNo;
  final String registerNumber;
  final String studentName;
  final String className;
  final String department;
  final String date;
  final String session; // 'Morning' or 'Afternoon'
  final AttendanceStatus? status; // null = Unmarked
  final DateTime? markedAt;

  StudentReportItem({
    required this.sNo,
    required this.registerNumber,
    required this.studentName,
    required this.className,
    required this.department,
    required this.date,
    required this.session,
    this.status,
    this.markedAt,
  });

  String get statusDisplay {
    if (status == null) return 'Unmarked';
    return status!.displayName;
  }
}

class AttendanceReportAnalytics {
  final int totalEnrolledStudents;
  final int totalMarkedEntries;
  final int totalPresent;
  final int totalAbsent;
  final int totalOd;
  final int totalBunk;
  final int totalUnmarked;
  final double overallPercentage;
  final String percentageFormula;

  // Morning Breakdown
  final int morningPresent;
  final int morningAbsent;
  final int morningOd;
  final int morningUnmarked;
  final double morningPercentage;

  // Afternoon Breakdown
  final int afternoonPresent;
  final int afternoonAbsent;
  final int afternoonOd;
  final int afternoonBunk;
  final int afternoonUnmarked;
  final double afternoonPercentage;

  // Comparison Shifts (Same Date)
  final int presentBothSessions;
  final int presentMorningAbsentAfternoon;
  final int absentBothSessions;

  AttendanceReportAnalytics({
    required this.totalEnrolledStudents,
    required this.totalMarkedEntries,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalOd,
    required this.totalBunk,
    required this.totalUnmarked,
    required this.overallPercentage,
    required this.percentageFormula,
    required this.morningPresent,
    required this.morningAbsent,
    required this.morningOd,
    required this.morningUnmarked,
    required this.morningPercentage,
    required this.afternoonPresent,
    required this.afternoonAbsent,
    required this.afternoonOd,
    required this.afternoonBunk,
    required this.afternoonUnmarked,
    required this.afternoonPercentage,
    required this.presentBothSessions,
    required this.presentMorningAbsentAfternoon,
    required this.absentBothSessions,
  });
}

class AttendanceReportData {
  final AttendanceReportConfig config;
  final DateTime generatedAt;
  final AttendanceReportAnalytics analytics;
  final List<StudentReportItem> allItems;
  final List<StudentReportItem> presentList;
  final List<StudentReportItem> absentList;
  final List<StudentReportItem> odList;
  final List<StudentReportItem> bunkList;
  final List<StudentReportItem> unmarkedList;

  AttendanceReportData({
    required this.config,
    required this.generatedAt,
    required this.analytics,
    required this.allItems,
    required this.presentList,
    required this.absentList,
    required this.odList,
    required this.bunkList,
    required this.unmarkedList,
  });
}

class AttendanceReportGeneratorService {
  final _adminService = AdminService();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetches real saved attendance records from Supabase and compiles analytics & categorized student lists
  Future<AttendanceReportData> fetchReportData(
      AttendanceReportConfig config) async {
    final startDateStr = DateFormat('yyyy-MM-dd').format(config.startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(config.endDate);

    List<ClassModel> targetClasses = [];
    if (config.selectedClass != null) {
      targetClasses = [config.selectedClass!];
    } else {
      targetClasses = await _adminService.getAllClasses();
    }

    if (targetClasses.isEmpty) {
      throw NoAttendanceDataException(
          "No active classes found to generate attendance report.");
    }

    final targetClassIds = targetClasses.map((c) => c.id).toList();
    final classMap = {for (var c in targetClasses) c.id: c};

    // 1. Fetch enrolled students per class
    final Map<String, List<Student>> classEnrolledStudents = {};
    final Set<String> distinctEnrolledStudentIds = {};

    if (SupabaseConfig.isDemoMode) {
      final demo = DemoDataService.instance;
      for (var c in targetClasses) {
        final students = demo.getEnrolledStudents(c.id);
        classEnrolledStudents[c.id] = students;
        distinctEnrolledStudentIds.addAll(students.map((s) => s.id));
      }
    } else {
      if (_supabase == null) {
        throw Exception("Database client connection is not initialized.");
      }

      // Query enrollments
      final enrollments = await _supabase!
          .from('class_enrollments')
          .select('class_id, student_id')
          .inFilter('class_id', targetClassIds);

      final studentIds = (enrollments as List)
          .map((e) => e['student_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final Map<String, Student> studentLookup = {};
      if (studentIds.isNotEmpty) {
        final studentsRes = await _supabase!
            .from('students')
            .select()
            .inFilter('id', studentIds)
            .eq('active', true);

        for (var row in (studentsRes as List)) {
          final s = Student.fromJson(row as Map<String, dynamic>);
          studentLookup[s.id] = s;
        }
      }

      for (var row in (enrollments as List)) {
        final cId = row['class_id'] as String;
        final sId = row['student_id'] as String;
        final student = studentLookup[sId];
        if (student != null) {
          classEnrolledStudents.putIfAbsent(cId, () => []).add(student);
          distinctEnrolledStudentIds.add(sId);
        }
      }
    }

    // 2. Fetch Sessions across the Date Range
    final List<Map<String, dynamic>> sessionsList = [];
    final List<String> sessionIds = [];

    if (SupabaseConfig.isDemoMode) {
      final demo = DemoDataService.instance;
      // Loop over dates
      DateTime current = config.startDate;
      while (!current.isAfter(config.endDate)) {
        final dStr = DateFormat('yyyy-MM-dd').format(current);
        for (var c in targetClasses) {
          if (config.sessionFilter == 'Both' ||
              config.sessionFilter == 'Morning') {
            final m = demo.getSession(c.id, dStr, SessionType.morning);
            if (m != null) {
              sessionsList.add({
                'id': m.id,
                'class_id': c.id,
                'attendance_date': dStr,
                'session_type': 'morning',
              });
              sessionIds.add(m.id);
            }
          }
          if (config.sessionFilter == 'Both' ||
              config.sessionFilter == 'Afternoon') {
            final a = demo.getSession(c.id, dStr, SessionType.afternoon);
            if (a != null) {
              sessionsList.add({
                'id': a.id,
                'class_id': c.id,
                'attendance_date': dStr,
                'session_type': 'afternoon',
              });
              sessionIds.add(a.id);
            }
          }
        }
        current = current.add(const Duration(days: 1));
      }
    } else {
      var query = _supabase!
          .from('attendance_sessions')
          .select('id, class_id, attendance_date, session_type, status')
          .inFilter('class_id', targetClassIds)
          .gte('attendance_date', startDateStr)
          .lte('attendance_date', endDateStr);

      if (config.sessionFilter == 'Morning') {
        query = query.eq('session_type', 'morning');
      } else if (config.sessionFilter == 'Afternoon') {
        query = query.eq('session_type', 'afternoon');
      }

      final res = await query;
      for (var row in (res as List)) {
        sessionsList.add(row as Map<String, dynamic>);
        sessionIds.add(row['id'] as String);
      }
    }

    if (sessionsList.isEmpty) {
      throw NoAttendanceDataException(
        "No attendance sessions found for ${config.classNameDisplay} between $startDateStr and $endDateStr (${config.sessionFilter} Session). Please verify that attendance has been marked.",
      );
    }

    // 3. Fetch Attendance Records for these Sessions
    final Map<String, List<AttendanceRecord>> sessionRecordsMap = {};
    if (SupabaseConfig.isDemoMode) {
      final demo = DemoDataService.instance;
      for (var sId in sessionIds) {
        final recs = demo.getSessionRecords(sId);
        sessionRecordsMap[sId] = recs;
      }
    } else {
      if (sessionIds.isNotEmpty) {
        final recordsRes = await _supabase!
            .from('attendance_records')
            .select()
            .inFilter('session_id', sessionIds);

        for (var row in (recordsRes as List)) {
          final rec = AttendanceRecord.fromJson(row as Map<String, dynamic>);
          sessionRecordsMap.putIfAbsent(rec.sessionId, () => []).add(rec);
        }
      }
    }

    // Check if any actual records exist
    int totalSavedRecordsCount = 0;
    for (var list in sessionRecordsMap.values) {
      totalSavedRecordsCount += list.length;
    }

    if (totalSavedRecordsCount == 0) {
      throw NoAttendanceDataException(
        "Attendance sessions exist, but no saved student attendance records were found for $startDateStr to $endDateStr. Unsaved changes or empty sessions cannot generate reports.",
      );
    }

    // 4. Categorize Students and Compile Items
    final List<StudentReportItem> allItems = [];
    final List<StudentReportItem> presentList = [];
    final List<StudentReportItem> absentList = [];
    final List<StudentReportItem> odList = [];
    final List<StudentReportItem> bunkList = [];
    final List<StudentReportItem> unmarkedList = [];

    int mP = 0, mA = 0, mOd = 0, mUnmarked = 0;
    int aP = 0, aA = 0, aOd = 0, aBunk = 0, aUnmarked = 0;

    // Track for Multi-Session Shifts per (studentId, date)
    final Map<String, AttendanceStatus?> morningDayRecord = {};
    final Map<String, AttendanceStatus?> afternoonDayRecord = {};

    for (var session in sessionsList) {
      final sId = session['id'] as String;
      final cId = session['class_id'] as String;
      final dateStr = session['attendance_date'] as String;
      final sessionTypeStr = session['session_type'] as String; // 'morning' / 'afternoon'
      final isMorning = sessionTypeStr == 'morning';
      final sessionDisplayName = isMorning ? 'Morning' : 'Afternoon';

      final classObj = classMap[cId];
      final enrolledStudents = classEnrolledStudents[cId] ?? [];
      final records = sessionRecordsMap[sId] ?? [];
      final Map<String, AttendanceRecord> studentRecordMap = {
        for (var r in records) r.studentId: r
      };

      for (var student in enrolledStudents) {
        final rec = studentRecordMap[student.id];
        final AttendanceStatus? status = rec?.status;

        final item = StudentReportItem(
          sNo: 0, // Will be set after sorting
          registerNumber: student.registerNumber,
          studentName: student.fullName,
          className: classObj?.className ?? 'Unknown',
          department: classObj?.department ?? '',
          date: dateStr,
          session: sessionDisplayName,
          status: status,
          markedAt: rec?.markedAt,
        );

        allItems.add(item);

        // Update day-level comparison tracker
        final dayKey = "${student.id}_$dateStr";
        if (isMorning) {
          morningDayRecord[dayKey] = status;
          if (status == AttendanceStatus.present) {
            mP++;
            presentList.add(item);
          } else if (status == AttendanceStatus.absent) {
            mA++;
            absentList.add(item);
          } else if (status == AttendanceStatus.od) {
            mOd++;
            odList.add(item);
          } else {
            mUnmarked++;
            unmarkedList.add(item);
          }
        } else {
          afternoonDayRecord[dayKey] = status;
          if (status == AttendanceStatus.present) {
            aP++;
            presentList.add(item);
          } else if (status == AttendanceStatus.absent) {
            aA++;
            absentList.add(item);
          } else if (status == AttendanceStatus.od) {
            aOd++;
            odList.add(item);
          } else if (status == AttendanceStatus.bunk) {
            aBunk++;
            bunkList.add(item);
          } else {
            aUnmarked++;
            unmarkedList.add(item);
          }
        }
      }
    }

    // Sort all categorized lists by register number (or student name)
    int compareItems(StudentReportItem a, StudentReportItem b) {
      final regComp = a.registerNumber.compareTo(b.registerNumber);
      if (regComp != 0) return regComp;
      final dateComp = a.date.compareTo(b.date);
      if (dateComp != 0) return dateComp;
      return a.session.compareTo(b.session);
    }

    allItems.sort(compareItems);
    presentList.sort(compareItems);
    absentList.sort(compareItems);
    odList.sort(compareItems);
    bunkList.sort(compareItems);
    unmarkedList.sort(compareItems);

    // Re-index S.No
    List<StudentReportItem> reindex(List<StudentReportItem> list) {
      return list.asMap().entries.map((entry) {
        final item = entry.value;
        return StudentReportItem(
          sNo: entry.key + 1,
          registerNumber: item.registerNumber,
          studentName: item.studentName,
          className: item.className,
          department: item.department,
          date: item.date,
          session: item.session,
          status: item.status,
          markedAt: item.markedAt,
        );
      }).toList();
    }

    final indexedPresent = reindex(presentList);
    final indexedAbsent = reindex(absentList);
    final indexedOd = reindex(odList);
    final indexedBunk = reindex(bunkList);
    final indexedUnmarked = reindex(unmarkedList);
    final indexedAll = reindex(allItems);

    // Calculate Multi-Session Comparative Metrics
    int presentBoth = 0;
    int presentMornAbsAft = 0;
    int absentBoth = 0;

    final allDayKeys = {...morningDayRecord.keys, ...afternoonDayRecord.keys};
    for (var key in allDayKeys) {
      final m = morningDayRecord[key];
      final a = afternoonDayRecord[key];
      if (m == AttendanceStatus.present && a == AttendanceStatus.present) {
        presentBoth++;
      }
      if (m == AttendanceStatus.present && a == AttendanceStatus.absent) {
        presentMornAbsAft++;
      }
      if (m == AttendanceStatus.absent && a == AttendanceStatus.absent) {
        absentBoth++;
      }
    }

    // Totals across selected scope
    final totalPresent = indexedPresent.length;
    final totalAbsent = indexedAbsent.length;
    final totalOd = indexedOd.length;
    final totalBunk = indexedBunk.length;
    final totalUnmarked = indexedUnmarked.length;
    final totalMarked = totalPresent + totalAbsent + totalOd + totalBunk;

    // Percentages (Excluding Unmarked from denominator)
    final mMarked = mP + mA + mOd;
    final morningPercentage =
        mMarked > 0 ? ((mP + mOd) / mMarked) * 100.0 : 0.0;

    final aMarked = aP + aA + aOd + aBunk;
    final afternoonPercentage =
        aMarked > 0 ? ((aP + aOd) / aMarked) * 100.0 : 0.0;

    final overallPercentage =
        totalMarked > 0 ? ((totalPresent + totalOd) / totalMarked) * 100.0 : 0.0;

    final analytics = AttendanceReportAnalytics(
      totalEnrolledStudents: distinctEnrolledStudentIds.length,
      totalMarkedEntries: totalMarked,
      totalPresent: totalPresent,
      totalAbsent: totalAbsent,
      totalOd: totalOd,
      totalBunk: totalBunk,
      totalUnmarked: totalUnmarked,
      overallPercentage: overallPercentage,
      percentageFormula:
          "Attendance % = ((Present + OD) / Total Marked Records) * 100 [Unmarked students excluded]",
      morningPresent: mP,
      morningAbsent: mA,
      morningOd: mOd,
      morningUnmarked: mUnmarked,
      morningPercentage: morningPercentage,
      afternoonPresent: aP,
      afternoonAbsent: aA,
      afternoonOd: aOd,
      afternoonBunk: aBunk,
      afternoonUnmarked: aUnmarked,
      afternoonPercentage: afternoonPercentage,
      presentBothSessions: presentBoth,
      presentMorningAbsentAfternoon: presentMornAbsAft,
      absentBothSessions: absentBoth,
    );

    return AttendanceReportData(
      config: config,
      generatedAt: DateTime.now(),
      analytics: analytics,
      allItems: indexedAll,
      presentList: indexedPresent,
      absentList: indexedAbsent,
      odList: indexedOd,
      bunkList: indexedBunk,
      unmarkedList: indexedUnmarked,
    );
  }

  /// Generates a professional, multi-page PDF document
  Future<Uint8List> generatePdfReport(AttendanceReportData data) async {
    final pdf = pw.Document();
    final config = data.config;
    final a = data.analytics;

    final dateRangeStr =
        "${DateFormat('dd MMM yyyy').format(config.startDate)} to ${DateFormat('dd MMM yyyy').format(config.endDate)}";
    final genTimeStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(data.generatedAt);

    // Multi-page document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue800, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "STUDENT ATTENDANCE MANAGEMENT SYSTEM",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Official Academic Attendance & Analytics Report",
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Generated: $genTimeStr",
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    pw.Text("Scope: ${config.sessionFilter} Session(s)",
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Student Attendance System • Confidential & Academic Use Only",
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          pw.SizedBox(height: 12),

          // Metadata Info Box
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Class / Section:",
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    pw.Text(config.classNameDisplay,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Attendance Date Range:",
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    pw.Text(dateRangeStr,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Total Students Enrolled:",
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    pw.Text("${a.totalEnrolledStudents}",
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Overall Attendance Rate:",
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    pw.Text("${a.overallPercentage.toStringAsFixed(1)}%",
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // --- ANALYTICS SECTION ---
          pw.Text("ATTENDANCE ANALYTICS SUMMARY",
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900)),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: [
              "Metric Category",
              "Present",
              "Absent",
              "On Duty (OD)",
              "Bunked",
              "Unmarked",
              "Attendance %"
            ],
            data: [
              if (config.sessionFilter == 'Both' ||
                  config.sessionFilter == 'Morning')
                [
                  "Morning Session",
                  "${a.morningPresent}",
                  "${a.morningAbsent}",
                  "${a.morningOd}",
                  "N/A",
                  "${a.morningUnmarked}",
                  "${a.morningPercentage.toStringAsFixed(1)}%",
                ],
              if (config.sessionFilter == 'Both' ||
                  config.sessionFilter == 'Afternoon')
                [
                  "Afternoon Session",
                  "${a.afternoonPresent}",
                  "${a.afternoonAbsent}",
                  "${a.afternoonOd}",
                  "${a.afternoonBunk}",
                  "${a.afternoonUnmarked}",
                  "${a.afternoonPercentage.toStringAsFixed(1)}%",
                ],
              [
                "Consolidated Total",
                "${a.totalPresent}",
                "${a.totalAbsent}",
                "${a.totalOd}",
                config.sessionFilter == 'Morning' ? 'N/A' : "${a.totalBunk}",
                "${a.totalUnmarked}",
                "${a.overallPercentage.toStringAsFixed(1)}%",
              ],
            ],
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),

          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Formula: ${a.percentageFormula}",
                  style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic),
                ),
                if (config.sessionFilter == 'Both')
                  pw.Text(
                    "Multi-Session Shifts: Present Both: ${a.presentBothSessions} | Pres M. -> Abs A.: ${a.presentMorningAbsentAfternoon} | Absent Both: ${a.absentBothSessions}",
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800),
                  ),
              ],
            ),
          ),

          pw.SizedBox(height: 18),

          // --- CATEGORIZED STUDENT LISTS ---

          // A. PRESENT STUDENTS
          _buildPdfCategorySection(
            title: "A. PRESENT STUDENTS (${data.presentList.length})",
            items: data.presentList,
            headerColor: PdfColors.green800,
            emptyMessage: "No students recorded as Present in the selected scope.",
          ),

          pw.SizedBox(height: 14),

          // B. ABSENT STUDENTS
          _buildPdfCategorySection(
            title: "B. ABSENT STUDENTS (${data.absentList.length})",
            items: data.absentList,
            headerColor: PdfColors.red800,
            emptyMessage: "No students recorded as Absent in the selected scope.",
          ),

          pw.SizedBox(height: 14),

          // C. ON-DUTY (OD) STUDENTS
          _buildPdfCategorySection(
            title: "C. ON-DUTY (OD) STUDENTS (${data.odList.length})",
            items: data.odList,
            headerColor: PdfColors.orange800,
            emptyMessage: "No students recorded on On-Duty (OD) in the selected scope.",
          ),

          if (config.sessionFilter != 'Morning') ...[
            pw.SizedBox(height: 14),
            // D. BUNKED STUDENTS
            _buildPdfCategorySection(
              title: "D. BUNKED STUDENTS (${data.bunkList.length})",
              items: data.bunkList,
              headerColor: PdfColors.purple800,
              emptyMessage: "No students recorded as Bunked in the selected scope.",
            ),
          ],

          pw.SizedBox(height: 14),

          // E. UNMARKED STUDENTS
          _buildPdfCategorySection(
            title: "E. UNMARKED STUDENTS (${data.unmarkedList.length})",
            items: data.unmarkedList,
            headerColor: PdfColors.grey700,
            emptyMessage: "All enrolled students have their attendance marked for the sessions.",
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfCategorySection({
    required String title,
    required List<StudentReportItem> items,
    required PdfColor headerColor,
    required String emptyMessage,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: headerColor,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                "Total: ${items.length}",
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Text(
              emptyMessage,
              style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: [
              "S.No",
              "Register Number",
              "Student Name",
              "Class",
              "Date",
              "Session",
              "Status"
            ],
            data: items.map((item) {
              return [
                "${item.sNo}",
                item.registerNumber,
                item.studentName,
                item.className,
                item.date,
                item.session,
                item.statusDisplay,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),
      ],
    );
  }

  /// Generates a complete Excel workbook (.xlsx) with 7 distinct worksheets
  Future<Uint8List> generateExcelReport(AttendanceReportData data) async {
    final excel = Excel.createExcel();
    final config = data.config;
    final a = data.analytics;

    final dateRangeStr =
        "${DateFormat('yyyy-MM-dd').format(config.startDate)} to ${DateFormat('yyyy-MM-dd').format(config.endDate)}";
    final genTimeStr =
        DateFormat('yyyy-MM-dd HH:mm').format(data.generatedAt);

    // Sheet 1: Summary & Analytics
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([TextCellValue("STUDENT ATTENDANCE MANAGEMENT SYSTEM — REPORT SUMMARY")]);
    summarySheet.appendRow([TextCellValue("Generated At:"), TextCellValue(genTimeStr)]);
    summarySheet.appendRow([TextCellValue("Class:"), TextCellValue(config.classNameDisplay)]);
    summarySheet.appendRow([TextCellValue("Date Range:"), TextCellValue(dateRangeStr)]);
    summarySheet.appendRow([TextCellValue("Session Scope:"), TextCellValue(config.sessionFilter)]);
    summarySheet.appendRow([TextCellValue("")]);

    summarySheet.appendRow([
      TextCellValue("Metric"),
      TextCellValue("Value"),
      TextCellValue("Unit / Description"),
    ]);

    summarySheet.appendRow([TextCellValue("Total Enrolled Students"), IntCellValue(a.totalEnrolledStudents), TextCellValue("Distinct Students")]);
    summarySheet.appendRow([TextCellValue("Total Marked Records"), IntCellValue(a.totalMarkedEntries), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Total Present Count"), IntCellValue(a.totalPresent), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Total Absent Count"), IntCellValue(a.totalAbsent), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Total OD Count"), IntCellValue(a.totalOd), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Total Bunk Count"), IntCellValue(a.totalBunk), TextCellValue("Records (Afternoon)")]);
    summarySheet.appendRow([TextCellValue("Total Unmarked Count"), IntCellValue(a.totalUnmarked), TextCellValue("Students not recorded")]);
    summarySheet.appendRow([TextCellValue("Overall Attendance Rate"), DoubleCellValue(double.parse(a.overallPercentage.toStringAsFixed(1))), TextCellValue(a.percentageFormula)]);
    summarySheet.appendRow([TextCellValue("")]);

    summarySheet.appendRow([TextCellValue("--- SESSION BREAKDOWN ---")]);
    summarySheet.appendRow([TextCellValue("Morning Present"), IntCellValue(a.morningPresent), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Morning Absent"), IntCellValue(a.morningAbsent), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Morning OD"), IntCellValue(a.morningOd), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Morning Unmarked"), IntCellValue(a.morningUnmarked), TextCellValue("Students")]);
    summarySheet.appendRow([TextCellValue("Morning %"), DoubleCellValue(double.parse(a.morningPercentage.toStringAsFixed(1))), TextCellValue("%")]);
    summarySheet.appendRow([TextCellValue("")]);

    summarySheet.appendRow([TextCellValue("Afternoon Present"), IntCellValue(a.afternoonPresent), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Afternoon Absent"), IntCellValue(a.afternoonAbsent), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Afternoon OD"), IntCellValue(a.afternoonOd), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Afternoon Bunk"), IntCellValue(a.afternoonBunk), TextCellValue("Records")]);
    summarySheet.appendRow([TextCellValue("Afternoon Unmarked"), IntCellValue(a.afternoonUnmarked), TextCellValue("Students")]);
    summarySheet.appendRow([TextCellValue("Afternoon %"), DoubleCellValue(double.parse(a.afternoonPercentage.toStringAsFixed(1))), TextCellValue("%")]);
    summarySheet.appendRow([TextCellValue("")]);

    summarySheet.appendRow([TextCellValue("--- MULTI-SESSION SHIFTS ---")]);
    summarySheet.appendRow([TextCellValue("Present Both Sessions"), IntCellValue(a.presentBothSessions), TextCellValue("Students")]);
    summarySheet.appendRow([TextCellValue("Present Morning, Absent Afternoon"), IntCellValue(a.presentMorningAbsentAfternoon), TextCellValue("Students")]);
    summarySheet.appendRow([TextCellValue("Absent Both Sessions"), IntCellValue(a.absentBothSessions), TextCellValue("Students")]);

    // Helper for table sheets
    void populateStudentSheet(Sheet sheet, List<StudentReportItem> list, String categoryTitle) {
      sheet.appendRow([TextCellValue(categoryTitle), IntCellValue(list.length)]);
      sheet.appendRow([TextCellValue("")]);
      sheet.appendRow([
        TextCellValue("S.No"),
        TextCellValue("Register Number"),
        TextCellValue("Student Name"),
        TextCellValue("Class"),
        TextCellValue("Department"),
        TextCellValue("Date"),
        TextCellValue("Session"),
        TextCellValue("Status"),
      ]);

      for (var item in list) {
        sheet.appendRow([
          IntCellValue(item.sNo),
          TextCellValue(item.registerNumber),
          TextCellValue(item.studentName),
          TextCellValue(item.className),
          TextCellValue(item.department),
          TextCellValue(item.date),
          TextCellValue(item.session),
          TextCellValue(item.statusDisplay),
        ]);
      }
    }

    // Sheet 2: Present Students
    populateStudentSheet(excel['Present Students'], data.presentList, "PRESENT STUDENTS");

    // Sheet 3: Absent Students
    populateStudentSheet(excel['Absent Students'], data.absentList, "ABSENT STUDENTS");

    // Sheet 4: OD Students
    populateStudentSheet(excel['OD Students'], data.odList, "ON-DUTY (OD) STUDENTS");

    // Sheet 5: Bunked Students
    populateStudentSheet(excel['Bunked Students'], data.bunkList, "BUNKED STUDENTS");

    // Sheet 6: Unmarked Students
    populateStudentSheet(excel['Unmarked Students'], data.unmarkedList, "UNMARKED STUDENTS");

    // Sheet 7: Detailed Attendance (Master Table)
    final detailSheet = excel['Detailed Attendance'];
    detailSheet.appendRow([TextCellValue("DETAILED MASTER ATTENDANCE RECORDS")]);
    detailSheet.appendRow([TextCellValue("")]);
    detailSheet.appendRow([
      TextCellValue("S.No"),
      TextCellValue("Register Number"),
      TextCellValue("Student Name"),
      TextCellValue("Class"),
      TextCellValue("Department"),
      TextCellValue("Date"),
      TextCellValue("Session"),
      TextCellValue("Status"),
      TextCellValue("Marked At"),
    ]);

    for (var item in data.allItems) {
      detailSheet.appendRow([
        IntCellValue(item.sNo),
        TextCellValue(item.registerNumber),
        TextCellValue(item.studentName),
        TextCellValue(item.className),
        TextCellValue(item.department),
        TextCellValue(item.date),
        TextCellValue(item.session),
        TextCellValue(item.statusDisplay),
        TextCellValue(item.markedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(item.markedAt!) : 'N/A'),
      ]);
    }

    // Remove default 'Sheet1' if present
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  /// High-level function that fetches data, builds report, and downloads/shares file
  Future<String> downloadReport(AttendanceReportConfig config) async {
    final reportData = await fetchReportData(config);

    final cleanClassName = config.selectedClass != null
        ? config.selectedClass!.className.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        : 'AllClasses';

    final startStr = DateFormat('yyyy-MM-dd').format(config.startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(config.endDate);
    final dateSuffix = startStr == endStr ? startStr : "${startStr}_to_$endStr";

    final ext = config.format.toLowerCase() == 'excel' ? 'xlsx' : 'pdf';
    final mimeType = config.format.toLowerCase() == 'excel'
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';

    final filename = "Attendance_Report_${cleanClassName}_$dateSuffix.$ext";

    Uint8List bytes;
    if (config.format.toLowerCase() == 'excel') {
      bytes = await generateExcelReport(reportData);
    } else {
      bytes = await generatePdfReport(reportData);
    }

    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );

    return filename;
  }

  /// Exports an existing AttendanceReportData directly as a downloaded PDF or Excel file
  Future<String> exportReportDataAsFile(
      AttendanceReportData reportData, String format) async {
    final cleanClassName = reportData.config.selectedClass != null
        ? reportData.config.selectedClass!.className
            .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        : 'AllClasses';

    final startStr =
        DateFormat('yyyy-MM-dd').format(reportData.config.startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(reportData.config.endDate);
    final dateSuffix = startStr == endStr ? startStr : "${startStr}_to_$endStr";

    final ext = format.toLowerCase() == 'excel' ? 'xlsx' : 'pdf';
    final mimeType = format.toLowerCase() == 'excel'
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';

    final filename = "Attendance_Report_${cleanClassName}_$dateSuffix.$ext";

    Uint8List bytes;
    if (format.toLowerCase() == 'excel') {
      bytes = await generateExcelReport(reportData);
    } else {
      bytes = await generatePdfReport(reportData);
    }

    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );

    return filename;
  }
}
