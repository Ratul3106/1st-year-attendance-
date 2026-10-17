-- Migration: 20261013000000_enhance_attendance_statuses_and_scheduler.sql
-- Description: Adds 'od' and 'bunk' statuses, updates comparison engine in database,
-- and provisions 2:00 PM IST preliminary report generator.

-- 1. Extend attendance_status_enum safely
ALTER TYPE attendance_status_enum ADD VALUE IF NOT EXISTS 'od';
ALTER TYPE attendance_status_enum ADD VALUE IF NOT EXISTS 'bunk';

-- 2. Enhanced Stored Procedure for Attendance Calculation with OD, Bunk, and Session Comparison
CREATE OR REPLACE FUNCTION generate_daily_attendance_report(p_class_id UUID, p_date DATE)
RETURNS UUID AS $$
DECLARE
    v_report_id UUID;
    v_total_enrolled INT;
    v_morning_session_id UUID;
    v_afternoon_session_id UUID;
    v_morning_present INT := 0;
    v_morning_absent INT := 0;
    v_morning_od INT := 0;
    v_afternoon_present INT := 0;
    v_afternoon_absent INT := 0;
    v_afternoon_od INT := 0;
    v_afternoon_bunk INT := 0;
    v_both_present INT := 0;
    v_both_absent INT := 0;
    v_morning_p_afternoon_a INT := 0;
    v_morning_a_afternoon_p INT := 0;
    v_morning_p_afternoon_bunk INT := 0;
    v_morning_p_afternoon_od INT := 0;
    v_morning_od_afternoon_p INT := 0;
    v_incomplete_count INT := 0;
    v_report_type report_type_enum := 'preliminary';
    v_discrepancies JSONB := '[]'::jsonb;
    v_report_payload JSONB;
    v_staff_record RECORD;
