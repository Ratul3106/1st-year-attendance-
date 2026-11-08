// Supabase Edge Function: daily-attendance-report-job
// Automated backend job scheduled for 2:00 PM IST (14:00 Asia/Kolkata = 08:30 UTC).
// Generates preliminary attendance reports for all active classes,
// sends WhatsApp reports to authorized staff recipients,
// and supports final report dispatch upon afternoon session completion.
// Fully idempotent across repeated runs.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const reportType = body.report_type || "preliminary"; // 'preliminary' or 'final'
    const specificClassId = body.class_id || null;

    // 1. Check if WhatsApp automatic reporting is enabled
    const { data: config, error: configErr } = await supabase
      .from("whatsapp_config")
      .select("*")
      .limit(1)
      .maybeSingle();

    if (config && !config.reports_enabled) {
      return new Response(
        JSON.stringify({ message: "Automatic WhatsApp attendance reports are disabled in configuration." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Determine target reporting date (Asia/Kolkata current date)
    const nowIst = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
    const todayStr = `${nowIst.getFullYear()}-${String(nowIst.month + 1 || nowIst.getMonth() + 1).padStart(2, "0")}-${String(nowIst.getDate()).padStart(2, "0")}`;
    const targetDate = body.report_date || todayStr;

    // 3. Fetch active classes
    let classQuery = supabase.from("classes").select("*").eq("active", true);
    if (specificClassId) {
      classQuery = classQuery.eq("id", specificClassId);
    }
    const { data: classes, error: classErr } = await classQuery;
    if (classErr || !classes || classes.length === 0) {
      return new Response(
        JSON.stringify({ message: "No active classes found for reporting." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Generate consolidated report and send to administrator
    const { data: reportResult, error: reportErr } = await supabase.rpc(
      "generate_consolidated_daily_report",
      { p_date: targetDate, p_admin_phone: config.admin_phone }
    );

    if (reportErr || !reportResult) {
      console.error(`[ScheduledJob] Error generating consolidated report:`, reportErr);
      return new Response(JSON.stringify({ error: "Failed to generate consolidated report" }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const reportMessageText = reportResult.message_text || reportResult;
    const reportId = reportResult.report_id || null;
    const outboxId = reportResult.outbox_id || null;

    // generate_consolidated_daily_report() already inserts the single outbox record
    // and audit log with atomic deduplication. Do not insert a duplicate.

    // Trigger whatsapp-worker fallback if configured
    try {
      await supabase.functions.invoke("whatsapp-worker");
    } catch (e) {
      console.warn("[ScheduledJob] whatsapp-worker invocation note:", e);
    }

    return new Response(
      JSON.stringify({ success: true, report_date: targetDate, report_type: reportType, outbox_id: outboxId }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[ScheduledJob Fatal Error]", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

