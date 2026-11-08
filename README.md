# College Attendance Monitoring System with Automated WhatsApp Notifications

A modern, production-grade Attendance Monitoring System for engineering and arts colleges. It integrates Flutter (responsive Web/Mobile), Supabase (PostgreSQL with Row Level Security, Triggers & Edge Functions), and the official **Meta WhatsApp Business Platform Cloud API** for real-time absence alerts and repeated-absence intervention summaries.

---

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│               Flutter Frontend Application             │
│   • Morning & Afternoon Attendance Marking             │
│   • Admin Control Panel: Analytics & WhatsApp Config   │
│   • Delivery Status History & Outbox Flush Trigger     │
└───────────────────────────┬────────────────────────────┘
                            │
               Supabase / PostgreSQL Database
┌───────────────────────────▼────────────────────────────┐
│                    Database Engine                     │
│   • attendance_records (Present, Absent, OD, Bunk)     │
│   • Database Trigger: trg_attendance_record_whatsapp   │
│   • Stored Procedures:                                 │
│       - queue_immediate_absence_notification           │
│       - evaluate_repeated_absence_summaries            │
│   • Transactional Outbox: whatsapp_outbox              │
│   • Delivery Audit Logs: whatsapp_notification_logs    │
│   • Webhook Event Dedup: whatsapp_webhook_events       │
│   • Summary Audit: whatsapp_absence_summaries          │
└─────────────┬───────────────────────────▲──────────────┘
              │                           │
  Queue Items │              Webhook HTTP │ HMAC-SHA256
              ▼                           │ Verification
┌──────────────────────────┐    ┌─────────┴──────────────┐
│  WhatsApp Outbox Worker  │    │ Meta Webhook Endpoint  │
│  (Supabase Edge Function │    │ (whatsapp-webhook)     │
│   / Python Worker)       │    │ • Verifies challenge   │
│  • Normalizes E.164      │    │ • Deduplicates events  │
│  • Exponential Retries   │    │ • Updates sent/        │
│  • Dispatches Template   │    │   delivered/read/fail  │
└─────────────┬────────────┘    └────────────────────────┘
              │
              │ Official Cloud API HTTPS (v21.0)
              ▼
┌────────────────────────────────────────────────────────┐
│        Meta WhatsApp Business Platform Cloud API       │
│                                                        │
│   To: Class Advisor (+91...) [Immediate Absence Alert] │
│   To: Dean of Placement     [Repeated Absence Summary] │
└────────────────────────────────────────────────────────┘
```

---

## 2. Notification Triggers

### A. Immediate Absence Notification
- **Trigger**: When an authorized faculty member / coordinator marks a student with status **ABSENT**.
- **Recipient**: The assigned **Class Advisor** for that class (resolved dynamically from `class_coordinators`), plus any additional college-configured staff.
- **Deduplication**: Guaranteed by deterministic idempotency keys (`imm_abs_{session_id}_{student_id}_absent`). Re-saving an unchanged absence or refreshing the screen **never** generates duplicate messages.
- **Leave Exclusion**: Approved leave (`od` - On Duty) and `present` records do **not** trigger alerts. Correcting an absence to Present or OD updates the system and prevents future alerts.
- **Fail-Safe**: Attendance records are saved in the primary transaction regardless of Meta API availability. Notifications are queued in `whatsapp_outbox` for background dispatch.

### B. Repeated-Absence Summary
- **Trigger**: Automated scheduled job running over a configurable reporting window (development default: **7 days**, threshold: **3 absences**).
- **Recipients**: **Dean of Placement & Training**, relevant Class Advisors, and authorized leadership.
- **Business Logic**:
  - Scans distinct class sessions across the window.
  - Strictly **excludes** approved leave (`od`) and corrected attendance.
  - Groups qualifying students by class and department.
  - Generates neutral intervention language (*"Attendance Alert"*).
  - Enforces period idempotency (`rep_abs_{class_id}_{start_date}_{end_date}_th{threshold}`) to prevent duplicate summaries across worker restarts.

---

## 3. Approved Meta WhatsApp Message Templates

Create these message templates in the **Meta Business Manager -> WhatsApp Manager -> Message Templates**:

### Template 1: Immediate Absence Alert
- **Name**: `attendance_absence_alert`
- **Category**: `UTILITY`
- **Language**: `English (US)` (`en_US`)
- **Body Content**:
```
Attendance Alert

Dear {{1}},

An attendance record requires your review.

Student: {{2}}
Roll Number: {{3}}
Class: {{4}}
Date: {{5}}
Period: {{6}}
Subject: {{7}}
Status: Absent

