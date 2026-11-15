# Advanced Attendance Analytics & Reports Module

The **Advanced Attendance Analytics & Reports** module provides institutional-grade attendance intelligence, historical pattern tracking, bunk ranking, risk-tier identification, and multi-format document exporting for college administration.

---

## 1. Core Analytics Views

The module provides six interconnected analytical views within the Admin Portal:

### 1. Month-Wise Bunk Analysis & Leaderboard
- **Ranking**: Sorts students descending by total bunk sessions within the selected academic period and department.
- **Student Details**: Displays student name, register number, department, class/section, total bunks, and overall attendance percentage.
- **Calendar Breakdown**: Tabulates monthly bunk occurrences (January through December).
- **Trend Detection**: Computes Month-over-Month (MoM) delta ($\Delta$) comparing current month bunks to previous month.
- **Visual Distribution**: Interactive bar chart plotting monthly bunk volume.
- **Actionable Drilldown**: Clicking any student row opens their dedicated individual analytics dossier.

### 2. All Students Performance Roster
- **Comprehensive Registry**: Ranks and tabulates all enrolled students within the selected filter scope.
- **Metrics Tracked**:
  - Rank & Student Credentials (Name, Register Number, Department, Class).
  - Total Conducted Sessions (Denominator).
  - Present ($P$), Absent ($A$), On Duty ($OD$), Bunk ($B$), and Unmarked ($U$).
  - Standard Attendance Percentage ($\%$) and Strict Percentage ($\%_{strict}$).
  - Attendance Risk Classification badge.
- **Capabilities**:
  - Real-time client-side search across Student Name and Register Number.
  - Multi-column sorting (by Attendance %, Bunk count, Absences, or Register Number).
  - Efficient client-side pagination with configurable page sizes (10, 25, 50, 100 rows).
  - Direct student drilldown trigger on row click.

### 3. Individual Student Analytics & Monthly Drilldown Dialog
- **Modal Dossier**: Deep-dive profile for any specific student.
- **KPI Summary Cards**:
  - Overall Attendance Percentage with Risk Tier badge.
  - Standard vs. Strict Attendance comparison.
  - Total Sessions, Present count, Absences, Bunks, and ODs.
  - Multi-session shift discrepancy summary (Morning vs. Afternoon consistency).
- **Monthly Trend Chart**: 12-month visual timeline indicating attendance percentage per month.
- **Statistical Extremes**: Automatically highlights the student's highest-performing and lowest-performing months.
- **Session History Log**: Chronological list of attended, absent, or bunked sessions.

### 4. Department & Class Comparative Analysis
- **Department Benchmarking**: Aggregates average attendance percentage, total enrolled students, total bunks, and at-risk student counts across departments (CSE, ECE, EEE, MECH, etc.).
- **Class-Level Comparison**: Breaks down performance across sections within a department (e.g., III CSE - A vs. III CSE - B).
- **Institutional Risk Overview**: Quantifies percentage of students falling below statutory thresholds (e.g. < 75% or < 65%).

### 5. Morning versus Afternoon Shift Discrepancy Analysis
- **Shift Consistency Tracking**: Evaluates student attendance behavioral patterns across morning (8:15–8:45 AM) and afternoon (12:20–12:50 PM) sessions on days where both sessions were conducted.
- **Key Metrics**:
  - Present in Both Sessions ($P_{both}$).
  - Present Morning but Absent/Bunked Afternoon ($P_{morn} \rightarrow A_{aft}$).
  - Absent in Both Sessions ($A_{both}$).
- **Drop-off Identification**: Identifies students with recurrent post-lunch absenteeism (half-day bunks).

### 6. Calendar Attendance Heatmap
- **Visual Activity Map**: GitHub-style daily attendance density map over the selected academic term or month.
- **Categorization Tiers**:
  - **High Attendance** ($\ge 85\%$ present): Deep Green
  - **Moderate Attendance** ($75\% - 84.9\%$): Light Green
  - **Low Attendance** ($60\% - 74.9\%$): Amber / Orange
  - **Critical Attendance** ($< 60\%$): Red
  - **No Conducted Sessions**: Neutral Slate Grey
- **Hover/Click Detail**: Displays exact date, total sessions conducted, student presence rate, and bunk counts.

---

## 2. Attendance Calculation Rules & Integrity Standards

Institutional audits require zero tolerance for calculation drift. The following rules govern all computations:

