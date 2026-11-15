# Changelog

All notable changes to the **Student Attendance Management System** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - 2026-11-15

### Added - Advanced Attendance Analytics & Reports Module (Phases 1–5)

#### 1. Analytics Models & Core Computation Engine (Phase 1)
- Implemented `AdvancedAnalyticsEngine` with strict, audited institutional attendance formulas.
- Standard Attendance %: $\frac{\text{Present} + \text{OD}}{\text{Conducted Closed Sessions}} \times 100$.
- Strict Physical Attendance %: $\frac{\text{Present}}{\text{Conducted Closed Sessions}} \times 100$.
- Safe zero-denominator guard preventing division-by-zero or `NaN`.
- Explicit accounting for missing attendance records in closed sessions as **Unmarked** ($U$), fully included in the denominator.
- Configurable attendance risk classifications: Good ($\ge 85\%$), Average ($75\% - 84.9\%$), At Risk ($65\% - 74.9\%$), and Severe ($< 65\%$).
- 10 comprehensive unit tests verifying percentage formulas, boundary conditions, and edge cases.

#### 2. Query Services & Historical Enrollment Architecture (Phase 2)
- Implemented `AdvancedAnalyticsService` with batch querying and in-memory TTL caching.
- Strict closed-session validation: excludes open or unconducted sessions from scheduled session totals.
- Historical student-to-class enrollment tracking: preserves class attribution across terms, transfers, and graduations without student duplication.
- Automatic cache invalidation wired to attendance marking, session closure, enrollment modification, and manual UI refresh.

#### 3. Interactive Analytics Dashboard UI & Dynamic Filters (Phase 3)
- Built `AdvancedAnalyticsDashboardScreen` with Vel Tech institutional styling.
- Responsive `AnalyticsFilterBar` supporting cascading selections:
  - Academic Year
  - Department (CSE, ECE, EEE, MECH, etc.)
  - Class / Section
  - Reporting Month & Year
  - Session Filter (Morning, Afternoon, Both)
  - Attendance Status (Present, Absent, OD, Bunk)
  - Custom Date Range picker
- High-level KPI overview cards: Overall Attendance %, Total Conducted Sessions, Student Headcount, and Risk Tier Counts.
- Reset Filters and Manual Refresh triggers.

#### 4. Analytical Intelligence & Visual Views (Phase 4)
- **Month-Wise Bunk Leaderboard**: Ranks students by bunk occurrences, tabulates 12-month calendar counts, computes Month-over-Month ($\Delta$) changes, and displays a monthly bunk distribution chart.
- **All Students Performance Table**: Paginated roster with real-time text search, multi-column sorting (Attendance %, Bunks, Absences), and color-coded risk indicators.
- **Individual Student Drilldown**: Modal dossier showing student trends, high/low months, multi-session consistency, and historical attendance log.
- **Department & Class Comparison**: Side-by-side performance cards with student headcounts, bunk totals, and at-risk student tallies.
- **Morning vs. Afternoon Analysis**: Cross-session shift evaluation identifying students attending morning but missing afternoon sessions.
- **Calendar Attendance Heatmap**: Activity matrix visualizing daily attendance density and intensity levels.

#### 5. Multi-Format Data Export Subsystem (Phase 5)
- Implemented `AdvancedAnalyticsExportService` with multi-platform file delivery.
- **Excel Export (`.xlsx`)**: 5-sheet workbook containing Executive Overview, Student Performance, Monthly Bunk Leaderboard, Morning vs. Afternoon, and Department & Class Comparison.
- **Institutional PDF Report (`.pdf`)**: Formal university report format with institutional headers, active filter parameters, KPI cards, tables, formula disclaimer, and sign-off blocks.
- **Four Standardized CSV Exports (`.csv`)**: RFC 4180 compliant with UTF-8 BOM encoding.
- Interactive export selection dialog (`AnalyticsExportDialog`) embedded into dashboard header.

### Quality Assurance & Validation
- **Unit & Widget Tests**: 35 test cases passing across 5 dedicated analytics test suites + 1 report generator test (36 tests total, 100% pass rate).
- **Static Analysis**: 0 analyzer errors (`flutter analyze`) across the entire codebase.

### Changed & Maintained
- **Android Configuration Baseline**: Maintained stable Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20, Java 17, Compile SDK 34, and Firebase Analytics. Documented AGP 9.3.1 evaluation findings in `docs/ANDROID_BUILD.md`.
- **Git Tracking Cleanup**: Updated `.gitignore` to prevent tracking of build artifacts (`.dart_tool/`, `build/`, `local.properties`), secrets, and logs.
