import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/services/admin_service.dart';
import 'package:student_attendance_system/services/demo_data_service.dart';
import 'package:student_attendance_system/services/attendance_comparison_service.dart';
import 'package:student_attendance_system/services/report_export_service.dart';
import 'package:student_attendance_system/widgets/custom_text_field.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _adminService = AdminService();

  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;
  List<Student> _classStudents = [];
  List<Student> _filteredStudents = [];
  bool _isLoading = true;

  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Present', 'Absent', 'OD', 'Bunk', 'Not Marked'
  bool _sortAscending = true;

  // Pagination
  int _currentPage = 1;
  final int _rowsPerPage = 6;

  // Cached records for current class and date: studentId -> record
  Map<String, AttendanceRecord?> _morningRecords = {};
  Map<String, AttendanceRecord?> _afternoonRecords = {};

  final _regNumController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final classes = await _adminService.getAllClasses();
    setState(() {
      _classes = classes;
      if (classes.isNotEmpty) {
        _selectedClass = classes.first;
      }
    });

    if (_selectedClass != null) {
      await _loadClassStudentsAndAttendance(_selectedClass!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClassStudentsAndAttendance(ClassModel cls) async {
    setState(() => _isLoading = true);
    final demo = DemoDataService.instance;
    final students = demo.getEnrolledStudents(cls.id);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final Map<String, AttendanceRecord?> mRecords = {};
    final Map<String, AttendanceRecord?> aRecords = {};

    for (var s in students) {
      final recMap = demo.getStudentRecordsForDate(
        classId: cls.id,
        date: dateStr,
        studentId: s.id,
      );
      mRecords[s.id] = recMap['morning'];
      aRecords[s.id] = recMap['afternoon'];
    }

    setState(() {
      _classStudents = students;
      _morningRecords = mRecords;
      _afternoonRecords = aRecords;
      _currentPage = 1;
      _isLoading = false;
    });

    _applyFilterAndSort();
  }

  void _applyFilterAndSort() {
    List<Student> list = List.from(_classStudents);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        return s.fullName.toLowerCase().contains(q) ||
            s.registerNumber.toLowerCase().contains(q);
      }).toList();
    }

    // Status filter
    if (_statusFilter != 'All') {
      list = list.where((s) {
        final m = _morningRecords[s.id];
        final a = _afternoonRecords[s.id];

        switch (_statusFilter) {
          case 'Present':
            return m?.status == AttendanceStatus.present || a?.status == AttendanceStatus.present;
          case 'Absent':
            return m?.status == AttendanceStatus.absent || a?.status == AttendanceStatus.absent;
          case 'OD':
            return m?.status == AttendanceStatus.od || a?.status == AttendanceStatus.od;
          case 'Bunk':
            return a?.status == AttendanceStatus.bunk;
          case 'Not Marked':
            return m == null || a == null;
          default:
            return true;
        }
      }).toList();
    }

    // Sorting by register number
    list.sort((a, b) => _sortAscending
        ? a.registerNumber.compareTo(b.registerNumber)
        : b.registerNumber.compareTo(a.registerNumber));

    setState(() {
      _filteredStudents = list;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      if (_selectedClass != null) {
        _loadClassStudentsAndAttendance(_selectedClass!);
      }
    }
  }

  // --- Overall Report Generation Modal ---
  void _openGenerateOverallReportModal() {
    DateTime reportStartDate = _selectedDate;
    DateTime reportEndDate = _selectedDate;
    List<ClassModel> targetClasses = List.from(_classes);
    String targetSession = 'Both';
    bool selectAllClasses = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assessment, color: AppColors.primary),
                SizedBox(width: 8),
                Text("Generate Overall Report"),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Configure Report Parameters",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    // Date Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Report Attendance Date:", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(
                                DateFormat('EEEE, dd MMM yyyy').format(reportStartDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.date_range, size: 16),
                            label: const Text("Change Date"),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: reportStartDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setModalState(() {
                                  reportStartDate = d;
                                  reportEndDate = d;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Session Selection
                    const Text("Session Filter", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['Both', 'Morning', 'Afternoon'].map((sess) {
                        final isSel = targetSession == sess;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(sess),
                              selected: isSel,
                              onSelected: (_) => setModalState(() => targetSession = sess),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Class Scope Selection
                    const Text("Authorized Class Scope", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 6),
                    RadioListTile<bool>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text("All Authorized Classes (${_classes.length})"),
                      value: true,
                      groupValue: selectAllClasses,
                      onChanged: (val) {
                        setModalState(() {
                          selectAllClasses = true;
                          targetClasses = List.from(_classes);
                        });
                      },
                    ),
                    RadioListTile<bool>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text("Active Selected Class (${_selectedClass?.className ?? 'Current'})"),
                      value: false,
                      groupValue: selectAllClasses,
                      onChanged: (val) {
                        setModalState(() {
                          selectAllClasses = false;
                          if (_selectedClass != null) {
                            targetClasses = [_selectedClass!];
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text("Generate Preview"),
                onPressed: () {
                  Navigator.pop(ctx);
                  _generateAndShowReportPreview(
                    OverallReportConfig(
                      startDate: reportStartDate,
                      endDate: reportEndDate,
                      selectedClasses: targetClasses,
                      sessionType: targetSession,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _generateAndShowReportPreview(OverallReportConfig config) {
    final demo = DemoDataService.instance;
    final dateStr = DateFormat('yyyy-MM-dd').format(config.startDate);

    final List<ClassSummaryReportItem> summaries = [];
    final List<StudentReportRow> studentRows = [];
    int sNo = 1;

    for (final cls in config.selectedClasses) {
      final students = demo.getEnrolledStudents(cls.id);
      int mP = 0, mA = 0, mOd = 0;
      int aP = 0, aA = 0, aOd = 0, aBunk = 0;
      int bothP = 0;

      for (final s in students) {
        final recs = demo.getStudentRecordsForDate(classId: cls.id, date: dateStr, studentId: s.id);
        final m = recs['morning']?.status;
        final a = recs['afternoon']?.status;

        if (m == AttendanceStatus.present) mP++;
        if (m == AttendanceStatus.absent) mA++;
        if (m == AttendanceStatus.od) mOd++;

        if (a == AttendanceStatus.present) aP++;
        if (a == AttendanceStatus.absent) aA++;
        if (a == AttendanceStatus.od) aOd++;
        if (a == AttendanceStatus.bunk) aBunk++;

        if (m == AttendanceStatus.present && a == AttendanceStatus.present) bothP++;

        final overall = AttendanceComparisonEngine.categorizeComparison(morning: m, afternoon: a);

        studentRows.add(StudentReportRow(
          sNo: sNo++,
          registerNumber: s.registerNumber,
          studentName: s.fullName,
          className: cls.className,
          department: cls.department,
          academicYear: cls.academicYear,
          morningStatus: m?.displayName ?? 'Not Marked',
          afternoonStatus: a?.displayName ?? 'Not Marked',
          overallStatus: overall,
        ));
      }

      final mMarked = mP + mA + mOd;
      final aMarked = aP + aA + aOd + aBunk;
      final mPct = mMarked > 0 ? (mP / mMarked) * 100.0 : 0.0;
      final aPct = aMarked > 0 ? (aP / aMarked) * 100.0 : 0.0;

      summaries.add(ClassSummaryReportItem(
        className: cls.className,
        department: cls.department,
        totalEnrolled: students.length,
        morningPresent: mP,
        morningAbsent: mA,
        morningOd: mOd,
        afternoonPresent: aP,
        afternoonAbsent: aA,
        afternoonOd: aOd,
        afternoonBunk: aBunk,
        bothPresent: bothP,
        morningPercentage: mPct,
        afternoonPercentage: aPct,
      ));
    }

    final reportResult = OverallReportResult(
      generatedAt: DateTime.now(),
      config: config,
      classSummaries: summaries,
      studentRows: studentRows,
    );

    _showReportPreviewDialog(reportResult);
  }

  void _showReportPreviewDialog(OverallReportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880, maxHeight: 680),
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.print, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "Overall Attendance Report — Preview",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Report Metadata Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: AppColors.background,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Date: ${DateFormat('dd MMM yyyy').format(result.config.startDate)} | Session: ${result.config.sessionType}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        "Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(result.generatedAt)}",
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                const TabBar(
                  labelColor: AppColors.primary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: "Class-Wise Summary"),
                    Tab(text: "Student-Wise Detailed Attendance"),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Class Summary Table
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("Class")),
                            DataColumn(label: Text("Dept")),
                            DataColumn(label: Text("Enrolled")),
                            DataColumn(label: Text("M. Pres")),
                            DataColumn(label: Text("M. Abs")),
                            DataColumn(label: Text("M. OD")),
                            DataColumn(label: Text("M. %")),
                            DataColumn(label: Text("A. Pres")),
                            DataColumn(label: Text("A. Abs")),
                            DataColumn(label: Text("A. OD")),
                            DataColumn(label: Text("A. Bunk")),
                            DataColumn(label: Text("A. %")),
                            DataColumn(label: Text("Both Pres")),
                          ],
                          rows: result.classSummaries.map((s) {
                            return DataRow(cells: [
                              DataCell(Text(s.className, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(s.department)),
                              DataCell(Text("${s.totalEnrolled}")),
                              DataCell(Text("${s.morningPresent}", style: const TextStyle(color: AppColors.present))),
                              DataCell(Text("${s.morningAbsent}", style: const TextStyle(color: AppColors.absent))),
                              DataCell(Text("${s.morningOd}", style: const TextStyle(color: AppColors.od))),
                              DataCell(Text("${s.morningPercentage.toStringAsFixed(1)}%")),
                              DataCell(Text("${s.afternoonPresent}", style: const TextStyle(color: AppColors.present))),
                              DataCell(Text("${s.afternoonAbsent}", style: const TextStyle(color: AppColors.absent))),
                              DataCell(Text("${s.afternoonOd}", style: const TextStyle(color: AppColors.od))),
                              DataCell(Text("${s.afternoonBunk}", style: const TextStyle(color: AppColors.bunk))),
                              DataCell(Text("${s.afternoonPercentage.toStringAsFixed(1)}%")),
                              DataCell(Text("${s.bothPresent}", style: const TextStyle(fontWeight: FontWeight.bold))),
                            ]);
                          }).toList(),
                        ),
                      ),

                      // Tab 2: Detailed Student Attendance Table
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text("S.No")),
                              DataColumn(label: Text("Reg No")),
                              DataColumn(label: Text("Student Name")),
                              DataColumn(label: Text("Class")),
                              DataColumn(label: Text("Morning Status")),
                              DataColumn(label: Text("Afternoon Status")),
                              DataColumn(label: Text("Overall Daily Status")),
                            ],
                            rows: result.studentRows.map((r) {
                              return DataRow(cells: [
                                DataCell(Text("${r.sNo}")),
                                DataCell(Text(r.registerNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(r.studentName)),
                                DataCell(Text(r.className)),
                                DataCell(_statusBadge(r.morningStatus)),
                                DataCell(_statusBadge(r.afternoonStatus)),
                                DataCell(Text(r.overallStatus, style: const TextStyle(fontSize: 12))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Export Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text("Download CSV"),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          final csv = result.generateCsv();
                          Clipboard.setData(ClipboardData(text: csv));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("CSV report copied to clipboard! Ready to save to file."),
                              backgroundColor: AppColors.present,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text("Print Report"),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Preparing printer-friendly report preview...")),
                          );
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Close"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _statusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'present':
        bg = AppColors.presentLight;
        fg = AppColors.present;
        break;
      case 'absent':
        bg = AppColors.absentLight;
        fg = AppColors.absent;
        break;
      case 'od':
        bg = AppColors.odLight;
        fg = AppColors.od;
        break;
      case 'bunk':
        bg = AppColors.bunkLight;
        fg = AppColors.bunk;
        break;
      default:
        bg = AppColors.unmarkedLight;
        fg = AppColors.unmarked;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: _regNumController,
              label: "Register Number",
              hint: "26CS013",
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _nameController,
              label: "Full Name",
              hint: "Vikram Sengupta",
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_regNumController.text.isNotEmpty && _nameController.text.isNotEmpty) {
                await _adminService.createStudent(
                  registerNumber: _regNumController.text.trim(),
                  fullName: _nameController.text.trim(),
                );
                _regNumController.clear();
                _nameController.clear();
                if (mounted) Navigator.pop(ctx);
                if (_selectedClass != null) {
                  _loadClassStudentsAndAttendance(_selectedClass!);
                }
              }
            },
            child: const Text("Save Student"),
          ),
        ],
      ),
    );
  }

  void _showEnrollDialog(Student student) {
    if (_classes.isEmpty) return;
    ClassModel selected = _classes.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Enroll ${student.fullName}"),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButton<ClassModel>(
              value: selected,
              isExpanded: true,
              items: _classes.map((cls) {
                return DropdownMenuItem(value: cls, child: Text(cls.displayName));
              }).toList(),
              onChanged: (val) {
                if (val != null) setModalState(() => selected = val);
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _adminService.enrollStudentInClass(
                classId: selected.id,
                studentId: student.id,
              );
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${student.fullName} enrolled in ${selected.className}")),
              );
              if (_selectedClass != null) {
                _loadClassStudentsAndAttendance(_selectedClass!);
              }
            },
            child: const Text("Enroll"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalFiltered = _filteredStudents.length;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage > totalFiltered) ? totalFiltered : startIndex + _rowsPerPage;
    final pagedStudents = (_filteredStudents.isNotEmpty && startIndex < totalFiltered)
        ? _filteredStudents.sublist(startIndex, endIndex)
        : <Student>[];
    final totalPages = (totalFiltered / _rowsPerPage).ceil().clamp(1, 999);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Class-Wise Student Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: "Add Student",
            onPressed: _showAddStudentDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Class Selection Filter Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.class_outlined, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              "Class & Session Selector",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            // Prominent Generate Overall Report Button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.description_outlined, size: 16),
                              label: const Text("Generate Overall Report"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: _openGenerateOverallReportModal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Class Dropdown and Date Picker Row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<ClassModel>(
                                value: _selectedClass,
                                decoration: const InputDecoration(
                                  labelText: "Selected Class",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                isExpanded: true,
                                items: _classes.map((cls) {
                                  return DropdownMenuItem(
                                    value: cls,
                                    child: Text(cls.displayName, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (newCls) {
                                  if (newCls != null) {
                                    setState(() => _selectedClass = newCls);
                                    _loadClassStudentsAndAttendance(newCls);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: "Attendance Date",
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM yyyy').format(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search & Filter Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "Search student name or register number...",
                              prefixIcon: Icon(Icons.search, size: 20),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (v) {
                              _searchQuery = v;
                              _applyFilterAndSort();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Status Filter Dropdown
                        DropdownButton<String>(
                          value: _statusFilter,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text("All Statuses")),
                            DropdownMenuItem(value: 'Present', child: Text("Present")),
                            DropdownMenuItem(value: 'Absent', child: Text("Absent")),
                            DropdownMenuItem(value: 'OD', child: Text("OD")),
                            DropdownMenuItem(value: 'Bunk', child: Text("Bunk")),
                            DropdownMenuItem(value: 'Not Marked', child: Text("Not Marked")),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _statusFilter = v);
                              _applyFilterAndSort();
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(_sortAscending ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
                          tooltip: "Sort Reg No",
                          onPressed: () {
                            setState(() => _sortAscending = !_sortAscending);
                            _applyFilterAndSort();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Student Enrolled Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.background),
                            columns: const [
                              DataColumn(label: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Reg No", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Morning Status", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Afternoon Status", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Overall Daily Status", style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: pagedStudents.asMap().entries.map((entry) {
                              final index = startIndex + entry.key + 1;
                              final student = entry.value;
                              final mRec = _morningRecords[student.id];
                              final aRec = _afternoonRecords[student.id];
                              final mStatusStr = mRec?.status.displayName ?? 'Not Marked';
                              final aStatusStr = aRec?.status.displayName ?? 'Not Marked';
                              final overall = AttendanceComparisonEngine.categorizeComparison(
                                morning: mRec?.status,
                                afternoon: aRec?.status,
                              );

                              return DataRow(
                                cells: [
                                  DataCell(Text("$index")),
                                  DataCell(Text(student.registerNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(student.fullName)),
                                  DataCell(Text(_selectedClass?.department ?? 'CSE')),
                                  DataCell(_statusBadge(mStatusStr)),
                                  DataCell(_statusBadge(aStatusStr)),
                                  DataCell(Text(overall, style: const TextStyle(fontSize: 12))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                                      tooltip: "Enroll to another class",
                                      onPressed: () => _showEnrollDialog(student),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                        if (_filteredStudents.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(
                              child: Text(
                                "No students match the current filters.",
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          ),

                        // Pagination Control Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Showing ${totalFiltered == 0 ? 0 : startIndex + 1} - $endIndex of $totalFiltered students",
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 1
                                        ? () => setState(() => _currentPage--)
                                        : null,
                                  ),
                                  Text("$_currentPage / $totalPages",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _currentPage < totalPages
                                        ? () => setState(() => _currentPage++)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
