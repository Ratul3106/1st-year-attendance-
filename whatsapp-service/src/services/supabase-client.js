import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL || "https://pagucnchqohxvceovpaf.supabase.co";
const supabaseKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  "sb_publishable_5-nMq0gB07w5bo2cS-67Vg_IKVQY7_r";

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false },
});

/**
 * Fetch WhatsApp reporting configuration from Supabase
 */
export async function getWhatsAppConfig() {
  try {
    const { data, error } = await supabase
      .from("whatsapp_config")
      .select("*")
      .limit(1)
      .maybeSingle();

    if (error) {
      console.warn("[Supabase] Failed to fetch whatsapp_config:", error.message);
      return null;
    }
    return data;
  } catch (err) {
    console.error("[Supabase] Exception in getWhatsAppConfig:", err);
    return null;
  }
}

/**
 * Trigger the PostgreSQL stored procedure: generate_consolidated_daily_report
 */
export async function generateConsolidatedReport(dateStr, targetPhone) {
  try {
    const { data, error } = await supabase.rpc(
      "generate_consolidated_daily_report",
      {
        p_date: dateStr,
        p_admin_phone: targetPhone,
      }
    );

    if (error) {
      console.error("[Supabase] RPC generate_consolidated_daily_report failed:", error.message);
      throw error;
    }
    return data;
  } catch (err) {
    console.error("[Supabase] Exception calling generate_consolidated_daily_report:", err);
    throw err;
  }
}

/**
 * Fetch detailed class, student, session, and record data for Excel & PDF generation
 */
export async function getFullAttendanceData(dateStr) {
  try {
    // 1. Fetch active classes
    const { data: classes, error: classErr } = await supabase
      .from("classes")
      .select("*")
      .eq("active", true)
      .order("class_name", { ascending: true });

    if (classErr) throw classErr;

    const classDataList = [];

    for (const cls of classes || []) {
      // 2. Fetch enrolled students
      const { data: enrollments, error: enrollErr } = await supabase
        .from("class_enrollments")
        .select("student_id, students (id, register_number, full_name, active)")
        .eq("class_id", cls.id);

      if (enrollErr) {
        console.warn(`[Supabase] Enrollment fetch error for ${cls.class_name}:`, enrollErr.message);
        continue;
      }

      const activeStudents = (enrollments || [])
        .map((e) => e.students)
        .filter((s) => s && s.active !== false)
        .sort((a, b) =>
          (a.register_number || "").localeCompare(b.register_number || "")
        );

      // 3. Fetch morning & afternoon sessions
      const { data: sessions, error: sessErr } = await supabase
        .from("attendance_sessions")
        .select("*")
        .eq("class_id", cls.id)
        .eq("attendance_date", dateStr);

      if (sessErr) {
        console.warn(`[Supabase] Sessions fetch error for ${cls.class_name}:`, sessErr.message);
      }

      const morningSession = (sessions || []).find((s) => s.session_type === "morning");
      const afternoonSession = (sessions || []).find((s) => s.session_type === "afternoon");

      // 4. Fetch records for morning
      let morningRecords = {};
      if (morningSession) {
        const { data: mRecs } = await supabase
          .from("attendance_records")
          .select("student_id, status")
          .eq("session_id", morningSession.id);

        for (const r of mRecs || []) {
          morningRecords[r.student_id] = r.status;
        }
      }

      // 5. Fetch records for afternoon
      let afternoonRecords = {};
      if (afternoonSession) {
        const { data: aRecs } = await supabase
          .from("attendance_records")
          .select("student_id, status")
          .eq("session_id", afternoonSession.id);

        for (const r of aRecs || []) {
          afternoonRecords[r.student_id] = r.status;
        }
      }

      // Compute counts
      let mPres = 0, mAbs = 0, mOd = 0;
      let aPres = 0, aAbs = 0, aOd = 0, aBunk = 0;

      const studentRoster = activeStudents.map((st, index) => {
        const mStatus = morningRecords[st.id] || "unmarked";
        const aStatus = afternoonRecords[st.id] || "unmarked";

        if (mStatus === "present") mPres++;
        else if (mStatus === "absent") mAbs++;
        else if (mStatus === "od") mOd++;

        if (aStatus === "present") aPres++;
        else if (aStatus === "absent") aAbs++;
        else if (aStatus === "od") aOd++;
        else if (aStatus === "bunk") aBunk++;

        return {
          serialNo: index + 1,
          id: st.id,
          registerNumber: st.register_number,
          fullName: st.full_name,
          morningStatus: mStatus,
          afternoonStatus: aStatus,
        };
      });

      const totalEnrolled = activeStudents.length;
      const mMarked = mPres + mAbs + mOd;
      const mUnmarked = Math.max(0, totalEnrolled - mMarked);
      const mPct = mMarked > 0 ? (((mPres + mOd) / mMarked) * 100).toFixed(1) : "0.0";

      const aMarked = aPres + aAbs + aOd + aBunk;
      const aUnmarked = Math.max(0, totalEnrolled - aMarked);
      const aPct = aMarked > 0 ? (((aPres + aOd) / aMarked) * 100).toFixed(1) : "0.0";

      classDataList.push({
        classId: cls.id,
        className: cls.class_name,
        department: cls.department,
        academicYear: cls.academic_year,
        totalEnrolled,
        morning: {
          present: mPres,
          absent: mAbs,
          od: mOd,
          unmarked: mUnmarked,
          percentage: mPct,
          status: morningSession && mUnmarked === 0 && mMarked > 0 ? "Completed" : "Incomplete",
        },
        afternoon: {
          present: aPres,
          absent: aAbs,
          od: aOd,
          bunk: aBunk,
          unmarked: aUnmarked,
          percentage: aPct,
          status: afternoonSession && aUnmarked === 0 && aMarked > 0 ? "Completed" : "Incomplete",
        },
        roster: studentRoster,
      });
    }

    return classDataList;
  } catch (err) {
    console.error("[Supabase] Exception in getFullAttendanceData:", err);
    throw err;
  }
}