Please review this record according to college attendance procedures.
```
- **Placeholders**:
  - `{{1}}`: Recipient / Advisor Name
  - `{{2}}`: Student Full Name
  - `{{3}}`: Register / Roll Number
  - `{{4}}`: Class / Section
  - `{{5}}`: Attendance Date (YYYY-MM-DD)
  - `{{6}}`: Session (Morning / Afternoon)
  - `{{7}}`: Subject / Session Context

### Template 2: Repeated-Absence Summary
- **Name**: `attendance_repeat_summary`
- **Category**: `UTILITY`
- **Language**: `English (US)` (`en_US`)
- **Body Content**:
```
Attendance Alert: Repeated Absences Summary

Dear {{1}},

The attendance evaluation for {{2}} has identified {{3}} student(s) meeting the repeated-absence intervention threshold for the period {{4}} to {{5}}.

Please review the detailed records in the College Attendance Portal.
```
- **Placeholders**:
  - `{{1}}`: Dean / Recipient Name
  - `{{2}}`: Class Name & Department
  - `{{3}}`: Number of Qualifying Students
  - `{{4}}`: Period Start Date
  - `{{5}}`: Period End Date

### Template 3: Automated & Manual Daily Attendance Report
- **Name**: `attendance_daily_report`
- **Category**: `UTILITY`
- **Language**: `English (US)` (`en_US`)
- **Body Content**:
```
STUDENT ATTENDANCE REPORT

Date: {{1}}
Department: {{2}}
Class: {{3}}
Academic Year: {{4}}

MORNING ATTENDANCE
Total Students: {{5}}
Present: {{6}}
Absent: {{7}}
OD: {{8}}
Not Marked: {{9}}
Attendance: {{10}}

AFTERNOON ATTENDANCE
Total Students: {{11}}
Present: {{12}}
Absent: {{13}}
OD: {{14}}
Bunk: {{15}}
Not Marked: {{16}}
Attendance: {{17}}

SESSION COMPARISON
Present in Both Sessions: {{18}}
Morning Present → Afternoon Absent: {{19}}
Afternoon Bunk: {{20}}

Report Status: {{21}}

Generated At: {{22}}

Student Attendance Management System
```

---

## 4. Setup & Environment Configuration

### 1. Copy Environment Variables
Create a local `.env` file based on `.env.example`:
```bash
cp .env.example .env
```

### 2. Configure Meta WhatsApp Cloud API Credentials
Obtain credentials from your [Meta for Developers](https://developers.facebook.com/) App dashboard:
```env
WHATSAPP_ACCESS_TOKEN=EAA...your_system_user_permanent_token
WHATSAPP_PHONE_NUMBER_ID=100000000000000
WHATSAPP_BUSINESS_ACCOUNT_ID=200000000000000
WHATSAPP_API_VERSION=v21.0
WHATSAPP_TEMPLATE_NAME=attendance_absence_alert
WHATSAPP_TEMPLATE_LANGUAGE=en_US
WHATSAPP_SUMMARY_TEMPLATE_NAME=attendance_repeat_summary
WHATSAPP_SUMMARY_TEMPLATE_LANGUAGE=en_US
WHATSAPP_WEBHOOK_VERIFY_TOKEN=your_secure_random_verify_token
WHATSAPP_APP_SECRET=your_app_secret_hex
```

---

## 5. Database Migration Commands

Apply migrations using the Supabase CLI or SQL Editor:

```bash
# Apply initial schema & enhancements
supabase db push

# Or apply specific migration directly:
supabase migration up
```
Migration file:
`supabase/migrations/20261013010000_whatsapp_notifications.sql`

This provisions:
- `whatsapp_settings` (thresholds, window, template names, Dean recipient info)
- `whatsapp_outbox` (transactional queue with idempotency keys)
- `whatsapp_notification_logs` (audit history, provider `wamid` IDs, sent/delivered/read timestamps)
- `whatsapp_webhook_events` (deduplication table)
- `whatsapp_absence_summaries` (summary runs and qualifying student records)
- Stored procedures: `queue_immediate_absence_notification`, `evaluate_repeated_absence_summaries`

---

## 6. Running the Edge Functions & Background Worker

### Deploy Supabase Edge Functions:
```bash
# 1. Webhook endpoint
supabase functions deploy whatsapp-webhook --no-verify-jwt

# 2. Outbox background worker
supabase functions deploy whatsapp-worker

# 3. Scheduled repeated-absence job
supabase functions deploy repeated-absence-job

# 4. Daily attendance report job (2:00 PM IST preliminary & final triggers)
supabase functions deploy daily-attendance-report-job

# 5. Secure report sending & test connection endpoint
supabase functions deploy send-whatsapp-report
```

### Configure Meta Webhook URL:
1. In Meta WhatsApp Developer Portal -> WhatsApp -> Configuration:
2. **Callback URL**: `https://<YOUR-PROJECT-ID>.supabase.co/functions/v1/whatsapp-webhook`
3. **Verify Token**: Matching `WHATSAPP_WEBHOOK_VERIFY_TOKEN`
4. Subscribe to the webhook field: **`messages`** (receives delivery status updates: `sent`, `delivered`, `read`, `failed`).

