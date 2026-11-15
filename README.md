# Student Attendance Management & Analytics System

A production-grade, enterprise Flutter application and backend infrastructure for college attendance management, real-time analytics intelligence, automated Meta WhatsApp Business notifications, and multi-format reporting.

Built with **Flutter** (Web, Mobile, Desktop), **Supabase** (PostgreSQL with Row Level Security, Triggers & Edge Functions), **Firebase Analytics**, and the official **Meta WhatsApp Cloud API**.

---

## 1. System Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Flutter Multi-Platform Client                     │
│   • Admin Portal: Management, Analytics Intelligence & Export Engine   │
│   • Faculty / Coordinator Portal: Morning & Afternoon Marking Windows  │
│   • Student Portal: Personal Attendance Dossier & Monthly Trends       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                       Supabase / PostgreSQL Database
┌───────────────────────────────────▼────────────────────────────────────┐
│                             Database Engine                            │
│   • Attendance Sessions & Records (Present, Absent, OD, Bunk)          │
│   • Multi-Tenant Row Level Security (RLS) & Role-Based Auth (RBAC)     │
│   • Transactional Queues: whatsapp_outbox & delivery audit logs        │
│   • Stored Procedures: immediate absence alerts & repeated summaries   │
└─────────────┬──────────────────────────────────────────▲───────────────┘
              │                                          │
  Event Queue │                       Webhook & Outbox   │ HMAC-SHA256
              ▼                                          │ Verification
┌───────────────────────────────┐        ┌───────────────┴───────────────┐
│     WhatsApp Outbox Worker    │        │     Meta Webhook Handler      │
│  (Supabase Edge / Node.js)    │        │  (whatsapp-webhook function)  │
│  • E.164 phone normalization  │        │  • Delivery status ingestion  │
│  • Exponential backoff retry  │        │  • Event deduplication        │
└─────────────┬─────────────────┘        └───────────────────────────────┘
              │
              │ HTTPS Graph API (v21.0)
              ▼
┌────────────────────────────────────────────────────────────────────────┐
│              Meta WhatsApp Business Platform Cloud API                 │
│   • Immediate Absence Alerts to Class Advisors                         │
│   • Periodical Repeated-Absence Summaries to Dean & Leadership         │
│   • Scheduled 2:00 PM IST Daily Class Attendance Reports               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Main Capabilities & User Roles

### User Roles & Access Control
- **Administrator**:
  - Full management of academic years, departments, classes, sections, student enrollments, and coordinator assignments.
  - Institutional control of WhatsApp API credentials, dispatch schedules, and authorized notification recipients.
  - Direct access to the **Advanced Attendance Analytics & Reports** dashboard.
- **Faculty / Class Coordinator**:
  - Controlled marking of student attendance within designated college operating windows.
  - Real-time roster overview with status toggles (`Present`, `Absent`, `On Duty`, `Bunk`).
  - Session closing and instant report verification.
- **Student**:
  - Self-service portal displaying subject-wise and term-wise attendance percentage, monthly presence charts, and absence history.

### College Attendance Marking Windows (IST)
To enforce institutional discipline and prevent back-dated manipulation:
- **Morning Attendance Window**: `08:15 AM – 08:45 AM IST`
- **Afternoon Attendance Window**: `12:20 PM – 12:50 PM IST`
- Outside of authorized windows, coordinator marking is strictly locked unless administrative override privileges are exercised.

---

## 3. Advanced Attendance Analytics & Reports Module

The system incorporates an institutional analytics engine that provides deep visibility into student absenteeism, bunk trends, department comparisons, and attendance risk distributions:

### Interactive Analytics Filters
- **Academic Year** (Multi-year historical lookup).
- **Department** (Cascades dynamically to available classes).
- **Class / Section**.
- **Reporting Month & Year** (January through December).
- **Session Filter** (`Morning`, `Afternoon`, `Both`).
- **Attendance Status** (`Present`, `Absent`, `OD`, `Bunk`).
- **Custom Date Range** picker.
- 1-click **Reset Filters** and **Refresh Analytics** with instant in-memory cache bypass.

