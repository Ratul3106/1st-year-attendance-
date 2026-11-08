-- Migration: 20261013020000_whatsapp_automated_reports.sql
-- Description: Database schema for WhatsApp Automated Attendance Reports via Meta Cloud API,
-- including report scheduling, authorized recipients, attendance reports cache, and delivery logs.

-- 1. Ensure Delivery Status & Notification Type Types
DO $$ BEGIN
    CREATE TYPE whatsapp_delivery_status AS ENUM ('queued', 'processing', 'sent', 'delivered', 'read', 'failed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE whatsapp_notification_type AS ENUM (
        'immediate_absence',
        'repeated_absence_summary',
        'manual_alert',
        'daily_report_preliminary',
        'daily_report_final',
        'attendance_report'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. WhatsApp Configuration Table (Non-secret scheduling and delivery preferences)
CREATE TABLE IF NOT EXISTS whatsapp_config (
    id UUID PRIMARY KEY DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    reports_enabled BOOLEAN NOT NULL DEFAULT true,
    immediate_alerts_enabled BOOLEAN NOT NULL DEFAULT true,
    summary_alerts_enabled BOOLEAN NOT NULL DEFAULT true,
    report_time TEXT NOT NULL DEFAULT '14:00',
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    report_frequency TEXT NOT NULL DEFAULT 'daily',
    target_classes TEXT NOT NULL DEFAULT 'all',
    include_morning BOOLEAN NOT NULL DEFAULT true,
    include_afternoon BOOLEAN NOT NULL DEFAULT true,
    include_combined BOOLEAN NOT NULL DEFAULT true,
    send_preliminary BOOLEAN NOT NULL DEFAULT true,
    send_final_on_completion BOOLEAN NOT NULL DEFAULT true,
    phone_number_id TEXT NOT NULL DEFAULT '100000000000000',
    business_account_id TEXT DEFAULT '200000000000000',
    api_version TEXT NOT NULL DEFAULT 'v21.0',
    report_template_name TEXT NOT NULL DEFAULT 'attendance_daily_report',
    report_template_lang TEXT NOT NULL DEFAULT 'en_US',
    absence_template_name TEXT NOT NULL DEFAULT 'attendance_absence_alert',
    absence_template_lang TEXT NOT NULL DEFAULT 'en_US',
    summary_template_name TEXT NOT NULL DEFAULT 'attendance_repeat_summary',
    summary_template_lang TEXT NOT NULL DEFAULT 'en_US',
    dean_placement_name TEXT DEFAULT 'Dean of Placement and Training',
    dean_placement_phone TEXT DEFAULT '+919876543200',
    absence_threshold INT NOT NULL DEFAULT 3,
    reporting_window_days INT NOT NULL DEFAULT 7,
    api_status TEXT NOT NULL DEFAULT 'configured',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default configuration row
INSERT INTO whatsapp_config (
    id,
    reports_enabled,
    report_time,
    timezone,
    report_frequency,
    phone_number_id,
    business_account_id,
    api_version,
    report_template_name,
    report_template_lang,
    send_preliminary,
    send_final_on_completion
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    true,
    '14:00',
    'Asia/Kolkata',
    'daily',
    '100000000000000',
    '200000000000000',
    'v21.0',
    'attendance_daily_report',
    'en_US',
    true,
    true
) ON CONFLICT (id) DO NOTHING;

-- 3. Authorized Report Recipients Table
CREATE TABLE IF NOT EXISTS whatsapp_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    designation TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    report_types TEXT NOT NULL DEFAULT 'both', -- 'preliminary', 'final', 'both'
    session_preferences TEXT NOT NULL DEFAULT 'combined', -- 'morning', 'afternoon', 'combined'
    active BOOLEAN NOT NULL DEFAULT true,
    consent_obtained BOOLEAN NOT NULL DEFAULT true,
    authorized_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Recipient Class Assignments (Mapping recipients to assigned classes)
CREATE TABLE IF NOT EXISTS whatsapp_recipient_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES whatsapp_recipients(id) ON DELETE CASCADE,
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
    all_classes BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recipient_class UNIQUE (recipient_id, class_id)
);

-- 5. Attendance Reports Cache & Historical Records Table
CREATE TABLE IF NOT EXISTS attendance_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_date DATE NOT NULL,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    report_type TEXT NOT NULL DEFAULT 'preliminary', -- 'preliminary', 'final'
    session_type TEXT NOT NULL DEFAULT 'combined',    -- 'morning', 'afternoon', 'combined'
    total_enrolled INT NOT NULL DEFAULT 0,
    morning_present INT NOT NULL DEFAULT 0,
    morning_absent INT NOT NULL DEFAULT 0,
    morning_od INT NOT NULL DEFAULT 0,
    morning_unmarked INT NOT NULL DEFAULT 0,
    morning_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    afternoon_present INT NOT NULL DEFAULT 0,
    afternoon_absent INT NOT NULL DEFAULT 0,
    afternoon_od INT NOT NULL DEFAULT 0,
    afternoon_bunk INT NOT NULL DEFAULT 0,
    afternoon_unmarked INT NOT NULL DEFAULT 0,
    afternoon_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    present_both INT NOT NULL DEFAULT 0,
    present_morning_absent_afternoon INT NOT NULL DEFAULT 0,
    afternoon_bunk_count INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'generated', -- 'generated', 'sent', 'incomplete'
    report_message_text TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_attendance_report_per_class_type UNIQUE (report_date, class_id, report_type)
);

