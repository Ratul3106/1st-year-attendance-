-- ==============================================================================
-- Student Attendance Management System - Consolidated Production Schema
-- Compatible with PostgreSQL 15+ & Supabase Database
-- Includes: Auth Hooks, Profiles, Roles, Classes, Students, Enrollments,
--           Attendance Sessions & Records (Present, Absent, OD, Bunk),
--           Automated Reports, WhatsApp Outbox, Recipient Routing, RLS & Seeds.
-- ==============================================================================

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Create Enums Safely
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'coordinator', 'staff');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE session_type_enum AS ENUM ('morning', 'afternoon');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE session_status_enum AS ENUM ('open', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE attendance_status_enum AS ENUM ('present', 'absent', 'od', 'bunk');
EXCEPTION WHEN duplicate_object THEN
    ALTER TYPE attendance_status_enum ADD VALUE IF NOT EXISTS 'od';
    ALTER TYPE attendance_status_enum ADD VALUE IF NOT EXISTS 'bunk';
END $$;

DO $$ BEGIN
    CREATE TYPE report_type_enum AS ENUM ('preliminary', 'final');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE whatsapp_delivery_status AS ENUM ('queued', 'processing', 'sent', 'delivered', 'read', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE whatsapp_notification_type AS ENUM (
        'immediate_absence',
        'repeated_absence_summary',
        'manual_alert',
        'daily_report_preliminary',
        'daily_report_final',
        'attendance_report'
    );
EXCEPTION WHEN duplicate_object THEN
    ALTER TYPE whatsapp_notification_type ADD VALUE IF NOT EXISTS 'daily_report_preliminary';
    ALTER TYPE whatsapp_notification_type ADD VALUE IF NOT EXISTS 'daily_report_final';
    ALTER TYPE whatsapp_notification_type ADD VALUE IF NOT EXISTS 'attendance_report';
END $$;

-- 3. Profiles Table (Linked to Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'coordinator',
    email TEXT,
    phone_number TEXT,
    designation TEXT,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure email column exists on existing profile tables
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Pre-authorized assignments by admin (invitations/access grants by email)
CREATE TABLE IF NOT EXISTS public.authorized_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    full_name TEXT,
    role user_role NOT NULL,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_authorized_email_class_role UNIQUE (email, class_id, role)
);

-- Automatic Auth Hook: Auto-create Profile when a new user signs up in Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_role public.user_role := 'coordinator'::public.user_role;
    v_raw_role TEXT;
    v_full_name TEXT;
    v_auth_record RECORD;
BEGIN
    -- Extract full name safely
    v_full_name := COALESCE(
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'name',
        split_part(COALESCE(new.email, 'User'), '@', 1)
    );

    -- Check if this email was pre-authorized by an administrator
    SELECT * INTO v_auth_record
    FROM public.authorized_assignments
    WHERE LOWER(email) = LOWER(new.email)
    LIMIT 1;

    IF v_auth_record.role IS NOT NULL THEN
        v_role := v_auth_record.role;
    ELSE
        -- Extract and validate role safely from metadata
        v_raw_role := LOWER(COALESCE(new.raw_user_meta_data->>'role', ''));
        IF v_raw_role = 'admin' THEN
            v_role := 'admin'::public.user_role;
        ELSIF v_raw_role = 'staff' THEN
            v_role := 'staff'::public.user_role;
        ELSE
            v_role := 'coordinator'::public.user_role;
        END IF;
    END IF;

    -- Insert or update profile including verified email
    INSERT INTO public.profiles (id, full_name, role, email, phone_number, designation, active)
    VALUES (
        new.id,
        v_full_name,
        v_role,
        LOWER(new.email),
        new.raw_user_meta_data->>'phone_number',
        new.raw_user_meta_data->>'designation',
        true
    )
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        email = COALESCE(EXCLUDED.email, public.profiles.email),
        phone_number = COALESCE(EXCLUDED.phone_number, public.profiles.phone_number),
        designation = COALESCE(EXCLUDED.designation, public.profiles.designation);

    -- Automatically fulfill any pending authorized class assignments for this email
    FOR v_auth_record IN
        SELECT class_id, role FROM public.authorized_assignments WHERE LOWER(email) = LOWER(new.email)
    LOOP
        IF v_auth_record.role = 'coordinator' THEN
            INSERT INTO public.class_coordinators (class_id, coordinator_id)
            VALUES (v_auth_record.class_id, new.id)
            ON CONFLICT (class_id, coordinator_id) DO NOTHING;
        ELSIF v_auth_record.role = 'staff' THEN
            INSERT INTO public.class_staff (class_id, staff_id)
            VALUES (v_auth_record.class_id, new.id)
            ON CONFLICT (class_id, staff_id) DO NOTHING;
        END IF;
    END LOOP;

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    -- Fallback: Ensure auth user creation in Supabase never fails
    RAISE WARNING 'handle_new_user trigger note: %', SQLERRM;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Classes Table
CREATE TABLE IF NOT EXISTS public.classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_name TEXT NOT NULL,
    department TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_class_dept_year UNIQUE (class_name, department, academic_year)
);

-- 5. Class Coordinators & Staff Mapping Tables
CREATE TABLE IF NOT EXISTS public.class_coordinators (
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    coordinator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, coordinator_id)
);

