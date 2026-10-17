import 'package:flutter/material.dart';
import 'package:student_attendance_system/core/constants/app_colors.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/models/student.dart';
import 'package:student_attendance_system/models/attendance_session.dart';
import 'package:student_attendance_system/models/attendance_record.dart';
import 'package:student_attendance_system/services/attendance_service.dart';
import 'package:student_attendance_system/widgets/student_attendance_tile.dart';
import 'package:student_attendance_system/widgets/custom_button.dart';

class AfternoonAttendanceScreen extends StatefulWidget {
  final ClassModel selectedClass;
  final String date;

  const AfternoonAttendanceScreen({
    super.key,
    required this.selectedClass,
    required this.date,
  });

  @override
  State<AfternoonAttendanceScreen> createState() => _AfternoonAttendanceScreenState();
}

class _AfternoonAttendanceScreenState extends State<AfternoonAttendanceScreen> {
  final _attendanceService = AttendanceService();
  final _searchController = TextEditingController();

  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  Map<String, AttendanceStatus> _attendanceState = {};
  Map<String, AttendanceStatus> _morningAttendanceMap = {};

  AttendanceSession? _session;
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _attendanceService.getEnrolledStudents(widget.selectedClass.id);

      // Fetch morning session records to allow cross-comparison review
      final morningSession = await _attendanceService.getOrCreateSession(
        classId: widget.selectedClass.id,
        date: widget.date,
        sessionType: SessionType.morning,
      );
      final morningRecords = await _attendanceService.getSessionRecords(morningSession.id);
      Map<String, AttendanceStatus> mMap = {};
      for (var r in morningRecords) {
        mMap[r.studentId] = r.status;
      }

      // Fetch afternoon session
      final session = await _attendanceService.getOrCreateSession(
        classId: widget.selectedClass.id,
        date: widget.date,
        sessionType: SessionType.afternoon,
      );

      final existingRecords = await _attendanceService.getSessionRecords(session.id);
      Map<String, AttendanceStatus> initialMap = {};
      for (var rec in existingRecords) {
        initialMap[rec.studentId] = rec.status;
      }

