-- Migration: 20261013030000_automatic_admin_whatsapp_reports.sql
-- Description: Configures automated coordinator-to-administrator WhatsApp attendance reporting workflow.
-- At 2:00 PM IST (14:00 Asia/Kolkata), backend generates consolidated report for all active classes
-- and dispatches it directly to the configured Administrator WhatsApp number.

-- 1. Extend whatsapp_config with Administrator Destination & Reporting Preferences
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS admin_name TEXT NOT NULL DEFAULT 'Dr. Ramesh Sharma (Administrator)';
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS admin_phone TEXT NOT NULL DEFAULT '+919876543200';
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS report_scope TEXT NOT NULL DEFAULT 'all'; -- 'all' or 'selected'
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS selected_class_ids JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS include_comparisons BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS last_report_generated_at TIMESTAMPTZ;
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS last_send_attempt_at TIMESTAMPTZ;
ALTER TABLE whatsapp_config ADD COLUMN IF NOT EXISTS last_delivery_status TEXT DEFAULT 'Delivered';

-- 2. Extend whatsapp_notification_logs with automated delivery monitoring fields
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS classes_included TEXT;
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS scheduled_time TEXT DEFAULT '14:00 IST';
ALTER TABLE whatsapp_notification_logs ADD COLUMN IF NOT EXISTS actual_send_time TIMESTAMPTZ;

