// Supabase Edge Function: repeated-absence-job
// Scheduled task to identify students whose absences meet the configurable threshold
// over the reporting window and queue summary alerts for Dean of Placement & Class Advisors.

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

    // 1. Fetch configurable threshold and window settings
    const { data: settings } = await supabase
      .from("whatsapp_settings")
      .select("absence_threshold, reporting_window_days, summary_alerts_enabled, timezone")
      .single();

    if (!settings?.summary_alerts_enabled) {
      return new Response(
        JSON.stringify({ message: "Repeated-absence summary alerts are disabled in settings." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const windowDays = settings?.reporting_window_days || 7;
    const threshold = settings?.absence_threshold || 3;

    // Date in configured timezone (default Asia/Kolkata) formatted as YYYY-MM-DD
    const targetTz = settings?.timezone || "Asia/Kolkata";
    const asOfDate = new Intl.DateTimeFormat("en-CA", { timeZone: targetTz }).format(new Date());

    // 2. Execute idempotent stored procedure
    const { data: summaryResults, error: rpcError } = await supabase.rpc(
      "evaluate_repeated_absence_summaries",
      {
        p_window_days: windowDays,
        p_threshold: threshold,
        p_as_of_date: asOfDate,
      }
    );

    if (rpcError) throw rpcError;

    // 3. Immediately trigger outbox worker if summaries were generated
    if (summaryResults && summaryResults.length > 0) {
      fetch(`${supabaseUrl}/functions/v1/whatsapp-worker`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${supabaseServiceKey}`,
          "Content-Type": "application/json",
        },
      }).catch((e) => console.warn("[Job] Worker trigger error:", e));
    }

    return new Response(
      JSON.stringify({
        message: "Repeated-absence evaluation completed successfully.",
        as_of_date: asOfDate,
        window_days: windowDays,
        threshold: threshold,
        classes_with_alerts: summaryResults?.length || 0,
        results: summaryResults,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[Job Error]", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