-- 6. Enhance WhatsApp Delivery Logs Table
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS report_id UUID REFERENCES attendance_reports(id) ON DELETE SET NULL;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS recipient_id UUID REFERENCES whatsapp_recipients(id) ON DELETE SET NULL;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS report_date DATE;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS report_type_label TEXT;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS retry_count INT NOT NULL DEFAULT 0;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS max_retries INT NOT NULL DEFAULT 5;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ;

-- 7. Indexes for Performance and Queries
CREATE INDEX IF NOT EXISTS idx_whatsapp_recipients_active ON whatsapp_recipients(active);
CREATE INDEX IF NOT EXISTS idx_whatsapp_recipient_classes ON whatsapp_recipient_classes(recipient_id, class_id);
CREATE INDEX IF NOT EXISTS idx_attendance_reports_date_class ON attendance_reports(report_date, class_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_report_id ON whatsapp_notification_logs(report_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_status_created ON whatsapp_notification_logs(status, created_at DESC);

-- 8. Row Level Security (RLS)
ALTER TABLE whatsapp_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_recipient_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_reports ENABLE ROW LEVEL SECURITY;

-- Admins full access to config & recipients
CREATE POLICY "Admins full management on whatsapp_config"
    ON whatsapp_config FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins full management on whatsapp_recipients"
    ON whatsapp_recipients FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins full management on whatsapp_recipient_classes"
    ON whatsapp_recipient_classes FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins full access on attendance_reports"
    ON attendance_reports FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- Staff and Coordinators can view reports only for their assigned classes
CREATE POLICY "Staff and coordinators view authorized attendance reports"
    ON attendance_reports FOR SELECT TO authenticated
    USING (
        is_admin() OR
        (class_id IS NOT NULL AND is_coordinator_for_class(class_id))
    );

-- 9. Stored Function to Calculate Standard Class Attendance Report
CREATE OR REPLACE FUNCTION generate_class_whatsapp_report(
    p_class_id UUID,
    p_date DATE,
    p_report_type TEXT DEFAULT 'preliminary'
)
RETURNS JSONB AS $$
DECLARE
    v_class RECORD;
    v_total_enrolled INT := 0;
    v_m_session RECORD;
    v_a_session RECORD;
    v_m_pres INT := 0;
    v_m_abs INT := 0;
    v_m_od INT := 0;
    v_m_unmarked INT := 0;
    v_m_recorded INT := 0;
    v_m_pct NUMERIC(5,2) := 0.00;
    v_a_pres INT := 0;
    v_a_abs INT := 0;
    v_a_od INT := 0;
    v_a_bunk INT := 0;
    v_a_unmarked INT := 0;
    v_a_recorded INT := 0;
    v_a_pct NUMERIC(5,2) := 0.00;
    v_both_pres INT := 0;
    v_m_pres_a_abs INT := 0;
    v_a_bunk_cnt INT := 0;
    v_status_label TEXT;
    v_msg TEXT;
    v_report_id UUID;
    v_now_ist_str TEXT;
BEGIN
    SELECT * INTO v_class FROM classes WHERE id = p_class_id;
    IF v_class IS NULL THEN
        RETURN jsonb_build_object('error', 'Class not found');
    END IF;

    -- Count enrolled active students
    SELECT COUNT(*) INTO v_total_enrolled
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = p_class_id AND s.active = true;

    -- Fetch sessions
    SELECT * INTO v_m_session
    FROM attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'morning'
    LIMIT 1;

    SELECT * INTO v_a_session
    FROM attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'afternoon'
    LIMIT 1;

    -- Aggregate student records
    WITH student_list AS (
        SELECT s.id AS student_id
        FROM class_enrollments ce
        JOIN students s ON s.id = ce.student_id
        WHERE ce.class_id = p_class_id AND s.active = true
    ),
    m_records AS (
        SELECT student_id, status FROM attendance_records
        WHERE session_id = v_m_session.id
    ),
    a_records AS (
        SELECT student_id, status FROM attendance_records
        WHERE session_id = v_a_session.id
    ),
    joined AS (
        SELECT
            sl.student_id,
            m.status AS m_status,
            a.status AS a_status
        FROM student_list sl
        LEFT JOIN m_records m ON m.student_id = sl.student_id
        LEFT JOIN a_records a ON a.student_id = sl.student_id
    )
    SELECT
        COUNT(*) FILTER (WHERE m_status = 'present') AS m_p,
        COUNT(*) FILTER (WHERE m_status = 'absent') AS m_a,
        COUNT(*) FILTER (WHERE m_status = 'od') AS m_o,
        COUNT(*) FILTER (WHERE m_status IS NULL) AS m_u,
        COUNT(*) FILTER (WHERE a_status = 'present') AS a_p,
        COUNT(*) FILTER (WHERE a_status = 'absent') AS a_a,
        COUNT(*) FILTER (WHERE a_status = 'od') AS a_o,
        COUNT(*) FILTER (WHERE a_status = 'bunk') AS a_b,
        COUNT(*) FILTER (WHERE a_status IS NULL) AS a_u,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'present') AS b_p,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'absent') AS m_p_a,
        COUNT(*) FILTER (WHERE a_status = 'bunk') AS bnk_cnt
    INTO
        v_m_pres, v_m_abs, v_m_od, v_m_unmarked,
        v_a_pres, v_a_abs, v_a_od, v_a_bunk, v_a_unmarked,
        v_both_pres, v_m_pres_a_abs, v_a_bunk_cnt
    FROM joined;

    -- Calculate Morning Percentage strictly using recorded attendance denominator
    v_m_recorded := v_m_pres + v_m_abs + v_m_od;
    IF v_m_recorded > 0 THEN
        v_m_pct := ROUND(((v_m_pres + v_m_od)::NUMERIC / v_m_recorded::NUMERIC) * 100.0, 2);
    ELSE
        v_m_pct := 0.00;
    END IF;

    -- Calculate Afternoon Percentage strictly using recorded attendance denominator
    v_a_recorded := v_a_pres + v_a_abs + v_a_od + v_a_bunk;
    IF v_a_recorded > 0 THEN
        v_a_pct := ROUND(((v_a_pres + v_a_od)::NUMERIC / v_a_recorded::NUMERIC) * 100.0, 2);
    ELSE
        v_a_pct := 0.00;
    END IF;

    -- Determine status label
    IF p_report_type = 'final' OR (v_a_session IS NOT NULL AND v_a_unmarked = 0 AND v_m_unmarked = 0) THEN
        v_status_label := 'FINAL';
    ELSE
        v_status_label := 'PRELIMINARY';
    END IF;

    v_now_ist_str := TO_CHAR(NOW() AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') || ' IST';

    -- Format exactly according to Section 5 specification
    v_msg := 'STUDENT ATTENDANCE REPORT' || E'\n\n' ||
             'Date: ' || TO_CHAR(p_date, 'YYYY-MM-DD') || E'\n' ||
             'Department: ' || v_class.department || E'\n' ||
             'Class: ' || v_class.class_name || E'\n' ||
             'Academic Year: ' || v_class.academic_year || E'\n\n' ||
             'MORNING ATTENDANCE' || E'\n' ||
             'Total Students: ' || v_total_enrolled || E'\n' ||
             'Present: ' || v_m_pres || E'\n' ||
             'Absent: ' || v_m_abs || E'\n' ||
             'OD: ' || v_m_od || E'\n' ||
             'Not Marked: ' || v_m_unmarked || E'\n' ||
             'Attendance: ' || TRIM(TO_CHAR(v_m_pct, '990.99')) || '%' || E'\n\n' ||
             'AFTERNOON ATTENDANCE' || E'\n' ||
             'Total Students: ' || v_total_enrolled || E'\n' ||
             'Present: ' || v_a_pres || E'\n' ||
             'Absent: ' || v_a_abs || E'\n' ||
             'OD: ' || v_a_od || E'\n' ||
             'Bunk: ' || v_a_bunk || E'\n' ||
             'Not Marked: ' || v_a_unmarked || E'\n' ||
             'Attendance: ' || TRIM(TO_CHAR(v_a_pct, '990.99')) || '%' || E'\n\n' ||
             'SESSION COMPARISON' || E'\n' ||
             'Present in Both Sessions: ' || v_both_pres || E'\n' ||
             'Morning Present → Afternoon Absent: ' || v_m_pres_a_abs || E'\n' ||
             'Afternoon Bunk: ' || v_a_bunk_cnt || E'\n\n' ||
             'Report Status: ' || v_status_label || E'\n\n' ||
             'Generated At: ' || v_now_ist_str || E'\n\n' ||
             'Student Attendance Management System';

    -- Upsert into attendance_reports table
    INSERT INTO attendance_reports (
        report_date,
        class_id,
        report_type,
        session_type,
        total_enrolled,
        morning_present,
        morning_absent,
        morning_od,
        morning_unmarked,
        morning_percentage,
        afternoon_present,
        afternoon_absent,
        afternoon_od,
        afternoon_bunk,
        afternoon_unmarked,
        afternoon_percentage,
        present_both,
        present_morning_absent_afternoon,
        afternoon_bunk_count,
        status,
        report_message_text,
        generated_at
    ) VALUES (
        p_date,
        p_class_id,
        LOWER(v_status_label),
        'combined',
        v_total_enrolled,
        v_m_pres,
        v_m_abs,
        v_m_od,
        v_m_unmarked,
        v_m_pct,
        v_a_pres,
        v_a_abs,
        v_a_od,
        v_a_bunk,
        v_a_unmarked,
        v_a_pct,
        v_both_pres,
        v_m_pres_a_abs,
        v_a_bunk_cnt,
        'generated',
        v_msg,
        NOW()
    )
    ON CONFLICT (report_date, class_id, report_type)
    DO UPDATE SET
        total_enrolled = EXCLUDED.total_enrolled,
        morning_present = EXCLUDED.morning_present,
        morning_absent = EXCLUDED.morning_absent,
        morning_od = EXCLUDED.morning_od,
        morning_unmarked = EXCLUDED.morning_unmarked,
        morning_percentage = EXCLUDED.morning_percentage,
        afternoon_present = EXCLUDED.afternoon_present,
        afternoon_absent = EXCLUDED.afternoon_absent,
        afternoon_od = EXCLUDED.afternoon_od,
        afternoon_bunk = EXCLUDED.afternoon_bunk,
        afternoon_unmarked = EXCLUDED.afternoon_unmarked,
        afternoon_percentage = EXCLUDED.afternoon_percentage,
        present_both = EXCLUDED.present_both,
        present_morning_absent_afternoon = EXCLUDED.present_morning_absent_afternoon,
        afternoon_bunk_count = EXCLUDED.afternoon_bunk_count,
        report_message_text = EXCLUDED.report_message_text,
        generated_at = NOW()
    RETURNING id INTO v_report_id;

    RETURN jsonb_build_object(
        'report_id', v_report_id,
        'class_id', p_class_id,
        'class_name', v_class.class_name,
        'department', v_class.department,
        'academic_year', v_class.academic_year,
        'report_date', p_date,
        'report_type', LOWER(v_status_label),
        'total_enrolled', v_total_enrolled,
        'morning_present', v_m_pres,
        'morning_absent', v_m_abs,
        'morning_od', v_m_od,
        'morning_unmarked', v_m_unmarked,
        'morning_percentage', v_m_pct,
        'afternoon_present', v_a_pres,
        'afternoon_absent', v_a_abs,
        'afternoon_od', v_a_od,
        'afternoon_bunk', v_a_bunk,
        'afternoon_unmarked', v_a_unmarked,
        'afternoon_percentage', v_a_pct,
        'present_both', v_both_pres,
        'present_morning_absent_afternoon', v_m_pres_a_abs,
        'afternoon_bunk_count', v_a_bunk_cnt,
        'message_text', v_msg
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

