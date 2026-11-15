import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_attendance_system/models/advanced_analytics_models.dart';
import 'package:student_attendance_system/models/class_model.dart';
import 'package:student_attendance_system/screens/admin/analytics/widgets/analytics_filter_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<ClassModel> dummyClasses = [
    ClassModel(
      id: 'c-cse-1',
      className: 'CSE-1A',
      department: 'CSE',
      academicYear: '2024-2025',
      active: true,
      createdAt: DateTime.now(),
    ),
    ClassModel(
      id: 'c-cse-2',
      className: 'CSE-1B',
      department: 'CSE',
      academicYear: '2024-2025',
      active: true,
      createdAt: DateTime.now(),
    ),
    ClassModel(
      id: 'c-ece-1',
      className: 'ECE-1A',
      department: 'ECE',
      academicYear: '2024-2025',
      active: true,
      createdAt: DateTime.now(),
    ),
  ];

  group('AnalyticsFilterBar Widget Tests', () {
    testWidgets('1. Renders all filter options and action buttons properly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var filterState = AnalyticsFilterState.initial();
      bool refreshed = false;
      bool reset = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnalyticsFilterBar(
              filterState: filterState,
              allClasses: dummyClasses,
              onFilterChanged: (newState) => filterState = newState,
              onRefresh: () => refreshed = true,
              onReset: () => reset = true,
              isLoading: false,
            ),
          ),
        ),
      );

      // Verify presence of title and key controls
      expect(find.text("Analytics & Filter Engine"), findsOneWidget);
      expect(find.text("Academic Year"), findsOneWidget);
      expect(find.text("Department"), findsOneWidget);
      expect(find.text("Class / Section"), findsOneWidget);
      expect(find.text("Month"), findsOneWidget);
      expect(find.text("Year"), findsOneWidget);
      expect(find.text("Session"), findsOneWidget);
      expect(find.text("Attendance Status"), findsOneWidget);
      expect(find.text("Custom Range"), findsOneWidget);
      expect(find.text("Reset Filters"), findsOneWidget);
      expect(find.text("Refresh Analytics"), findsOneWidget);

      // Tap Reset button
      await tester.tap(find.text("Reset Filters"));
      await tester.pump();
      expect(reset, isTrue);

      // Tap Refresh button
      await tester.tap(find.text("Refresh Analytics"));
      await tester.pump();
      expect(refreshed, isTrue);
    });

    testWidgets('2. Cascading: Changing Department triggers onFilterChanged with updated department',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AnalyticsFilterState currentFilter = AnalyticsFilterState.initial();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AnalyticsFilterBar(
                  filterState: currentFilter,
                  allClasses: dummyClasses,
                  onFilterChanged: (newState) {
                    setState(() {
                      currentFilter = newState;
                    });
                  },
                  onRefresh: () {},
                  onReset: () {},
                  isLoading: false,
                );
              },
            ),
          ),
        ),
      );

      // Find the department dropdown
      final deptDropdown = find.ancestor(
        of: find.text('All Departments'),
        matching: find.byType(DropdownButton<String>),
      );
      expect(deptDropdown, findsOneWidget);

      await tester.tap(deptDropdown);
      await tester.pumpAndSettle();

      // Tap on 'CSE' in the popup menu
      final cseOption = find.text('CSE').last;
      await tester.tap(cseOption);
      await tester.pumpAndSettle();

      expect(currentFilter.department, 'CSE');
    });

    testWidgets('3. Session selection triggers state update (Morning / Afternoon / Both)',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AnalyticsFilterState currentFilter = AnalyticsFilterState.initial();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AnalyticsFilterBar(
                  filterState: currentFilter,
                  allClasses: dummyClasses,
                  onFilterChanged: (newState) {
                    setState(() {
                      currentFilter = newState;
                    });
                  },
                  onRefresh: () {},
                  onReset: () {},
                  isLoading: false,
                );
              },
            ),
          ),
        ),
      );

      final sessionDropdown = find.ancestor(
        of: find.text('Both Sessions'),
        matching: find.byType(DropdownButton<String>),
      );
      expect(sessionDropdown, findsOneWidget);

      await tester.tap(sessionDropdown);
      await tester.pumpAndSettle();

      final morningOption = find.text('Morning Only').last;
      await tester.tap(morningOption);
      await tester.pumpAndSettle();

      expect(currentFilter.sessionFilter, 'Morning');
    });
  });
}