CREATE TABLE IF NOT EXISTS public.class_staff (
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, staff_id)
);

-- 6. Students Table
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    register_number TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Class Enrollments Table
CREATE TABLE IF NOT EXISTS public.class_enrollments (
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, student_id)
);

-- 8. Attendance Sessions Table
CREATE TABLE IF NOT EXISTS public.attendance_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    session_type session_type_enum NOT NULL,
    status session_status_enum NOT NULL DEFAULT 'open',
    opened_by UUID NOT NULL REFERENCES public.profiles(id),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    CONSTRAINT unique_class_date_session UNIQUE (class_id, attendance_date, session_type)
);

-- 9. Attendance Records Table (Composite unique key on session_id, student_id prevents duplication)
CREATE TABLE IF NOT EXISTS public.attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.attendance_sessions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    status attendance_status_enum NOT NULL,
    marked_by UUID NOT NULL REFERENCES public.profiles(id),
    marked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_session_student UNIQUE (session_id, student_id)
);

-- 10. Daily Reports Table
CREATE TABLE IF NOT EXISTS public.daily_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    report_type report_type_enum NOT NULL DEFAULT 'preliminary',
    report_data JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'generated',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_class_daily_report UNIQUE (class_id, attendance_date)
);

-- 11. Attendance Reports Historical Cache Table
CREATE TABLE IF NOT EXISTS public.attendance_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_date DATE NOT NULL,
    class_id UUID NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
    report_type TEXT NOT NULL DEFAULT 'preliminary',
    session_type TEXT NOT NULL DEFAULT 'combined',
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
    status TEXT NOT NULL DEFAULT 'generated',
    report_message_text TEXT NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_attendance_report_per_class_type UNIQUE (report_date, class_id, report_type)
);

-- 12. App Notifications Table
CREATE TABLE IF NOT EXISTS public.app_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    report_id UUID REFERENCES public.daily_reports(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. Device Tokens Table (FCM)
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_fcm_token UNIQUE (user_id, fcm_token)
);