### Six Analytical Intelligence Views
1. **Month-Wise Bunk Leaderboard**:
   - Ranks students descending by total bunk occurrences.
   - 12-month calendar breakdown with Month-over-Month ($\Delta$) trend detection.
   - Monthly bunk volume distribution bar chart.
2. **All Students Performance Table**:
   - Paginated roster with real-time text search and multi-column sorting.
   - Displays Conducted Sessions, $P, A, OD, B, U$, Attendance %, and Risk Tier.
3. **Individual Student Analytics Dossier**:
   - Deep-dive modal displaying overall %, standard vs. strict attendance, shift consistency, 12-month visual timeline, and highest/lowest attendance months.
4. **Department & Class Comparative Analysis**:
   - Benchmarks attendance performance across engineering departments and class sections.
   - Identifies counts and percentages of at-risk students ($< 75\%$ and $< 65\%$).
5. **Morning versus Afternoon Shift Discrepancy**:
   - Detects post-lunch attendance drop-offs on days where both shifts were conducted.
   - Quantifies students present morning but absent afternoon ($P_{morn} \rightarrow A_{aft}$).
6. **Calendar Attendance Heatmap**:
   - GitHub-style color intensity activity grid charting daily presence rates.

---

## 4. Attendance Calculation Integrity Rules

Institutional audits require strict adherence to calculation standards:

1. **Conducted Closed Sessions Denominator**:
   - Total scheduled sessions ($N$) is computed strictly from finalized, closed attendance sessions (`status = 'closed'`).
   - Open, active, or unconducted sessions are excluded from denominators.
   - Denominators are derived independently of student record row counts.
2. **Explicit Unmarked Handling**:
   - If an enrolled student has no attendance record in a closed session, the system explicitly records it as **Unmarked** ($U$).
   - Unmarked sessions are penalized in the denominator: $N = P + A + OD + B + U$.
   - Unmarked sessions are never assumed to be Present or Bunk.
3. **Formulas**:
   - **Standard Institutional Percentage** (includes approved On Duty):
     $$\text{Attendance } \% = \frac{\text{Present} + \text{OD}}{N} \times 100$$
   - **Strict Physical Presence Percentage**:
     $$\text{Strict Attendance } \% = \frac{\text{Present}}{N} \times 100$$
   - If $N = 0$, attendance safely returns $0.0\%$ (zero division guard).
4. **Historical Class Attribution**:
   - Preserves historical student-to-class enrollments. Graduated students and class transfers retain correct attribution to historical classes without duplicate aggregation.

---

## 5. Multi-Format Data Export Subsystem

Export institutional reports matching active dashboard filters via the **Export Analytics & Reports** modal:

- **Multi-Sheet Excel Workbook (`.xlsx`)**:
  - *Sheet 1*: Executive Overview (KPIs, active filters, risk breakdown table).
  - *Sheet 2*: Student Performance Roster (all students, metrics, and risk tier).
  - *Sheet 3*: Monthly Bunk Leaderboard (Jan–Dec bunk counts and MoM delta).
  - *Sheet 4*: Morning vs. Afternoon Analysis (shift attendance and drop-off counts).
  - *Sheet 5*: Department & Class Comparison (enrolled counts, average %, bunk totals).
- **Institutional PDF Report (`.pdf`)**:
  - Official university header, metadata, filter criteria, summary cards, data tables, formula reference, and formal administrative sign-off blocks.
- **Standardized CSV Exports (`.csv`)**:
  - 4 clean RFC 4180 CSV exports with UTF-8 BOM encoding for seamless spreadsheet opening.

---

## 6. Technology Stack

- **Frontend Application**:
  - **Flutter SDK**: `3.47.x` – `3.50.0`
  - **Dart**: `3.13.x`
  - **UI Libraries**: Google Fonts, Flutter Riverpod, Fl Chart
  - **Reporting Libraries**: `pdf` (3.12.0), `excel` (4.0.6), `csv` (6.0.0), `printing`