/**
 * Claim queued batch from whatsapp_outbox
 */
export async function claimOutboxBatch(batchSize = 10) {
  try {
    // Attempt RPC claim first
    const { data: claimed, error: rpcErr } = await supabase.rpc(
      "claim_whatsapp_outbox_batch",
      { p_batch_size: batchSize }
    );

    if (!rpcErr && claimed && claimed.length > 0) {
      return claimed;
    }

    // Fallback: direct query
    const nowIso = new Date().toISOString();
    const { data: fallback, error: queryErr } = await supabase
      .from("whatsapp_outbox")
      .select("*")
      .eq("status", "queued")
      .lte("next_retry_at", nowIso)
      .lt("retry_count", 5)
      .order("created_at", { ascending: true })
      .limit(batchSize);

    if (queryErr) throw queryErr;

    // Transition to processing
    if (fallback && fallback.length > 0) {
      const ids = fallback.map((f) => f.id);
      await supabase
        .from("whatsapp_outbox")
        .update({ status: "processing", updated_at: nowIso })
        .in("id", ids);
    }

    return fallback || [];
  } catch (err) {
    console.error("[Supabase] Error claiming outbox batch:", err);
    return [];
  }
}

/**
 * Update outbox and notification logs status
 */
export async function updateOutboxStatus(outboxId, status, errorMessage = null, providerMessageId = null) {
  try {
    const nowIso = new Date().toISOString();
    const updateData = {
      status,
      updated_at: nowIso,
    };

    if (errorMessage) {
      updateData.error_message = errorMessage;
    }
    if (providerMessageId) {
      updateData.provider_message_id = providerMessageId;
    }

    await supabase
      .from("whatsapp_outbox")
      .update(updateData)
      .eq("id", outboxId);

    // Update corresponding notification log
    const logUpdate = { status };
    if (status === "sent") {
      logUpdate.sent_at = nowIso;
      logUpdate.actual_send_time = nowIso;
    }
    if (providerMessageId) {
      logUpdate.provider_message_id = providerMessageId;
    }
    if (errorMessage) {
      logUpdate.error_message = errorMessage;
    }

    await supabase
      .from("whatsapp_notification_logs")
      .update(logUpdate)
      .eq("outbox_id", outboxId);
  } catch (err) {
    console.error(`[Supabase] Error updating outbox status for ${outboxId}:`, err);
  }
}

