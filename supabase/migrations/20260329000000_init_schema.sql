-- Student Attendance Management System Schema
-- Migration: 20260329000000_init_schema.sql

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create Enums
CREATE TYPE user_role AS ENUM ('admin', 'coordinator', 'staff');
CREATE TYPE session_type_enum AS ENUM ('morning', 'afternoon');
CREATE TYPE session_status_enum AS ENUM ('open', 'closed');
CREATE TYPE attendance_status_enum AS ENUM ('present', 'absent');
CREATE TYPE report_type_enum AS ENUM ('preliminary', 'final');

-- 2. Create Profiles Table (links to Supabase Auth)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'coordinator',
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Create Classes Table
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_name TEXT NOT NULL,
    department TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_class_dept_year UNIQUE (class_name, department, academic_year)
);

-- 4. Class Coordinators Mapping
CREATE TABLE class_coordinators (
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    coordinator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, coordinator_id)
);

-- 5. Class Staff Recipients Mapping
CREATE TABLE class_staff (
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, staff_id)
);

-- 6. Students Table
CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    register_number TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Class Enrollments Table
CREATE TABLE class_enrollments (
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, student_id)
);

-- 8. Attendance Sessions Table
CREATE TABLE attendance_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    session_type session_type_enum NOT NULL,
    status session_status_enum NOT NULL DEFAULT 'open',
    opened_by UUID NOT NULL REFERENCES profiles(id),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    CONSTRAINT unique_class_date_session UNIQUE (class_id, attendance_date, session_type)
);

-- 9. Attendance Records Table
CREATE TABLE attendance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    status attendance_status_enum NOT NULL,
    marked_by UUID NOT NULL REFERENCES profiles(id),
    marked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_session_student UNIQUE (session_id, student_id)
);

-- 10. Daily Reports Table
CREATE TABLE daily_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    report_type report_type_enum NOT NULL DEFAULT 'preliminary',
    report_data JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'generated',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_class_daily_report UNIQUE (class_id, attendance_date)
);

-- 11. App Notifications Table
CREATE TABLE app_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    report_id UUID REFERENCES daily_reports(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. Device Tokens Table (FCM)
CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_fcm_token UNIQUE (user_id, fcm_token)
);

-- Create Indexes for performance
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_students_reg ON students(register_number);
CREATE INDEX idx_sessions_class_date ON attendance_sessions(class_id, attendance_date);
CREATE INDEX idx_records_session ON attendance_records(session_id);
CREATE INDEX idx_records_student ON attendance_records(student_id);
CREATE INDEX idx_reports_class_date ON daily_reports(class_id, attendance_date);
CREATE INDEX idx_notifications_recipient ON app_notifications(recipient_id, created_at DESC);

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_coordinators ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Helper Functions for Auth & Roles
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role AS $$
    SELECT role FROM profiles WHERE id = auth.uid() AND active = true;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
    SELECT current_user_role() = 'admin';
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_coordinator_for_class(c_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM class_coordinators
        WHERE class_id = c_id AND coordinator_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_staff_for_class(c_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM class_staff
        WHERE class_id = c_id AND staff_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- RLS POLICIES

-- PROFILES
CREATE POLICY "Public profile reading for authenticated users"
    ON profiles FOR SELECT TO authenticated
    USING (active = true);

CREATE POLICY "Admin full access on profiles"
    ON profiles FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- CLASSES
CREATE POLICY "Admins full control on classes"
    ON classes FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators and staff read assigned classes"
    ON classes FOR SELECT TO authenticated
    USING (
        is_admin() OR
        is_coordinator_for_class(id) OR
        is_staff_for_class(id)
    );

-- CLASS COORDINATORS
CREATE POLICY "Admin full management on class coordinators"
    ON class_coordinators FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators view own class assignments"
    ON class_coordinators FOR SELECT TO authenticated
    USING (coordinator_id = auth.uid() OR is_admin());

-- CLASS STAFF
CREATE POLICY "Admin full management on class staff"
    ON class_staff FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Staff view own class assignments"
    ON class_staff FOR SELECT TO authenticated
    USING (staff_id = auth.uid() OR is_admin());

-- STUDENTS
CREATE POLICY "Admin full management on students"
    ON students FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators and Staff read active students"
    ON students FOR SELECT TO authenticated
    USING (active = true);

-- CLASS ENROLLMENTS
CREATE POLICY "Admin full management on enrollments"
    ON class_enrollments FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators and Staff view enrollments"
    ON class_enrollments FOR SELECT TO authenticated
    USING (
        is_admin() OR
        is_coordinator_for_class(class_id) OR
        is_staff_for_class(class_id)
    );

-- ATTENDANCE SESSIONS
CREATE POLICY "Admin manage sessions"
    ON attendance_sessions FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators manage sessions for their classes"
    ON attendance_sessions FOR ALL TO authenticated
    USING (is_coordinator_for_class(class_id))
    WITH CHECK (is_coordinator_for_class(class_id));

CREATE POLICY "Staff read sessions"
    ON attendance_sessions FOR SELECT TO authenticated
    USING (is_staff_for_class(class_id) OR is_admin());

-- ATTENDANCE RECORDS
CREATE POLICY "Admin manage records"
    ON attendance_records FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators manage attendance records for assigned open sessions"
    ON attendance_records FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM attendance_sessions s
            WHERE s.id = attendance_records.session_id
            AND is_coordinator_for_class(s.class_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM attendance_sessions s
            WHERE s.id = attendance_records.session_id
            AND is_coordinator_for_class(s.class_id)
            AND s.status = 'open'
        )
    );

CREATE POLICY "Staff read attendance records"
    ON attendance_records FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM attendance_sessions s
            WHERE s.id = attendance_records.session_id
            AND (is_staff_for_class(s.class_id) OR is_admin())
        )
    );

