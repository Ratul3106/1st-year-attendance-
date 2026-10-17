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
```

### Configure Meta Webhook URL:
1. In Meta WhatsApp Developer Portal -> WhatsApp -> Configuration:
2. **Callback URL**: `https://<YOUR-PROJECT-ID>.supabase.co/functions/v1/whatsapp-webhook`
3. **Verify Token**: Matching `WHATSAPP_WEBHOOK_VERIFY_TOKEN`
4. Subscribe to the webhook field: **`messages`** (receives delivery status updates: `sent`, `delivered`, `read`, `failed`).

### Automate Scheduled Summary (pg_cron):
```sql
-- Schedule daily repeated-absence evaluation at 18:00 IST (12:30 UTC)
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

All 23 comprehensive tests pass with 100% coverage across:
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

---

## 9. Administrator UI Guide

1. Log in with Administrator credentials (`admin@college.edu`).
2. Navigate to **System Control Panel -> Administrative Operations**:
   - **WhatsApp Attendance Alerts Configuration**:
     - Toggle Immediate Absence Alerts ON/OFF
     - Toggle Repeated-Absence Summaries ON/OFF
     - Adjust Qualifying Absence Threshold (1 to 10)
     - Adjust Reporting Window Days (3 to 30)
     - Configure Dean of Placement & Training phone number
     - Add additional authorized recipient staff
   - **WhatsApp Delivery Logs & History**:
     - Filter logs by status (`Queued`, `Processing`, `Sent`, `Delivered`, `Read`, `Failed`)
     - Inspect provider message IDs (`wamid`), delivery timestamps, and student roll numbers
     - Trigger **Run Absence Summary** on-demand with interactive student preview
     - Trigger **Flush Outbox** to immediately process queued alerts
     - Retry failed messages with 1-click retry