BEGIN
    -- Count total active enrolled students
    SELECT COUNT(*) INTO v_total_enrolled
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = p_class_id AND s.active = true;

    -- Find morning and afternoon sessions
    SELECT id INTO v_morning_session_id
    FROM attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'morning';

    SELECT id INTO v_afternoon_session_id
    FROM attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'afternoon';

    -- Mark report as final when both sessions exist and are completed
    IF v_morning_session_id IS NOT NULL AND v_afternoon_session_id IS NOT NULL THEN
        v_report_type := 'final';
    END IF;

    -- Compare student attendance session by session
    WITH student_list AS (
        SELECT s.id AS student_id, s.register_number, s.full_name
        FROM class_enrollments ce
        JOIN students s ON s.id = ce.student_id
        WHERE ce.class_id = p_class_id AND s.active = true
    ),
    m_rec AS (
        SELECT student_id, status FROM attendance_records WHERE session_id = v_morning_session_id
    ),
    a_rec AS (
        SELECT student_id, status FROM attendance_records WHERE session_id = v_afternoon_session_id
    ),
    merged AS (
        SELECT
            sl.student_id,
            sl.register_number,
            sl.full_name,
            m.status AS m_status,
            a.status AS a_status
        FROM student_list sl
        LEFT JOIN m_rec m ON m.student_id = sl.student_id
        LEFT JOIN a_rec a ON a.student_id = sl.student_id
    )
    SELECT
        COUNT(*) FILTER (WHERE m_status = 'present') AS m_pres,
        COUNT(*) FILTER (WHERE m_status = 'absent') AS m_abs,
        COUNT(*) FILTER (WHERE m_status = 'od') AS m_od,
        COUNT(*) FILTER (WHERE a_status = 'present') AS a_pres,
        COUNT(*) FILTER (WHERE a_status = 'absent') AS a_abs,
        COUNT(*) FILTER (WHERE a_status = 'od') AS a_od,
        COUNT(*) FILTER (WHERE a_status = 'bunk') AS a_bunk,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'present') AS b_pres,
        COUNT(*) FILTER (WHERE m_status = 'absent' AND a_status = 'absent') AS b_abs,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'absent') AS m_p_a_a,
        COUNT(*) FILTER (WHERE m_status = 'absent' AND a_status = 'present') AS m_a_a_p,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'bunk') AS m_p_a_bunk,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'od') AS m_p_a_od,
        COUNT(*) FILTER (WHERE m_status = 'od' AND a_status = 'present') AS m_od_a_p,
        COUNT(*) FILTER (WHERE (v_morning_session_id IS NOT NULL AND m_status IS NULL) OR (v_afternoon_session_id IS NOT NULL AND a_status IS NULL)) AS inc_cnt,
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'student_id', student_id,
                'register_number', register_number,
                'full_name', full_name,
                'morning_status', m_status,
                'afternoon_status', a_status,
                'discrepancy_type', CASE
                    WHEN m_status = 'present' AND a_status = 'bunk' THEN 'Marked Bunk in the afternoon'
                    WHEN m_status = 'present' AND a_status = 'absent' THEN 'Present in the morning, absent in the afternoon'
                    WHEN m_status = 'present' AND a_status = 'od' THEN 'OD in the afternoon'
                    WHEN m_status = 'absent' AND a_status = 'present' THEN 'Present in the afternoon after morning absent'
                    WHEN m_status = 'od' AND a_status = 'present' THEN 'Present in the afternoon after morning OD'
                    WHEN m_status IS NULL AND a_status IS NOT NULL THEN 'Morning attendance incomplete'
                    WHEN m_status IS NOT NULL AND a_status IS NULL THEN 'Afternoon attendance incomplete'
                    ELSE 'Session Status Shift'
                END
            )
        ) FILTER (WHERE (m_status IS DISTINCT FROM a_status) AND (m_status IS NOT NULL OR a_status IS NOT NULL)), '[]'::jsonb) AS disc_list
    INTO
        v_morning_present, v_morning_absent, v_morning_od,
        v_afternoon_present, v_afternoon_absent, v_afternoon_od, v_afternoon_bunk,
        v_both_present, v_both_absent,
        v_morning_p_afternoon_a, v_morning_a_afternoon_p,
        v_morning_p_afternoon_bunk, v_morning_p_afternoon_od, v_morning_od_afternoon_p,
        v_incomplete_count, v_discrepancies
    FROM merged;

    -- Build structured payload
    v_report_payload := jsonb_build_object(
        'total_enrolled', v_total_enrolled,
        'morning_present', v_morning_present,
        'morning_absent', v_morning_absent,
        'morning_od', v_morning_od,
        'afternoon_present', v_afternoon_present,
        'afternoon_absent', v_afternoon_absent,
        'afternoon_od', v_afternoon_od,
        'afternoon_bunk', v_afternoon_bunk,
        'both_present', v_both_present,
        'both_absent', v_both_absent,
        'morning_present_afternoon_absent', v_morning_p_afternoon_a,
        'morning_absent_afternoon_present', v_morning_a_afternoon_p,
        'morning_present_afternoon_bunk', v_morning_p_afternoon_bunk,
        'morning_present_afternoon_od', v_morning_p_afternoon_od,
        'morning_od_afternoon_present', v_morning_od_afternoon_p,
        'incomplete_count', v_incomplete_count,
        'discrepancies', v_discrepancies
    );

    -- Insert or Update daily report
    INSERT INTO daily_reports (class_id, attendance_date, report_type, report_data, status, generated_at)
    VALUES (p_class_id, p_date, v_report_type, v_report_payload, 'generated', NOW())
    ON CONFLICT (class_id, attendance_date)
    DO UPDATE SET
        report_type = EXCLUDED.report_type,
        report_data = EXCLUDED.report_data,
        status = 'updated',
        generated_at = NOW()
    RETURNING id INTO v_report_id;

    -- Dispatch in-app notifications
    FOR v_staff_record IN
        SELECT DISTINCT p.id
        FROM profiles p
        LEFT JOIN class_staff cs ON cs.staff_id = p.id
        WHERE p.role = 'admin' OR (p.role = 'staff' AND cs.class_id = p_class_id)
    LOOP
        INSERT INTO app_notifications (recipient_id, report_id, title, message)
        VALUES (
            v_staff_record.id,
            v_report_id,
            'Daily Attendance Report (' || v_report_type || ')',
            'Report generated for class date ' || p_date || '. Total: ' || v_total_enrolled || ', M.Pres: ' || v_morning_present || ', A.Pres: ' || v_afternoon_present || ', A.Bunk: ' || v_afternoon_bunk
        );
    END LOOP;

    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Scheduled 2:00 PM IST Preliminary Report Trigger
-- Executes at 14:00 India Standard Time (08:30 UTC)
CREATE OR REPLACE FUNCTION trigger_daily_2pm_ist_reports()
RETURNS VOID AS $$
DECLARE
    v_class_record RECORD;
    v_today DATE := CURRENT_DATE;
BEGIN
    FOR v_class_record IN SELECT id FROM classes WHERE active = true LOOP
        PERFORM generate_daily_attendance_report(v_class_record.id, v_today);
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- In PostgreSQL with pg_cron enabled:
-- SELECT cron.schedule('daily_2pm_ist_report', '30 8 * * *', 'SELECT trigger_daily_2pm_ist_reports();');