-- DAILY REPORTS
CREATE POLICY "Admin and assigned staff read daily reports"
    ON daily_reports FOR SELECT TO authenticated
    USING (
        is_admin() OR
        is_staff_for_class(class_id) OR
        is_coordinator_for_class(class_id)
    );

CREATE POLICY "Admin or system insert/update daily reports"
    ON daily_reports FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- APP NOTIFICATIONS
CREATE POLICY "Users manage own notifications"
    ON app_notifications FOR ALL TO authenticated
    USING (recipient_id = auth.uid())
    WITH CHECK (recipient_id = auth.uid());

-- DEVICE TOKENS
CREATE POLICY "Users manage own device tokens"
    ON device_tokens FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());


-- STORED PROCEDURE FOR REPORT CALCULATION & GENERATION
CREATE OR REPLACE FUNCTION generate_daily_attendance_report(p_class_id UUID, p_date DATE)
RETURNS UUID AS $$
DECLARE
    v_report_id UUID;
    v_total_enrolled INT;
    v_morning_session_id UUID;
    v_afternoon_session_id UUID;
    v_morning_present INT := 0;
    v_morning_absent INT := 0;
    v_afternoon_present INT := 0;
    v_afternoon_absent INT := 0;
    v_both_present INT := 0;
    v_both_absent INT := 0;
    v_morning_p_afternoon_a INT := 0;
    v_morning_a_afternoon_p INT := 0;
    v_incomplete_count INT := 0;
    v_report_type report_type_enum := 'preliminary';
    v_discrepancies JSONB := '[]'::jsonb;
    v_report_payload JSONB;
    v_staff_record RECORD;
BEGIN
    -- 1. Count total active enrolled students
    SELECT COUNT(*) INTO v_total_enrolled
    FROM class_enrollments ce
    JOIN students s ON s.id = ce.student_id
    WHERE ce.class_id = p_class_id AND s.active = true;

    -- 2. Find morning and afternoon session IDs
    SELECT id INTO v_morning_session_id
    FROM attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'morning';

    SELECT id INTO v_afternoon_session_id
    FROM attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'afternoon';

    -- Check if both sessions exist and are closed or explicitly marked
    IF v_morning_session_id IS NOT NULL AND v_afternoon_session_id IS NOT NULL THEN
        v_report_type := 'final';
    END IF;

    -- Calculate attendance statistics & compare sessions student by student
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
        COUNT(*) FILTER (WHERE a_status = 'present') AS a_pres,
        COUNT(*) FILTER (WHERE a_status = 'absent') AS a_abs,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'present') AS b_pres,
        COUNT(*) FILTER (WHERE m_status = 'absent' AND a_status = 'absent') AS b_abs,
        COUNT(*) FILTER (WHERE m_status = 'present' AND a_status = 'absent') AS m_p_a_a,
        COUNT(*) FILTER (WHERE m_status = 'absent' AND a_status = 'present') AS m_a_a_p,
        COUNT(*) FILTER (WHERE m_status IS NULL OR a_status IS NULL) AS inc_cnt,
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'student_id', student_id,
                'register_number', register_number,
                'full_name', full_name,
                'morning_status', m_status,
                'afternoon_status', a_status,
                'discrepancy_type', CASE
                    WHEN m_status = 'present' AND a_status = 'absent' THEN 'Morning Present, Afternoon Absent'
                    WHEN m_status = 'absent' AND a_status = 'present' THEN 'Morning Absent, Afternoon Present'
                    WHEN m_status IS NULL OR a_status IS NULL THEN 'Incomplete Record'
                    ELSE 'Normal'
                END
            )
        ) FILTER (WHERE (m_status = 'present' AND a_status = 'absent') OR (m_status = 'absent' AND a_status = 'present') OR (m_status IS NULL OR a_status IS NULL)), '[]'::jsonb) AS disc_list
    INTO
        v_morning_present, v_morning_absent,
        v_afternoon_present, v_afternoon_absent,
        v_both_present, v_both_absent,
        v_morning_p_afternoon_a, v_morning_a_afternoon_p,
        v_incomplete_count, v_discrepancies
    FROM merged;

    -- Build payload
    v_report_payload := jsonb_build_object(
        'total_enrolled', v_total_enrolled,
        'morning_present', v_morning_present,
        'morning_absent', v_morning_absent,
        'afternoon_present', v_afternoon_present,
        'afternoon_absent', v_afternoon_absent,
        'both_present', v_both_present,
        'both_absent', v_both_absent,
        'morning_present_afternoon_absent', v_morning_p_afternoon_a,
        'morning_absent_afternoon_present', v_morning_a_afternoon_p,
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

    -- Generate in-app notifications for assigned staff and administrators
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
            'Report generated for class date ' || p_date || '. Total: ' || v_total_enrolled || ', M.Pres: ' || v_morning_present || ', A.Pres: ' || v_afternoon_present
        );
    END LOOP;

    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
