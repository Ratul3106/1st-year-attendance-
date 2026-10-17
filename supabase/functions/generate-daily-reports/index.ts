// Supabase Edge Function: generate-daily-reports
// Triggered at 14:00 IST (08:30 UTC) daily

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-supabase-js@2.38.4";

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

    // Get date in Asia/Kolkata timezone
    const nowKolkata = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" }));
    const currentDate = nowKolkata.toISOString().split("T")[0];

    // 1. Fetch all active classes
    const { data: classes, error: classError } = await supabase
      .from("classes")
      .select("id, class_name, department")
      .eq("active", true);

    if (classError) throw classError;

    const reportResults = [];

    // 2. Loop each active class and run generate_daily_attendance_report
    for (const cls of classes || []) {
      const { data: reportId, error: rpcError } = await supabase.rpc(
        "generate_daily_attendance_report",
        {
          p_class_id: cls.id,
          p_date: currentDate,
        }
      );

      if (rpcError) {
        console.error(`Error building report for class ${cls.class_name}:`, rpcError);
        reportResults.push({ class_id: cls.id, status: "error", error: rpcError.message });
      } else {
        reportResults.push({ class_id: cls.id, report_id: reportId, status: "success" });
      }
    }

    return new Response(
      JSON.stringify({
        message: "Daily report generation completed successfully.",
        date: currentDate,
        processed_classes: reportResults.length,
        details: reportResults,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