### A. Conducted Closed Sessions Denominator
- **Strict Finalization Rule**: Only finalized/closed attendance sessions (`status = 'closed'` or with non-null `closed_at`) count toward the scheduled session denominator ($N$).
- **Open Session Exclusion**: Open, active, or upcoming sessions are strictly excluded from denominators to prevent artificial deflation of attendance.
- **Independent Denominator**: The total scheduled sessions for an individual student is derived from valid conducted sessions for their enrolled class during their enrollment period, **not** by counting attendance record rows (`COUNT(ar.id)`).

### B. Missing Attendance Records & Unmarked Handling
- If a session was conducted and closed, but no attendance record exists for an enrolled student, the system explicitly categorizes the record as **Unmarked** ($U$).
- **Integrity Rule**: Unmarked sessions are penalized in the denominator:
  $$\text{Scheduled Sessions } (N) = P + A + OD + B + U$$
- Unmarked sessions are **never** assumed or converted to Present, nor are they silently dropped from the denominator.

### C. Standard vs. Strict Attendance Percentages
- **Standard Institutional Percentage** (includes approved On Duty):
  $$\text{Attendance } \% = \frac{\text{Present} + \text{OD}}{N} \times 100$$
- **Strict Physical Presence Percentage**:
  $$\text{Strict Attendance } \% = \frac{\text{Present}}{N} \times 100$$
- **Zero-Session Guard**: If $N = 0$, attendance safely returns $0.0\%$ without division-by-zero or `NaN` exceptions.

### D. Attendance Risk Level Classifications
By default, institutional thresholds are categorized as:
- **Good / Safe**: $\ge 85.0\%$
- **Average / Warning**: $75.0\% - 84.99\%$
- **At Risk / Critical**: $65.0\% - 74.99\%$
- **Severe Shortage / Detained**: $< 65.0\%$

Thresholds are configurable in `AdvancedAnalyticsEngine` without breaking API contracts.

### E. Historical Enrollment & Student Transfers
- Student historical attendance is strictly attributed to the class and academic year in which the session was conducted.
- Transferred students preserve attendance history under their original class without duplication in historical aggregates.
- Graduated students and inactive classes remain fully queryable when selecting historical academic years.

---

## 3. Caching & Real-Time Invalidation Strategy

To support instant responsiveness across 900+ students and multi-year attendance datasets:
- **In-Memory Query Cache**: Analytics records, aggregated KPI models, and student rosters are cached with time-to-live (TTL) expiration in `AdvancedAnalyticsService`.
- **Automatic Invalidation Triggers**:
  - Attendance marking: `AttendanceService.saveAttendance()` triggers `AdvancedAnalyticsService.instance.invalidateCache()`.
  - Session finalization: `AttendanceService.closeSession()` invalidates cache.
  - Class enrollment / transfers: `AdminService.assignStudentToClass()` invalidates cache.
  - Manual Refresh: The **Refresh Analytics** button on the dashboard forces an immediate cache bypass and fresh remote fetch.

---

## 4. Multi-Format Data Export Capabilities

The module includes an export subsystem (`AdvancedAnalyticsExportService`) accessible via the **Export Analytics & Reports** modal dialog:

### 1. Multi-Sheet Excel Workbook (`.xlsx`)
Formulas and structured tables spanning five dedicated sheets:
1. **Executive Overview**: High-level KPI summary, filters applied, overall percentages, risk distribution table.
2. **Student Performance**: Full roster with Register No, Name, Dept, Class, Conducted Sessions, $P, A, OD, B, U$, Attendance %, and Risk Tier.
3. **Monthly Bunk Leaderboard**: Ranked bunk offenders with January–December monthly columns, total bunks, and MoM changes.
4. **Morning vs Afternoon**: Morning %, Afternoon %, shift drops, and discrepancy incident counts.
5. **Department & Class Comparison**: Comparative breakdown of students, average attendance %, bunks, and at-risk counts.

### 2. Institutional PDF Document (`.pdf`)
- Built for official university records, accreditation audits (NBA/NAAC), and administrative reviews.
- Includes header with institutional branding, academic year metadata, active filter criteria, executive KPI cards, performance tables, formula notes, and formal sign-off approval blocks.

### 3. Four Standardized CSV Exports (`.csv`)
Formatted per RFC 4180 with UTF-8 BOM encoding for seamless opening in Microsoft Excel and external data tools:
1. `attendance_executive_summary.csv`
2. `student_performance_roster.csv`
3. `monthly_bunk_leaderboard.csv`
4. `morning_vs_afternoon_analysis.csv`