- **Backend & Cloud Infrastructure**:
  - **Supabase**: PostgreSQL 15+ with Row Level Security (RLS)
  - **Supabase Edge Functions**: Deno / TypeScript serverless runtime
  - **Firebase**: Firebase Core & Analytics
- **Messaging Integration**:
  - **Meta WhatsApp Business Platform Cloud API**: Graph API `v21.0`
  - **Transactional Outbox Worker**: Node.js worker with exponential backoff retries

---

## 7. Setup & Installation Guide

### Prerequisites
- Flutter SDK (`3.47.x` or higher)
- JDK 17 (Eclipse Adoptium Temurin 17 recommended)
- Android SDK Platform API 34
- Supabase CLI

### 1. Clone the Repository
```bash
git clone https://github.com/Ratul3106/1st-year-attendance-.git
cd 1st-year-attendance-
```

### 2. Configure Environment Variables
Copy the template configuration file:
```bash
cp .env.example .env
```
Populate your Supabase URL, publishable anonymous key, and WhatsApp credentials in `.env`.

### 3. Install Flutter Dependencies
```bash
flutter pub get
```

### 4. Run Automated Test Suites
Run the full test suite or the dedicated analytics test suites:
```bash
# Run all 5 analytics test suites + report generator test:
flutter test test/advanced_analytics_engine_test.dart test/advanced_analytics_service_test.dart test/advanced_analytics_dashboard_test.dart test/advanced_analytics_phase4_test.dart test/advanced_analytics_export_test.dart test/report_generator_test.dart
```

### 5. Launch the Application
```bash
# Run on Chrome / Web:
flutter run -d chrome

# Run on Android (ensure JDK 17 is active):
flutter run -d android
```

---

## 8. Project Directory Structure

```text
├── android/                        # Android Gradle and Native Configuration
│   ├── app/build.gradle            # App-level build configuration (SDK 34, Java 17)
│   ├── gradle/wrapper/             # Gradle Wrapper (8.14.3)
│   ├── build.gradle                # Root project build configuration
│   └── settings.gradle             # AGP (8.11.1), Kotlin (2.2.20), Firebase plugins
├── docs/                           # System Technical Specifications
│   ├── ADVANCED_ANALYTICS.md       # Analytics Views, Formulas, and Caching Specification
│   └── ANDROID_BUILD.md            # Android Toolchain, JDK 17, and Build Instructions
├── lib/
│   ├── core/                       # App themes, constants, Supabase config, utilities
│   ├── models/                     # Data models (Student, Class, Record, Advanced Analytics)
│   ├── screens/
│   │   ├── admin/                  # Admin portal, class management, WhatsApp settings
│   │   │   └── analytics/          # Advanced Analytics Dashboard & 8 visual widgets
│   │   ├── auth/                   # Authentication & role-based routing
│   │   ├── coordinator/            # Morning & afternoon attendance marking screens
│   │   └── student/                # Student personal attendance dashboard
│   ├── services/                   # Business logic (Auth, Attendance, Analytics, Exports)
│   └── widgets/                    # Reusable UI widgets, dialogs, and components
├── supabase/
│   ├── functions/                  # Deno Edge functions (webhook, outbox worker, report jobs)
│   └── migrations/                 # PostgreSQL schema migrations and stored procedures
├── test/                           # Automated unit, service, widget, and export test suites
├── CHANGELOG.md                    # Release and migration history
└── pubspec.yaml                    # Flutter package manifests and dependencies
```

---

## 9. Security & Governance

- **Zero Service-Role Exposure**: Client applications strictly use the public anonymous / publishable Supabase key (`sb_publishable_...`). Service-role administrative keys are never bundled into mobile or web builds.
- **Public Repository Cleanliness**: `.gitignore` comprehensively excludes sensitive `.env` files, Android keystores, local SDK paths (`local.properties`), IDE configurations, and temporary cache directories (`.dart_tool/`, `build/`).
- **Idempotent Webhooks & Outbox**: WhatsApp notifications employ deterministic idempotency keys and HMAC-SHA256 signature verification to prevent duplicate messaging.