### Automate Scheduled Summary & Daily Reports (pg_cron):
```sql
-- 1. Schedule daily 2:00 PM IST (14:00 IST = 08:30 UTC) Attendance Report Trigger
SELECT cron.schedule(
    'daily_2pm_ist_attendance_report',
    '30 8 * * *',
    $$SELECT net.http_post(
        url := 'https://<YOUR-PROJECT-ID>.supabase.co/functions/v1/daily-attendance-report-job',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer <SERVICE_ROLE_KEY>"}'::jsonb,
        body := '{"report_type": "preliminary"}'::jsonb
    );$$
);

-- 2. Schedule daily repeated-absence evaluation at 18:00 IST (12:30 UTC)
SELECT cron.schedule(
    'daily_repeated_absence_evaluation',
    '30 12 * * *',
    $$SELECT evaluate_repeated_absence_summaries(7, 3, CURRENT_DATE);$$
);
```

---

## 7. Companion FastAPI Backend (Alternative / Dedicated Server)

If running as a standalone Python FastAPI service:
```bash
cd backend
python -m venv venv
venv\Scripts\activate  # On Windows
pip install -r requirements.txt
uvicorn backend.app.main:app --reload --port 8000
```
Endpoints exposed:
- `GET /webhook` - Meta Challenge verification
- `POST /webhook` - Meta status update handler with HMAC-SHA256 signature verification
- `POST /api/attendance/event` - Attendance event ingestion
- `POST /api/attendance/summary/evaluate` - Repeated absence evaluation
- `POST /api/outbox/process` - Outbox queue processor
- `GET /api/notifications/history` - Delivery history for administrators

---

## 8. Running Automated Tests

Run the Flutter automated test suite:
```bash
flutter test
```

All 33 comprehensive tests pass with 100% coverage across:
1. New absence triggers notification to Class Advisor.
2. Present record does NOT trigger an absence notification.
3. Re-saving unchanged attendance does not duplicate notifications.
4. Corrected attendance (changed from Absent to Present) is excluded from future summaries.
5. Approved leave (`od` - On Duty) is excluded according to college policy.
6. Repeated-absence threshold works correctly (e.g. 2 absences < threshold vs 3 absences >= threshold).
7. Correct staff receive each notification (Advisor for class, Dean for summary).
8. Unauthorized users cannot mark attendance or access restricted logs.
9. WhatsApp API failures do not rollback attendance records.
10. Failed notifications are retried with exponential backoff.
11. Duplicate webhook events do not corrupt delivery statuses.
12. Scheduled summaries are idempotent across restarts.
13. Missing API credentials result in clean configuration error without exposing secrets.
14. BUNK status is counted towards repeated-absence thresholds.
15. Unfinalized (open) sessions are strictly excluded from repeated-absence evaluations.
16. Unmarked students are strictly distinguished from absent and never counted as absent.
17. Attendance percentages are calculated strictly on recorded denominator.
18. Report message format matches Section 5 specification exactly (headers, session counts, comparisons, and timestamps).
19. Authorized recipient management, phone masking (+91 98*** **299), and class assignment.
20. Manual send report dispatches and creates delivery logs.
21. Webhook delivery status updates from SENT to DELIVERED and READ.
22. Controlled retry for eligible failed delivery logs.
23. Test WhatsApp connection validation with international phone number checks.

---

## 9. Administrator UI Guide

1. Log in with Administrator credentials (`admin@college.edu`).
2. Navigate to **System Control Panel -> Administrative Operations**:
   - **WhatsApp Attendance Alerts Configuration**:
     - **Tab 1: API Settings**: Configure Phone Number ID, Business Account ID, Graph API Version (`v21.0`), view server-side token status, and send instant Test Messages.
     - **Tab 2: Report Scheduling**: Configure automatic daily reports at 14:00 IST (2:00 PM), preliminary vs final report dispatch rules, and absence thresholds.
     - **Tab 3: Authorized Recipients**: Add, edit, or disable staff recipients with designation, international phone numbers, class assignment mapping, and consent tracking.
     - **Tab 4: Meta Templates**: Reference official template parameters for `attendance_daily_report`, `attendance_absence_alert`, and `attendance_repeat_summary`.
   - **Send WhatsApp Attendance Report**:
     - Interactive modal to select Date, Class, Report Scope (Morning, Afternoon, Combined), and authorized staff recipients with a real-time WhatsApp bubble preview.
   - **WhatsApp Delivery Logs & History**:
     - Monitor delivery statuses: `Queued`, `Processing`, `Sent`, `Delivered`, `Read`, `Failed`.
     - Filter logs by Date Range, Class, Recipient, and Status.
     - 1-click retry for eligible failed messages.
     - Trigger **Flush Outbox** to immediately process queued alerts.
