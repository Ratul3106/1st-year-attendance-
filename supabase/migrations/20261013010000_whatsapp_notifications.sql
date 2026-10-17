-- Migration: 20261013010000_whatsapp_notifications.sql
-- Description: Schema for Meta WhatsApp Cloud API automated attendance notifications,
-- transactional outbox, delivery status tracking, webhooks, and repeated-absence summaries.

-- 1. Create Enums for Notification Status & Event Types
DO $$ BEGIN
    CREATE TYPE whatsapp_delivery_status AS ENUM ('queued', 'processing', 'sent', 'delivered', 'read', 'failed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE whatsapp_notification_type AS ENUM ('immediate_absence', 'repeated_absence_summary', 'manual_alert');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Extend Profiles with Contact Details & Staff Designation
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS designation TEXT;

-- 3. WhatsApp Configuration Table (College-wide settings)
CREATE TABLE IF NOT EXISTS whatsapp_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    dean_placement_phone TEXT,
    dean_placement_name TEXT DEFAULT 'Dean of Placement and Training',
    additional_recipients JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default settings row if absent
INSERT INTO whatsapp_settings (
    id,
    immediate_alerts_enabled,
    summary_alerts_enabled,
    absence_threshold,
    reporting_window_days,
    timezone,
    phone_number_id,
    absence_template_name,
    summary_template_name,
    dean_placement_phone
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    true,
    true,
    3,
    7,
    'Asia/Kolkata',
    '100000000000000',
    'attendance_absence_alert',
    'attendance_repeat_summary',
    '+919876543200'
) ON CONFLICT (id) DO NOTHING;

-- 4. WhatsApp Transactional Outbox (Guarantees no lost messages even if Meta API is down)
CREATE TABLE IF NOT EXISTS whatsapp_outbox (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- 5. WhatsApp Notification Audit & History Logs
CREATE TABLE IF NOT EXISTS whatsapp_notification_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outbox_id UUID REFERENCES whatsapp_outbox(id) ON DELETE SET NULL,
    student_id UUID REFERENCES students(id) ON DELETE SET NULL,
    class_id UUID REFERENCES classes(id) ON DELETE SET NULL,
    session_id UUID REFERENCES attendance_sessions(id) ON DELETE SET NULL,
    notification_type whatsapp_notification_type NOT NULL,
    recipient_phone TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    recipient_role TEXT NOT NULL,
    provider_message_id TEXT,
    status whatsapp_delivery_status NOT NULL DEFAULT 'queued',
    error_code TEXT,
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. WhatsApp Webhook Events (Deduplication and traceability)
CREATE TABLE IF NOT EXISTS whatsapp_webhook_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id TEXT NOT NULL UNIQUE,
    provider_message_id TEXT,
    event_type TEXT NOT NULL,
    recipient_phone TEXT,
    status TEXT,
    error_details JSONB,
    raw_payload JSONB NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Repeated-Absence Summaries Record (Idempotent tracking of scheduled runs)
CREATE TABLE IF NOT EXISTS whatsapp_absence_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    summary_period_start DATE NOT NULL,
    summary_period_end DATE NOT NULL,
    rule_version TEXT NOT NULL DEFAULT 'v1',
    recipient_role TEXT NOT NULL,
    recipient_phone TEXT NOT NULL,
    class_id UUID REFERENCES classes(id) ON DELETE CASCADE,
    qualifying_count INT NOT NULL,
    qualifying_students JSONB NOT NULL,
    outbox_id UUID REFERENCES whatsapp_outbox(id) ON DELETE SET NULL,
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Indexes for outbox queue processing, webhook lookup, and audit log queries
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_queue ON whatsapp_outbox(status, next_retry_at) WHERE status IN ('queued', 'processing');
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_wamid ON whatsapp_outbox(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_class_date ON whatsapp_notification_logs(class_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_student ON whatsapp_notification_logs(student_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_logs_wamid ON whatsapp_notification_logs(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_summaries_period ON whatsapp_absence_summaries(summary_period_start, summary_period_end, class_id);

-- 9. Row Level Security (RLS)
ALTER TABLE whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_absence_summaries ENABLE ROW LEVEL SECURITY;

-- Admins have full access to WhatsApp settings and logs
CREATE POLICY "Admins full management on whatsapp_settings"
    ON whatsapp_settings FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Authenticated users view whatsapp_settings"
    ON whatsapp_settings FOR SELECT TO authenticated
    USING (is_admin());

CREATE POLICY "Admins full access on whatsapp_outbox"
    ON whatsapp_outbox FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins full access on whatsapp_notification_logs"
    ON whatsapp_notification_logs FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Coordinators view logs for assigned classes"
    ON whatsapp_notification_logs FOR SELECT TO authenticated
    USING (
        is_admin() OR
        (class_id IS NOT NULL AND is_coordinator_for_class(class_id))
    );

CREATE POLICY "Admins full access on whatsapp_webhook_events"
    ON whatsapp_webhook_events FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

CREATE POLICY "Admins full access on whatsapp_absence_summaries"
    ON whatsapp_absence_summaries FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- 10. Stored Procedure: Queue Immediate Absence Notification
CREATE OR REPLACE FUNCTION queue_immediate_absence_notification(
    p_record_id UUID,
    p_marked_by UUID
)
RETURNS VOID AS $$
DECLARE
    v_record RECORD;
    v_session RECORD;
    v_class RECORD;
    v_student RECORD;
    v_coord RECORD;
    v_settings RECORD;
    v_idempotency_key TEXT;
    v_advisor_phone TEXT;
    v_advisor_name TEXT;
    v_outbox_id UUID;
BEGIN
    -- Fetch settings
    SELECT * INTO v_settings FROM whatsapp_settings LIMIT 1;
    IF v_settings IS NULL OR NOT v_settings.immediate_alerts_enabled THEN
        RETURN;
    END IF;

    -- Fetch attendance record
    SELECT * INTO v_record FROM attendance_records WHERE id = p_record_id;
    IF v_record IS NULL OR v_record.status NOT IN ('absent', 'bunk') THEN
        RETURN;
    END IF;

    -- Fetch session & class details
    SELECT * INTO v_session FROM attendance_sessions WHERE id = v_record.session_id;
    SELECT * INTO v_class FROM classes WHERE id = v_session.class_id;
    SELECT * INTO v_student FROM students WHERE id = v_record.student_id;

    -- Resolve class coordinator / advisor
    SELECT p.full_name, COALESCE(p.phone_number, '+919876543211') AS phone
    INTO v_coord
    FROM class_coordinators cc
    JOIN profiles p ON p.id = cc.coordinator_id
    WHERE cc.class_id = v_class.id
    LIMIT 1;

    v_advisor_name := COALESCE(v_coord.full_name, 'Class Advisor');
    v_advisor_phone := COALESCE(v_coord.phone, '+919876543211');

    -- Create deterministic idempotency key for this student + session + status
    v_idempotency_key := 'imm_abs_' || v_session.id || '_' || v_student.id || '_' || v_record.status;

    -- Insert into transactional outbox if not already present
    INSERT INTO whatsapp_outbox (
        notification_type,
        recipient_phone,
        recipient_name,
        recipient_role,
        template_name,
        template_language,
        template_parameters,
        payload,
        status,
        idempotency_key
    ) VALUES (
        'immediate_absence',
        v_advisor_phone,
        v_advisor_name,
        'Class Advisor',
        v_settings.absence_template_name,
        v_settings.absence_template_lang,
        jsonb_build_array(
            v_advisor_name,
            v_student.full_name,
            v_student.register_number,
            v_class.class_name,
            v_session.attendance_date::TEXT,
            initcap(v_session.session_type::TEXT),
            'Class Session'
        ),
        jsonb_build_object(
            'student_id', v_student.id,
            'class_id', v_class.id,
            'session_id', v_session.id,
            'attendance_date', v_session.attendance_date,
            'session_type', v_session.session_type
        ),
        'queued',
        v_idempotency_key
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO v_outbox_id;

    -- Create corresponding audit log entry
    IF v_outbox_id IS NOT NULL THEN
        INSERT INTO whatsapp_notification_logs (
            outbox_id,
            student_id,
            class_id,
            session_id,
            notification_type,
            recipient_phone,
            recipient_name,
            recipient_role,
            status
        ) VALUES (
            v_outbox_id,
            v_student.id,
            v_class.id,
            v_session.id,
            'immediate_absence',
            v_advisor_phone,
            v_advisor_name,
            'Class Advisor',
            'queued'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Trigger on attendance_records to auto-queue absence alert on INSERT or UPDATE
CREATE OR REPLACE FUNCTION trg_attendance_record_whatsapp_alert()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger if status is 'absent' or 'bunk' and (INSERT or status changed to absent/bunk from something else)
    IF NEW.status IN ('absent', 'bunk') AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM NEW.status) THEN
        PERFORM queue_immediate_absence_notification(NEW.id, NEW.marked_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_attendance_record_whatsapp ON attendance_records;
CREATE TRIGGER trg_attendance_record_whatsapp
    AFTER INSERT OR UPDATE OF status ON attendance_records
    FOR EACH ROW
    EXECUTE FUNCTION trg_attendance_record_whatsapp_alert();

-- 12. Stored Procedure: Evaluate Repeated Absences over Configurable Window
CREATE OR REPLACE FUNCTION evaluate_repeated_absence_summaries(
    p_window_days INT DEFAULT 7,
    p_threshold INT DEFAULT 3,
    p_as_of_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    class_id UUID,
    class_name TEXT,
    qualifying_count BIGINT,
    dean_notified BOOLEAN
) AS $$
DECLARE
    v_start_date DATE := p_as_of_date - (p_window_days - 1);
    v_settings RECORD;
    v_class RECORD;
    v_dean_phone TEXT;
    v_dean_name TEXT;
    v_coord RECORD;
    v_advisor_name TEXT;
    v_advisor_phone TEXT;
    v_qualifying_students JSONB;
    v_qualifying_count INT;
    v_idempotency_key TEXT;
    v_adv_idempotency_key TEXT;
    v_outbox_id UUID;
    v_adv_outbox_id UUID;
BEGIN
    SELECT * INTO v_settings FROM whatsapp_settings LIMIT 1;
    v_dean_phone := COALESCE(v_settings.dean_placement_phone, '+919876543200');
    v_dean_name := COALESCE(v_settings.dean_placement_name, 'Dean of Placement and Training');

    FOR v_class IN SELECT c.id, c.class_name, c.department FROM classes c WHERE c.active = true LOOP
        -- Count distinct qualifying unexcused absent/bunk sessions for each student in window.
        -- Strictly filters for finalized (closed) sessions and excludes approved OD and present records.
        WITH student_absences AS (
            SELECT
                ar.student_id,
                s.full_name,
                s.register_number,
                COUNT(DISTINCT ar.session_id) AS absence_count
            FROM attendance_records ar
            JOIN attendance_sessions ses ON ses.id = ar.session_id
            JOIN students s ON s.id = ar.student_id
            WHERE ses.class_id = v_class.id
              AND ses.attendance_date BETWEEN v_start_date AND p_as_of_date
              AND ses.status = 'closed'
              AND ar.status IN ('absent', 'bunk')
              AND s.active = true
            GROUP BY ar.student_id, s.full_name, s.register_number
            HAVING COUNT(DISTINCT ar.session_id) >= p_threshold
        )
        SELECT
            COUNT(*),
            COALESCE(jsonb_agg(
                jsonb_build_object(
                    'student_id', student_id,
                    'full_name', full_name,
                    'register_number', register_number,
                    'absences', absence_count
                )
            ), '[]'::jsonb)
        INTO v_qualifying_count, v_qualifying_students
        FROM student_absences;

        IF v_qualifying_count > 0 THEN
            -- 1. Queue summary for Dean of Placement & Training
            v_idempotency_key := 'rep_abs_dean_' || v_class.id || '_' || v_start_date || '_' || p_as_of_date || '_th' || p_threshold;

            INSERT INTO whatsapp_outbox (
                notification_type,
                recipient_phone,
                recipient_name,
                recipient_role,
                template_name,
                template_language,
                template_parameters,
                payload,
                status,
                idempotency_key
            ) VALUES (
                'repeated_absence_summary',
                v_dean_phone,
                v_dean_name,
                'Dean of Placement & Training',
                v_settings.summary_template_name,
                v_settings.summary_template_lang,
                jsonb_build_array(
                    v_dean_name,
                    v_class.class_name,
                    v_qualifying_count::TEXT,
                    v_start_date::TEXT,
                    p_as_of_date::TEXT
                ),
                jsonb_build_object(
                    'class_id', v_class.id,
                    'start_date', v_start_date,
                    'end_date', p_as_of_date,
                    'qualifying_students', v_qualifying_students
                ),
                'queued',
                v_idempotency_key
            )
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING id INTO v_outbox_id;

            -- Record summary log for Dean
            INSERT INTO whatsapp_absence_summaries (
                summary_period_start,
                summary_period_end,
                rule_version,
                recipient_role,
                recipient_phone,
                class_id,
                qualifying_count,
                qualifying_students,
                outbox_id,
                idempotency_key
            ) VALUES (
                v_start_date,
                p_as_of_date,
                'v1',
                'Dean of Placement & Training',
                v_dean_phone,
                v_class.id,
                v_qualifying_count,
                v_qualifying_students,
                v_outbox_id,
                v_idempotency_key
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

            -- 2. Queue summary for Assigned Class Advisor / Coordinator
            SELECT p.full_name, COALESCE(p.phone_number, '+919876543211') AS phone
            INTO v_coord
            FROM class_coordinators cc
            JOIN profiles p ON p.id = cc.coordinator_id
            WHERE cc.class_id = v_class.id
            LIMIT 1;

            IF v_coord.phone IS NOT NULL THEN
                v_advisor_name := COALESCE(v_coord.full_name, 'Class Advisor');
                v_advisor_phone := v_coord.phone;
                v_adv_idempotency_key := 'rep_abs_adv_' || v_class.id || '_' || v_start_date || '_' || p_as_of_date || '_th' || p_threshold;

                INSERT INTO whatsapp_outbox (
                    notification_type,
                    recipient_phone,
                    recipient_name,
                    recipient_role,
                    template_name,
                    template_language,
                    template_parameters,
                    payload,
                    status,
                    idempotency_key
                ) VALUES (
                    'repeated_absence_summary',
                    v_advisor_phone,
                    v_advisor_name,
                    'Class Advisor',
                    v_settings.summary_template_name,
                    v_settings.summary_template_lang,
                    jsonb_build_array(
                        v_advisor_name,
                        v_class.class_name,
                        v_qualifying_count::TEXT,
                        v_start_date::TEXT,
                        p_as_of_date::TEXT
                    ),
                    jsonb_build_object(
                        'class_id', v_class.id,
                        'start_date', v_start_date,
                        'end_date', p_as_of_date,
                        'qualifying_students', v_qualifying_students
                    ),
                    'queued',
                    v_adv_idempotency_key
                )
                ON CONFLICT (idempotency_key) DO NOTHING
                RETURNING id INTO v_adv_outbox_id;

                INSERT INTO whatsapp_absence_summaries (
                    summary_period_start,
                    summary_period_end,
                    rule_version,
                    recipient_role,
                    recipient_phone,
                    class_id,
                    qualifying_count,
                    qualifying_students,
                    outbox_id,
                    idempotency_key
                ) VALUES (
                    v_start_date,
                    p_as_of_date,
                    'v1',
                    'Class Advisor',
                    v_advisor_phone,
                    v_class.id,
                    v_qualifying_count,
                    v_qualifying_students,
                    v_adv_outbox_id,
                    v_adv_idempotency_key
                )
                ON CONFLICT (idempotency_key) DO NOTHING;
            END IF;

            class_id := v_class.id;
            class_name := v_class.class_name;
            qualifying_count := v_qualifying_count;
            dean_notified := (v_outbox_id IS NOT NULL);
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Atomic Queue Worker Claim Batch Procedure (FOR UPDATE SKIP LOCKED)
-- Guarantees race-condition-free batch processing across concurrent worker instances.
CREATE OR REPLACE FUNCTION claim_whatsapp_outbox_batch(p_batch_size INT DEFAULT 20)
RETURNS SETOF whatsapp_outbox AS $$
BEGIN
    RETURN QUERY
    WITH claimed AS (
        SELECT id
        FROM whatsapp_outbox
        WHERE (
            status = 'queued'
            OR (status = 'failed' AND next_retry_at <= NOW() AND retry_count < max_retries)
            OR (status = 'processing' AND updated_at < NOW() - INTERVAL '5 minutes')
        )
        ORDER BY created_at ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    )
    UPDATE whatsapp_outbox o
    SET status = 'processing',
        updated_at = NOW()
    FROM claimed
    WHERE o.id = claimed.id
    RETURNING o.*;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 14. Scheduled Repeated-Absence Evaluation Configuration
-- To activate weekly scheduled evaluation in Supabase pg_cron:
-- SELECT cron.schedule(
--     'weekly_repeated_absence_job',
--     '30 11 * * 5', -- Every Friday at 17:00 IST (11:30 UTC)
--     $$SELECT evaluate_repeated_absence_summaries(7, 3, CURRENT_DATE);$$
-- );