-- 14. WhatsApp Configuration Table
CREATE TABLE IF NOT EXISTS public.whatsapp_config (
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
    admin_name TEXT NOT NULL DEFAULT 'Dr. Ramesh Sharma (Administrator)',
    admin_phone TEXT NOT NULL DEFAULT '+919876543200',
    report_scope TEXT NOT NULL DEFAULT 'all',
    selected_class_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    include_comparisons BOOLEAN NOT NULL DEFAULT true,
    absence_threshold INT NOT NULL DEFAULT 3,
    reporting_window_days INT NOT NULL DEFAULT 7,
    api_status TEXT NOT NULL DEFAULT 'configured',
    last_report_generated_at TIMESTAMPTZ,
    last_send_attempt_at TIMESTAMPTZ,
    last_delivery_status TEXT DEFAULT 'Delivered',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fallback settings table for compatibility
CREATE TABLE IF NOT EXISTS public.whatsapp_settings (
    id UUID PRIMARY KEY DEFAULT '00000000-0000-0000-0000-000000000001'::uuid,
    immediate_alerts_enabled BOOLEAN NOT NULL DEFAULT true,
    summary_alerts_enabled BOOLEAN NOT NULL DEFAULT true,
    absence_threshold INT NOT NULL DEFAULT 3,
    reporting_window_days INT NOT NULL DEFAULT 7,
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    phone_number_id TEXT NOT NULL DEFAULT '100000000000000',
    api_version TEXT NOT NULL DEFAULT 'v21.0',
    absence_template_name TEXT NOT NULL DEFAULT 'attendance_absence_alert',
    absence_template_lang TEXT NOT NULL DEFAULT 'en_US',
    summary_template_name TEXT NOT NULL DEFAULT 'attendance_repeat_summary',
    summary_template_lang TEXT NOT NULL DEFAULT 'en_US',
    dean_placement_phone TEXT DEFAULT '+919876543200',
    dean_placement_name TEXT DEFAULT 'Dean of Placement and Training',
    additional_recipients JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default configuration
INSERT INTO public.whatsapp_config (id) VALUES ('00000000-0000-0000-0000-000000000001'::uuid) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.whatsapp_settings (id) VALUES ('00000000-0000-0000-0000-000000000001'::uuid) ON CONFLICT (id) DO NOTHING;

-- 15. Authorized Report Recipients Table
CREATE TABLE IF NOT EXISTS public.whatsapp_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    designation TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    report_types TEXT NOT NULL DEFAULT 'both',
    session_preferences TEXT NOT NULL DEFAULT 'combined',
    active BOOLEAN NOT NULL DEFAULT true,
    consent_obtained BOOLEAN NOT NULL DEFAULT true,
    authorized_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.whatsapp_recipient_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES public.whatsapp_recipients(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    all_classes BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recipient_class UNIQUE (recipient_id, class_id)
);

-- 16. WhatsApp Transactional Outbox
CREATE TABLE IF NOT EXISTS public.whatsapp_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_type whatsapp_notification_type NOT NULL DEFAULT 'immediate_absence',
    recipient_phone TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    recipient_role TEXT NOT NULL,
    template_name TEXT NOT NULL,
    template_language TEXT NOT NULL DEFAULT 'en_US',
    template_parameters JSONB NOT NULL DEFAULT '[]'::jsonb,
    payload JSONB NOT NULL,
    status whatsapp_delivery_status NOT NULL DEFAULT 'queued',
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 5,
    next_retry_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    provider_message_id TEXT,
    error_message TEXT,
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. WhatsApp Notification Audit & History Logs
CREATE TABLE IF NOT EXISTS public.whatsapp_notification_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outbox_id UUID REFERENCES public.whatsapp_outbox(id) ON DELETE SET NULL,
    report_id UUID REFERENCES public.attendance_reports(id) ON DELETE SET NULL,
    recipient_id UUID REFERENCES public.whatsapp_recipients(id) ON DELETE SET NULL,
    student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
    class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    session_id UUID REFERENCES public.attendance_sessions(id) ON DELETE SET NULL,
    report_date DATE,
    report_type_label TEXT,
    notification_type whatsapp_notification_type NOT NULL,
    recipient_phone TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    recipient_role TEXT NOT NULL,
    classes_included TEXT,
    scheduled_time TEXT DEFAULT '14:00 IST',
    actual_send_time TIMESTAMPTZ,
    provider_message_id TEXT,
    status whatsapp_delivery_status NOT NULL DEFAULT 'queued',
    error_code TEXT,
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 5,
    next_retry_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 18. WhatsApp Webhook Events (Deduplication)
CREATE TABLE IF NOT EXISTS public.whatsapp_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id TEXT NOT NULL UNIQUE,
    provider_message_id TEXT,
    event_type TEXT NOT NULL,
    recipient_phone TEXT,
    status TEXT,
    error_details JSONB,
    raw_payload JSONB NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 19. Repeated Absence Summaries Table
CREATE TABLE IF NOT EXISTS public.whatsapp_absence_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    summary_period_start DATE NOT NULL,
    summary_period_end DATE NOT NULL,
    rule_version TEXT NOT NULL DEFAULT 'v1',
    recipient_role TEXT NOT NULL,
    recipient_phone TEXT NOT NULL,
    class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE,
    qualifying_count INT NOT NULL,
    qualifying_students JSONB NOT NULL,
    outbox_id UUID REFERENCES public.whatsapp_outbox(id) ON DELETE SET NULL,
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 20. Essential Indexes for High-Traffic Queries
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_students_reg ON public.students(register_number);
CREATE INDEX IF NOT EXISTS idx_sessions_class_date ON public.attendance_sessions(class_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_records_session ON public.attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_records_student ON public.attendance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_queue ON public.whatsapp_outbox(status, next_retry_at) WHERE status IN ('queued', 'processing');
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_wamid ON public.whatsapp_outbox(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_created ON public.whatsapp_notification_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_wamid ON public.whatsapp_notification_logs(provider_message_id);

-- ==============================================================================
-- 21. Row Level Security (RLS) - Explicit Security Policies
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_coordinators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_recipient_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_absence_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.authorized_assignments ENABLE ROW LEVEL SECURITY;

-- Security Helper Functions
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid() AND active = true;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
    SELECT public.current_user_role() = 'admin';
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_coordinator_for_class(c_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.class_coordinators
        WHERE class_id = c_id AND coordinator_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_staff_for_class(c_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.class_staff
        WHERE class_id = c_id AND staff_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- RLS Policies Setup (Safe Drops & Creates)
DROP POLICY IF EXISTS "Public profile reading for authenticated users" ON public.profiles;
CREATE POLICY "Public profile reading for authenticated users" ON public.profiles FOR SELECT TO authenticated USING (active = true);

DROP POLICY IF EXISTS "Admin full access on profiles" ON public.profiles;
CREATE POLICY "Admin full access on profiles" ON public.profiles FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Admins full control on classes" ON public.classes;
CREATE POLICY "Admins full control on classes" ON public.classes FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators and staff read assigned classes" ON public.classes;
CREATE POLICY "Coordinators and staff read assigned classes" ON public.classes FOR SELECT TO authenticated
USING (public.is_admin() OR public.is_coordinator_for_class(id) OR public.is_staff_for_class(id));

DROP POLICY IF EXISTS "Admin full management on class coordinators" ON public.class_coordinators;
CREATE POLICY "Admin full management on class coordinators" ON public.class_coordinators FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators view own class assignments" ON public.class_coordinators;
CREATE POLICY "Coordinators view own class assignments" ON public.class_coordinators FOR SELECT TO authenticated USING (coordinator_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Admin full management on class staff" ON public.class_staff;
CREATE POLICY "Admin full management on class staff" ON public.class_staff FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin full management on authorized_assignments" ON public.authorized_assignments;
CREATE POLICY "Admin full management on authorized_assignments" ON public.authorized_assignments FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Staff view own class assignments" ON public.class_staff;
CREATE POLICY "Staff view own class assignments" ON public.class_staff FOR SELECT TO authenticated USING (staff_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Admin full management on students" ON public.students;
CREATE POLICY "Admin full management on students" ON public.students FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators and Staff read active students" ON public.students;
CREATE POLICY "Coordinators and Staff read active students" ON public.students FOR SELECT TO authenticated USING (active = true);

DROP POLICY IF EXISTS "Admin full management on enrollments" ON public.class_enrollments;
CREATE POLICY "Admin full management on enrollments" ON public.class_enrollments FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators and Staff view enrollments" ON public.class_enrollments;
CREATE POLICY "Coordinators and Staff view enrollments" ON public.class_enrollments FOR SELECT TO authenticated
USING (public.is_admin() OR public.is_coordinator_for_class(class_id) OR public.is_staff_for_class(class_id));

DROP POLICY IF EXISTS "Admin manage sessions" ON public.attendance_sessions;
CREATE POLICY "Admin manage sessions" ON public.attendance_sessions FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators manage sessions for their classes" ON public.attendance_sessions;
CREATE POLICY "Coordinators manage sessions for their classes" ON public.attendance_sessions FOR ALL TO authenticated
USING (public.is_coordinator_for_class(class_id)) WITH CHECK (public.is_coordinator_for_class(class_id));

DROP POLICY IF EXISTS "Staff read sessions" ON public.attendance_sessions;
CREATE POLICY "Staff read sessions" ON public.attendance_sessions FOR SELECT TO authenticated
USING (public.is_staff_for_class(class_id) OR public.is_admin());

DROP POLICY IF EXISTS "Admin manage records" ON public.attendance_records;
CREATE POLICY "Admin manage records" ON public.attendance_records FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators manage attendance records for assigned open sessions" ON public.attendance_records;
CREATE POLICY "Coordinators manage attendance records for assigned open sessions" ON public.attendance_records FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.attendance_sessions s WHERE s.id = attendance_records.session_id AND public.is_coordinator_for_class(s.class_id)))
WITH CHECK (EXISTS (SELECT 1 FROM public.attendance_sessions s WHERE s.id = attendance_records.session_id AND public.is_coordinator_for_class(s.class_id) AND s.status = 'open'));

DROP POLICY IF EXISTS "Staff read attendance records" ON public.attendance_records;
CREATE POLICY "Staff read attendance records" ON public.attendance_records FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM public.attendance_sessions s WHERE s.id = attendance_records.session_id AND (public.is_staff_for_class(s.class_id) OR public.is_admin())));

DROP POLICY IF EXISTS "Admin full access on whatsapp_config" ON public.whatsapp_config;
CREATE POLICY "Admin full access on whatsapp_config" ON public.whatsapp_config FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators read whatsapp_config" ON public.whatsapp_config;
CREATE POLICY "Coordinators read whatsapp_config" ON public.whatsapp_config FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Admin full access on whatsapp_recipients" ON public.whatsapp_recipients;
CREATE POLICY "Admin full access on whatsapp_recipients" ON public.whatsapp_recipients FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Authenticated read whatsapp_recipients" ON public.whatsapp_recipients;
CREATE POLICY "Authenticated read whatsapp_recipients" ON public.whatsapp_recipients FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Admin full access on whatsapp_recipient_classes" ON public.whatsapp_recipient_classes;
CREATE POLICY "Admin full access on whatsapp_recipient_classes" ON public.whatsapp_recipient_classes FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admin full access on whatsapp_outbox" ON public.whatsapp_outbox;
CREATE POLICY "Admin full access on whatsapp_outbox" ON public.whatsapp_outbox FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators insert into outbox" ON public.whatsapp_outbox;
CREATE POLICY "Coordinators insert into outbox" ON public.whatsapp_outbox FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Admin full access on whatsapp_notification_logs" ON public.whatsapp_notification_logs;
CREATE POLICY "Admin full access on whatsapp_notification_logs" ON public.whatsapp_notification_logs FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Coordinators view logs for assigned classes" ON public.whatsapp_notification_logs;
CREATE POLICY "Coordinators view logs for assigned classes" ON public.whatsapp_notification_logs FOR SELECT TO authenticated
USING (public.is_admin() OR (class_id IS NOT NULL AND public.is_coordinator_for_class(class_id)));

DROP POLICY IF EXISTS "Admin full access on attendance_reports" ON public.attendance_reports;
CREATE POLICY "Admin full access on attendance_reports" ON public.attendance_reports FOR ALL TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Staff and coordinators view authorized attendance reports" ON public.attendance_reports;
CREATE POLICY "Staff and coordinators view authorized attendance reports" ON public.attendance_reports FOR SELECT TO authenticated
USING (public.is_admin() OR (class_id IS NOT NULL AND public.is_coordinator_for_class(class_id)));

-- ==============================================================================
-- 22. Stored Procedures: Core Business Logic
-- ==============================================================================

-- Stored Procedure: Generate Class Daily Attendance Report
CREATE OR REPLACE FUNCTION public.generate_daily_attendance_report(p_class_id UUID, p_date DATE)
RETURNS UUID AS $$
DECLARE
    v_report_id UUID;
    v_total_enrolled INT := 0;
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
BEGIN
    SELECT COUNT(*) INTO v_total_enrolled
    FROM public.class_enrollments ce
    JOIN public.students s ON s.id = ce.student_id
    WHERE ce.class_id = p_class_id AND s.active = true;

    SELECT id INTO v_morning_session_id
    FROM public.attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'morning' LIMIT 1;

    SELECT id INTO v_afternoon_session_id
    FROM public.attendance_sessions
    WHERE class_id = p_class_id AND attendance_date = p_date AND session_type = 'afternoon' LIMIT 1;

    IF v_morning_session_id IS NOT NULL AND v_afternoon_session_id IS NOT NULL THEN
        v_report_type := 'final';
    END IF;

    WITH student_list AS (
        SELECT s.id AS student_id, s.register_number, s.full_name
        FROM public.class_enrollments ce
        JOIN public.students s ON s.id = ce.student_id
        WHERE ce.class_id = p_class_id AND s.active = true
    ),
    m_rec AS (
        SELECT student_id, status FROM public.attendance_records WHERE session_id = v_morning_session_id
    ),
    a_rec AS (
        SELECT student_id, status FROM public.attendance_records WHERE session_id = v_afternoon_session_id
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
        COUNT(*) FILTER (WHERE (v_morning_session_id IS NOT NULL AND m_status IS NULL) OR (v_afternoon_session_id IS NOT NULL AND a_status IS NULL)) AS inc_cnt
    INTO
        v_morning_present, v_morning_absent, v_morning_od,
        v_afternoon_present, v_afternoon_absent, v_afternoon_od, v_afternoon_bunk,
        v_both_present, v_both_absent,
        v_morning_p_afternoon_a, v_morning_a_afternoon_p,
        v_morning_p_afternoon_bunk, v_morning_p_afternoon_od, v_morning_od_afternoon_p,
        v_incomplete_count
    FROM merged;

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
        'incomplete_count', v_incomplete_count
    );

    INSERT INTO public.daily_reports (class_id, attendance_date, report_type, report_data, status, generated_at)
    VALUES (p_class_id, p_date, v_report_type, v_report_payload, 'generated', NOW())
    ON CONFLICT (class_id, attendance_date)
    DO UPDATE SET
        report_type = EXCLUDED.report_type,
        report_data = EXCLUDED.report_data,
        status = 'updated',
        generated_at = NOW()
    RETURNING id INTO v_report_id;

    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to Automatically Queue WhatsApp Notification on Student Absence
CREATE OR REPLACE FUNCTION public.trg_attendance_record_whatsapp_func()
RETURNS trigger AS $$
DECLARE
    v_session RECORD;
    v_class RECORD;
    v_student RECORD;
    v_coord RECORD;
    v_config RECORD;
    v_idempotency_key TEXT;
    v_outbox_id UUID;
    v_log_id UUID;
    v_period TEXT;
BEGIN
    IF NEW.status NOT IN ('absent', 'bunk') THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_config FROM public.whatsapp_config LIMIT 1;
    IF v_config IS NULL OR NOT v_config.immediate_alerts_enabled THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_session FROM public.attendance_sessions WHERE id = NEW.session_id;
    SELECT * INTO v_class FROM public.classes WHERE id = v_session.class_id;
    SELECT * INTO v_student FROM public.students WHERE id = NEW.student_id;

    SELECT p.full_name, COALESCE(p.phone_number, '+919876543211') AS phone
    INTO v_coord
    FROM public.class_coordinators cc
    JOIN public.profiles p ON p.id = cc.coordinator_id
    WHERE cc.class_id = v_class.id
    LIMIT 1;

    v_period := CASE WHEN v_session.session_type = 'morning' THEN 'Morning' ELSE 'Afternoon' END;
    v_idempotency_key := 'imm_abs_' || v_session.id || '_' || v_student.id || '_' || NEW.status;

    v_outbox_id := gen_random_uuid();
    v_log_id := gen_random_uuid();

    INSERT INTO public.whatsapp_outbox (
        id, notification_type, recipient_phone, recipient_name, recipient_role,
        template_name, template_language, template_parameters, payload, status, idempotency_key
    ) VALUES (
        v_outbox_id, 'immediate_absence',
        COALESCE(v_coord.phone, '+919876543211'),
        COALESCE(v_coord.full_name, 'Class Advisor'),
        'Class Advisor',
        v_config.absence_template_name,
        v_config.absence_template_lang,
        jsonb_build_array(
            COALESCE(v_coord.full_name, 'Class Advisor'),
            v_student.full_name,
            v_student.register_number,
            v_class.class_name,
            v_session.attendance_date::TEXT,
            v_period,
            'Daily Class Session'
        ),
        jsonb_build_object(
            'session_id', v_session.id,
            'student_id', v_student.id,
            'class_id', v_class.id,
            'attendance_date', v_session.attendance_date,
            'status', NEW.status
        ),
        'queued',
        v_idempotency_key
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    INSERT INTO public.whatsapp_notification_logs (
        id, outbox_id, student_id, class_id, session_id,
        notification_type, recipient_phone, recipient_name, recipient_role, status
    ) VALUES (
        v_log_id, v_outbox_id, v_student.id, v_class.id, v_session.id,
        'immediate_absence',
        COALESCE(v_coord.phone, '+919876543211'),
        COALESCE(v_coord.full_name, 'Class Advisor'),
        'Class Advisor',
        'queued'
    ) ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_attendance_record_whatsapp ON public.attendance_records;
CREATE TRIGGER trg_attendance_record_whatsapp
    AFTER INSERT OR UPDATE ON public.attendance_records
    FOR EACH ROW EXECUTE FUNCTION public.trg_attendance_record_whatsapp_func();

-- Stored Procedure: Claim Batch for Background Outbox Worker
CREATE OR REPLACE FUNCTION public.claim_whatsapp_outbox_batch(p_batch_size INT DEFAULT 20)
RETURNS SETOF public.whatsapp_outbox AS $$
BEGIN
    RETURN QUERY
    WITH claimed AS (
        SELECT id
        FROM public.whatsapp_outbox
        WHERE (
            status = 'queued'
            OR (status = 'failed' AND next_retry_at <= NOW() AND retry_count < max_retries)
            OR (status = 'processing' AND updated_at < NOW() - INTERVAL '5 minutes')
        )
        ORDER BY created_at ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    )
    UPDATE public.whatsapp_outbox o
    SET status = 'processing',
        updated_at = NOW()
    FROM claimed
    WHERE o.id = claimed.id
    RETURNING o.*;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 23. Default Seed Data (Initial Classes & Enrolled Students)
-- ==============================================================================
DO $$
DECLARE
    v_c1 UUID := 'c1000000-0000-0000-0000-000000000001'::uuid;
    v_c2 UUID := 'c2000000-0000-0000-0000-000000000002'::uuid;
    v_c3 UUID := 'c3000000-0000-0000-0000-000000000003'::uuid;
    v_s1 UUID := 'a1000000-0000-0000-0000-000000000001'::uuid;
    v_s2 UUID := 'a2000000-0000-0000-0000-000000000002'::uuid;
    v_s3 UUID := 'a3000000-0000-0000-0000-000000000003'::uuid;
    v_s4 UUID := 'a4000000-0000-0000-0000-000000000004'::uuid;
    v_s5 UUID := 'a5000000-0000-0000-0000-000000000005'::uuid;
    v_s6 UUID := 'a6000000-0000-0000-0000-000000000006'::uuid;
    v_s7 UUID := 'a7000000-0000-0000-0000-000000000007'::uuid;
    v_s8 UUID := 'a8000000-0000-0000-0000-000000000008'::uuid;
    v_s9 UUID := 'a9000000-0000-0000-0000-000000000009'::uuid;
BEGIN
    -- Classes
    INSERT INTO public.classes (id, class_name, department, academic_year, active) VALUES
        (v_c1, '1st Year - CSE (Sec A)', 'Computer Science & Engineering', '2026-2027', true),
        (v_c2, '1st Year - ECE (Sec B)', 'Electronics & Communication', '2026-2027', true),
        (v_c3, '1st Year - MECH (Sec A)', 'Mechanical Engineering', '2026-2027', true)
    ON CONFLICT (id) DO NOTHING;

    -- Students
    INSERT INTO public.students (id, register_number, full_name, active) VALUES
        (v_s1, '26CS001', 'Aarav Patel', true),
        (v_s2, '26CS002', 'Ananya Sharma', true),
        (v_s3, '26CS003', 'Rohan Verma', true),
        (v_s4, '26CS004', 'Sneha Kulkarni', true),
        (v_s5, '26CS005', 'Vikram Aditya', true),
        (v_s6, '26CS006', 'Diya Sen', true),
        (v_s7, '26CS007', 'Karthik Sundaram', true),
        (v_s8, '26CS008', 'Meera Iyer', true),
        (v_s9, '26CS009', 'Rahul Menon', true)
    ON CONFLICT (register_number) DO NOTHING;

    -- Enrollments in 1st Year CSE (Sec A)
    INSERT INTO public.class_enrollments (class_id, student_id) VALUES
        (v_c1, v_s1), (v_c1, v_s2), (v_c1, v_s3), (v_c1, v_s4),
        (v_c1, v_s5), (v_c1, v_s6), (v_c1, v_s7), (v_c1, v_s8), (v_c1, v_s9)
    ON CONFLICT (class_id, student_id) DO NOTHING;

    -- Seed Initial Authorized Recipients
    INSERT INTO public.whatsapp_recipients (name, designation, phone_number, report_types, session_preferences, active)
    VALUES
        ('Prof. Priya Nair', 'Class Coordinator (CSE-A)', '+919876543211', 'both', 'combined', true),
        ('Dr. Ramesh Sharma', 'Dean of Placement & Training', '+919876543200', 'both', 'combined', true),
        ('Dr. K. Sundaram', 'Head of Department (CSE)', '+919876543222', 'final', 'combined', true)
    ON CONFLICT DO NOTHING;
END $$;