      setState(() {
        _allStudents = students;
        _filteredStudents = students;
        _morningAttendanceMap = mMap;
        _attendanceState = Map.from(initialMap);
        _session = session;
        _hasUnsavedChanges = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading afternoon session: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredStudents = _allStudents.where((student) {
        return student.fullName.toLowerCase().contains(_searchQuery) ||
            student.registerNumber.toLowerCase().contains(_searchQuery);
      }).toList();
    });
  }

  int get _presentCount =>
      _attendanceState.values.where((status) => status == AttendanceStatus.present).length;

  int get _absentCount =>
      _attendanceState.values.where((status) => status == AttendanceStatus.absent).length;

  int get _odCount =>
      _attendanceState.values.where((status) => status == AttendanceStatus.od).length;

  int get _bunkCount =>
      _attendanceState.values.where((status) => status == AttendanceStatus.bunk).length;

  int get _unmarkedCount => _allStudents.length - _attendanceState.length;

  void _markAllAsPresent() {
    setState(() {
      for (var student in _allStudents) {
        _attendanceState[student.id] = AttendanceStatus.present;
      }
      _hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Marked all students as Present for Afternoon session."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _reviewAndSubmit() {
    // Calculate morning vs afternoon shifts for review
    int mP_aBunk = 0;
    int mP_aA = 0;
    int mP_aOd = 0;
    int mA_aP = 0;
    int mOd_aP = 0;

    for (final s in _allStudents) {
      final m = _morningAttendanceMap[s.id];
      final a = _attendanceState[s.id];
      if (m == AttendanceStatus.present && a == AttendanceStatus.bunk) mP_aBunk++;
      if (m == AttendanceStatus.present && a == AttendanceStatus.absent) mP_aA++;
      if (m == AttendanceStatus.present && a == AttendanceStatus.od) mP_aOd++;
      if (m == AttendanceStatus.absent && a == AttendanceStatus.present) mA_aP++;
      if (m == AttendanceStatus.od && a == AttendanceStatus.present) mOd_aP++;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.rate_review_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text("Review Afternoon Attendance"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedClass.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _reviewRow("Total Enrolled:", "${_allStudents.length}", AppColors.textPrimary),
                      const Divider(height: 12),
                      _reviewRow("Present (P):", "$_presentCount", AppColors.present),
                      const Divider(height: 12),
                      _reviewRow("Absent (A):", "$_absentCount", AppColors.absent),
                      const Divider(height: 12),
                      _reviewRow("On Duty (OD):", "$_odCount", AppColors.od),
                      const Divider(height: 12),
                      _reviewRow("Bunk (B):", "$_bunkCount", AppColors.bunk),
                      const Divider(height: 12),
                      _reviewRow("Unmarked:", "$_unmarkedCount", _unmarkedCount > 0 ? AppColors.absent : AppColors.unmarked),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Session Shift Highlights:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                _shiftChip("Morning Present → Afternoon Bunk: $mP_aBunk", AppColors.bunk, AppColors.bunkLight),
                const SizedBox(height: 4),
                _shiftChip("Morning Present → Afternoon Absent: $mP_aA", AppColors.absent, AppColors.absentLight),
                const SizedBox(height: 4),
                _shiftChip("Morning Present → Afternoon OD: $mP_aOd", AppColors.od, AppColors.odLight),
                const SizedBox(height: 4),
                _shiftChip("Morning Absent → Afternoon Present: $mA_aP", AppColors.info, AppColors.infoLight),
                const SizedBox(height: 4),
                _shiftChip("Morning OD → Afternoon Present: $mOd_aP", AppColors.info, AppColors.infoLight),

                if (_unmarkedCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "$_unmarkedCount students remain unmarked. Incomplete records will be flagged in reports.",
                            style: const TextStyle(fontSize: 12, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Edit Entries"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveAttendance();
            },
            child: const Text("Confirm & Save"),
          ),
        ],
      ),
    );
  }

  Widget _shiftChip(String text, Color textColor, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_session == null) return;

    setState(() => _isSaving = true);
    try {
      await _attendanceService.saveAttendanceRecords(
        sessionId: _session!.id,
        studentStatusMap: _attendanceState,
      );

      _hasUnsavedChanges = false;
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Afternoon attendance saved successfully! Final reports generated."),
            backgroundColor: AppColors.present,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save afternoon attendance: $e")),
        );
      }
    }
  }

  Widget _reviewRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Discard Unsaved Changes?"),
        content: const Text(
          "You have unsaved afternoon attendance entries. If you leave now, recent changes will not be saved.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Stay & Save"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.absent),
            child: const Text("Discard & Exit"),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Afternoon Attendance — ${widget.selectedClass.className}"),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18, color: Colors.white),
              label: const Text(
                "All Present",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoading ? null : _markAllAsPresent,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Afternoon Metric Strip with 4 Distinct Statuses + Unmarked
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _countColumn("Total", _allStudents.length.toString(), AppColors.textPrimary),
                        _countColumn("Present", _presentCount.toString(), AppColors.present),
                        _countColumn("Absent", _absentCount.toString(), AppColors.absent),
                        _countColumn("OD", _odCount.toString(), AppColors.od),
                        _countColumn("Bunk", _bunkCount.toString(), AppColors.bunk),
                        _countColumn("Unmarked", _unmarkedCount.toString(), AppColors.unmarked),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Search student name or register number...",
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Student List with 4 Statuses: Present, Absent, OD, Bunk
                  Expanded(
                    child: _filteredStudents.isEmpty
                        ? const Center(
                            child: Text(
                              "No matching students found.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final status = _attendanceState[student.id];

                              return StudentAttendanceTile(
                                student: student,
                                status: status,
                                // Exactly 4 statuses: Present, Absent, OD, Bunk
                                allowedStatuses: const [
                                  AttendanceStatus.present,
                                  AttendanceStatus.absent,
                                  AttendanceStatus.od,
                                  AttendanceStatus.bunk,
                                ],
                                onStatusChanged: (newStatus) {
                                  setState(() {
                                    _attendanceState[student.id] = newStatus;
                                    _hasUnsavedChanges = true;
                                  });
                                },
                              );
                            },
                          ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _reviewAndSubmit,
                          icon: const Icon(Icons.checklist, size: 18),
                          label: const Text("Review"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: "Save Afternoon Attendance",
                            isLoading: _isSaving,
                            onPressed: _saveAttendance,
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

  Widget _countColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