-- 3. Stored Procedure: Generate Consolidated Daily Attendance Report for All Active Classes
CREATE OR REPLACE FUNCTION generate_consolidated_daily_report(
    p_date DATE DEFAULT CURRENT_DATE,
    p_admin_phone TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_config RECORD;
    v_class RECORD;
    v_target_phone TEXT;
    v_now_ist_str TEXT;
    v_msg TEXT := '';
    v_all_afternoon_complete BOOLEAN := true;
    v_class_count INT := 0;
    v_report_status_text TEXT;
    v_outbox_id UUID;
    v_log_id UUID;
    v_idempotency_key TEXT;
    v_class_names TEXT := '';

    -- Per-class metrics
    v_total_enrolled INT;
    v_m_session RECORD;
    v_a_session RECORD;
    v_m_pres INT;
    v_m_abs INT;
    v_m_od INT;
    v_m_unmarked INT;
    v_m_pct NUMERIC(5,1);
    v_m_status TEXT;

    v_a_pres INT;
    v_a_abs INT;
    v_a_od INT;
    v_a_bunk INT;
    v_a_unmarked INT;
    v_a_pct NUMERIC(5,1);
    v_a_status TEXT;

    v_both_pres INT;
    v_m_pres_a_abs INT;
    v_m_pres_a_od INT;
    v_m_pres_a_bunk INT;
    v_other_changes INT;
    v_comp_incomplete TEXT;
BEGIN
    -- Fetch configuration
    SELECT * INTO v_config FROM whatsapp_config LIMIT 1;
    v_target_phone := COALESCE(p_admin_phone, v_config.admin_phone, '+919876543200');
    v_now_ist_str := TO_CHAR(NOW() AT TIME ZONE 'Asia/Kolkata', 'HH12:MI AM') || ' IST';

    -- Header per Section 4 specification
    v_msg := 'STUDENT ATTENDANCE MANAGEMENT SYSTEM' || E'\n\n' ||
             'Date: ' || TO_CHAR(p_date, 'YYYY-MM-DD') || E'\n' ||
             'Generated At: ' || v_now_ist_str || E'\n\n';

    -- Iterate active classes
    FOR v_class IN
        SELECT id, class_name, department, academic_year
        FROM classes
        WHERE active = true
        ORDER BY class_name ASC
    LOOP
        v_class_count := v_class_count + 1;
        IF v_class_names = '' THEN
            v_class_names := v_class.class_name;
        ELSE
            v_class_names := v_class_names || ', ' || v_class.class_name;
        END IF;

        -- Count enrolled students
        SELECT COUNT(*) INTO v_total_enrolled
        FROM class_enrollments ce
        JOIN students s ON s.id = ce.student_id
        WHERE ce.class_id = v_class.id AND s.active = true;

        -- Sessions
        SELECT * INTO v_m_session FROM attendance_sessions
        WHERE class_id = v_class.id AND attendance_date = p_date AND session_type = 'morning' LIMIT 1;

        SELECT * INTO v_a_session FROM attendance_sessions
        WHERE class_id = v_class.id AND attendance_date = p_date AND session_type = 'afternoon' LIMIT 1;

        -- Morning Counts
        SELECT
            COUNT(*) FILTER (WHERE r.status = 'present'),
            COUNT(*) FILTER (WHERE r.status = 'absent'),
            COUNT(*) FILTER (WHERE r.status = 'od')
        INTO v_m_pres, v_m_abs, v_m_od
        FROM attendance_records r
        WHERE r.session_id = v_m_session.id;

        v_m_pres := COALESCE(v_m_pres, 0);
        v_m_abs := COALESCE(v_m_abs, 0);
        v_m_od := COALESCE(v_m_od, 0);
        v_m_unmarked := GREATEST(0, v_total_enrolled - (v_m_pres + v_m_abs + v_m_od));

        IF (v_m_pres + v_m_abs + v_m_od) > 0 THEN
            v_m_pct := ROUND(((v_m_pres + v_m_od)::NUMERIC / (v_m_pres + v_m_abs + v_m_od)::NUMERIC) * 100.0, 1);
        ELSE
            v_m_pct := 0.0;
        END IF;

        IF v_m_session IS NOT NULL AND v_m_unmarked = 0 AND (v_m_pres + v_m_abs + v_m_od) > 0 THEN
            v_m_status := 'Completed';
        ELSE
            v_m_status := 'Incomplete';
        END IF;

        -- Afternoon Counts
        SELECT
            COUNT(*) FILTER (WHERE r.status = 'present'),
            COUNT(*) FILTER (WHERE r.status = 'absent'),
            COUNT(*) FILTER (WHERE r.status = 'od'),
            COUNT(*) FILTER (WHERE r.status = 'bunk')
        INTO v_a_pres, v_a_abs, v_a_od, v_a_bunk
        FROM attendance_records r
        WHERE r.session_id = v_a_session.id;

        v_a_pres := COALESCE(v_a_pres, 0);
        v_a_abs := COALESCE(v_a_abs, 0);
        v_a_od := COALESCE(v_a_od, 0);
        v_a_bunk := COALESCE(v_a_bunk, 0);
        v_a_unmarked := GREATEST(0, v_total_enrolled - (v_a_pres + v_a_abs + v_a_od + v_a_bunk));

        IF (v_a_pres + v_a_abs + v_a_od + v_a_bunk) > 0 THEN
            v_a_pct := ROUND(((v_a_pres + v_a_od)::NUMERIC / (v_a_pres + v_a_abs + v_a_od + v_a_bunk)::NUMERIC) * 100.0, 1);
        ELSE
            v_a_pct := 0.0;
        END IF;

        IF v_a_session IS NOT NULL AND v_a_unmarked = 0 AND (v_a_pres + v_a_abs + v_a_od + v_a_bunk) > 0 THEN
            v_a_status := 'Completed';
        ELSE
            v_a_status := 'Incomplete';
            v_all_afternoon_complete := false;
        END IF;

        -- Session Comparisons
        WITH joined_records AS (
            SELECT
                ce.student_id,
                mr.status AS m_status,
                ar.status AS a_status
            FROM class_enrollments ce
            JOIN students s ON s.id = ce.student_id AND s.active = true
            LEFT JOIN attendance_records mr ON mr.session_id = v_m_session.id AND mr.student_id = ce.student_id
            LEFT JOIN attendance_records ar ON ar.session_id = v_a_session.id AND ar.student_id = ce.student_id
            WHERE ce.class_id = v_class.id
        )
        SELECT
            COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'present'),
            COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'absent'),
            COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'od'),
            COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'bunk'),
            COUNT(*) FILTER (WHERE m_status IS NOT NULL AND a_status IS NOT NULL AND m_status != a_status AND NOT (m_status = 'present' AND a_status IN ('absent', 'od', 'bunk')))
        INTO v_both_pres, v_m_pres_a_abs, v_m_pres_a_od, v_m_pres_a_bunk, v_other_changes
        FROM joined_records;

        v_both_pres := COALESCE(v_both_pres, 0);
        v_m_pres_a_abs := COALESCE(v_m_pres_a_abs, 0);
        v_m_pres_a_od := COALESCE(v_m_pres_a_od, 0);
        v_m_pres_a_bunk := COALESCE(v_m_pres_a_bunk, 0);
        v_other_changes := COALESCE(v_other_changes, 0);

        IF v_m_status = 'Completed' AND v_a_status = 'Completed' THEN
            v_comp_incomplete := 'No';
        ELSE
            v_comp_incomplete := 'Yes';
        END IF;

        -- Append Class Section per Section 4
        v_msg := v_msg ||
                 'Class: ' || v_class.class_name || E'\n' ||
                 'Department: ' || v_class.department || E'\n' ||
                 'Academic Year: ' || v_class.academic_year || E'\n' ||
                 'Total Enrolled Students: ' || v_total_enrolled || E'\n\n' ||
                 'MORNING ATTENDANCE' || E'\n' ||
                 'Present: ' || v_m_pres || E'\n' ||
                 'Absent: ' || v_m_abs || E'\n' ||
                 'OD: ' || v_m_od || E'\n' ||
                 'Not Marked: ' || v_m_unmarked || E'\n' ||
                 'Attendance Percentage: ' || TRIM(TO_CHAR(v_m_pct, '990.0')) || '%' || E'\n' ||
                 'Session Status: ' || v_m_status || E'\n\n' ||
                 'AFTERNOON ATTENDANCE' || E'\n' ||
                 'Present: ' || v_a_pres || E'\n' ||
                 'Absent: ' || v_a_abs || E'\n' ||
                 'OD: ' || v_a_od || E'\n' ||
                 'Bunk: ' || v_a_bunk || E'\n' ||
                 'Not Marked: ' || v_a_unmarked || E'\n' ||
                 'Attendance Percentage: ' || TRIM(TO_CHAR(v_a_pct, '990.0')) || '%' || E'\n' ||
                 'Session Status: ' || v_a_status || E'\n\n' ||
                 'SESSION COMPARISON' || E'\n' ||
                 'Present in Both Sessions: ' || v_both_pres || E'\n' ||
                 'Morning Present → Afternoon Absent: ' || v_m_pres_a_abs || E'\n' ||
                 'Morning Present → Afternoon OD: ' || v_m_pres_a_od || E'\n' ||
                 'Morning Present → Afternoon Bunk: ' || v_m_pres_a_bunk || E'\n' ||
                 'Other Attendance Changes: ' || v_other_changes || E'\n' ||
                 'Comparison Incomplete: ' || v_comp_incomplete || E'\n\n' ||
                 '----------------------------------------' || E'\n\n';
    END LOOP;

    -- Overall Status Banner per Section 4
    IF v_all_afternoon_complete AND v_class_count > 0 THEN
        v_report_status_text := 'FINAL REPORT — BOTH SESSIONS COMPLETE';
    ELSE
        v_report_status_text := 'PRELIMINARY REPORT — AFTERNOON ATTENDANCE INCOMPLETE';
    END IF;

    v_msg := v_msg ||
             'REPORT STATUS: ' || v_report_status_text || E'\n' ||
             'Destination: Administrator (' || v_target_phone || E')\n\n' ||
             'Student Attendance Management System';

    -- Deterministic idempotency key: rpt_consolidated_{date}_{status}
    v_idempotency_key := 'rpt_admin_consolidated_' || TO_CHAR(p_date, 'YYYYMMDD') || '_' || CASE WHEN v_all_afternoon_complete THEN 'final' ELSE 'prelim' END;

    -- Insert into outbox if not duplicate
    v_outbox_id := gen_random_uuid();
    v_log_id := gen_random_uuid();

    INSERT INTO whatsapp_outbox (
        id,
        notification_type,
        recipient_phone,
        recipient_name,
        recipient_role,
        template_name,
        template_parameters,
        payload,
        status,
        idempotency_key,
        created_at
    ) VALUES (
        v_outbox_id,
        'attendance_report',
        v_target_phone,
        v_config.admin_name,
        'Administrator',
        'attendance_daily_report',
        jsonb_build_array(v_msg),
        jsonb_build_object(
            'report_date', p_date,
            'report_status', v_report_status_text,
            'message_text', v_msg,
            'classes_included', v_class_names
        ),
        'queued',
        v_idempotency_key,
        NOW()
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    -- Insert into delivery logs
    INSERT INTO whatsapp_notification_logs (
        id,
        outbox_id,
        report_date,
        report_type_label,
        notification_type,
        recipient_phone,
        recipient_name,
        recipient_role,
        classes_included,
        scheduled_time,
        actual_send_time,
        status,
        created_at
    ) VALUES (
        v_log_id,
        v_outbox_id,
        p_date,
        v_report_status_text,
        'attendance_report',
        v_target_phone,
        v_config.admin_name,
        'Administrator',
        v_class_names,
        '14:00 IST',
        NOW(),
        'queued',
        NOW()
    ) ON CONFLICT DO NOTHING;

    -- Update config status tracking
    UPDATE whatsapp_config
    SET last_report_generated_at = NOW(),
        last_send_attempt_at = NOW(),
        last_delivery_status = 'Queued for Delivery'
    WHERE id = v_config.id;

    RETURN jsonb_build_object(
        'success', true,
        'report_date', p_date,
        'report_status', v_report_status_text,
        'recipient_phone', v_target_phone,
        'classes_count', v_class_count,
        'classes_included', v_class_names,
        'message_text', v_msg,
        'outbox_id', v_outbox_id,
        'log_id', v_log_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Automate daily 2:00 PM IST (14:00 IST = 08:30 UTC) pg_cron invocation
-- SELECT cron.schedule('daily_2pm_ist_admin_attendance_report', '30 8 * * *', 'SELECT generate_consolidated_daily_report();');

