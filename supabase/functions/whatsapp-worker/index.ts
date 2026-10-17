// Supabase Edge Function: whatsapp-worker
// Background worker for processing queued WhatsApp messages via Meta Cloud API.
// Features exponential backoff retries, E.164 normalization, timeouts, and structured tracking.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Normalize phone number to E.164 without symbols
function normalizeE164(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  // If 10 digits (India standard local), prefix country code 91
  if (digits.length === 10) {
    return `91${digits}`;
  }
  return digits;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Meta WhatsApp Cloud API Configuration
    const accessToken = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
    const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
    const apiVersion = Deno.env.get("WHATSAPP_API_VERSION") || "v21.0";

    if (!accessToken || !phoneNumberId) {
      console.warn("[Worker] Missing WhatsApp API credentials. Messages will remain in queue.");
      return new Response(
        JSON.stringify({ error: "Missing WHATSAPP_ACCESS_TOKEN or WHATSAPP_PHONE_NUMBER_ID" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Atomically claim outbox batch using FOR UPDATE SKIP LOCKED to prevent duplicate processing
    let queueItems: any[] = [];
    const { data: claimedItems, error: rpcError } = await supabase.rpc(
      "claim_whatsapp_outbox_batch",
      { p_batch_size: 20 }
    );

    if (!rpcError && claimedItems) {
      queueItems = claimedItems;
    } else {
      // Fallback if stored procedure not yet deployed
      const nowIso = new Date().toISOString();
      const { data: fallbackItems, error: fetchError } = await supabase
        .from("whatsapp_outbox")
        .select("*")
        .or(`status.eq.queued,and(status.eq.failed,next_retry_at.lte.${nowIso})`)
        .lt("retry_count", 5)
        .order("created_at", { ascending: true })
        .limit(20);

      if (fetchError) throw fetchError;
      queueItems = fallbackItems || [];

      // Mark as processing in fallback mode
      for (const item of queueItems) {
        await supabase
          .from("whatsapp_outbox")
          .update({ status: "processing", updated_at: new Date().toISOString() })
          .eq("id", item.id);
      }
    }

    if (!queueItems || queueItems.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending WhatsApp messages to process.", processed: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results = [];

    // 2. Process each outbox record
    for (const item of queueItems) {

      const targetPhone = normalizeE164(item.recipient_phone);
      const templateParams = Array.isArray(item.template_parameters)
        ? item.template_parameters
        : [];

      // Format Meta WhatsApp Business Cloud API template payload
      const payload = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: targetPhone,
        type: "template",
        template: {
          name: item.template_name,
          language: { code: item.template_language || "en_US" },
          components: [
            {
              type: "body",
              parameters: templateParams.map((param: any) => ({
                type: "text",
                text: String(param),
              })),
            },
          ],
        },
      };

      try {
        const metaApiUrl = `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout

        const response = await fetch(metaApiUrl, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        clearTimeout(timeoutId);
        const resJson = await response.json();

        if (response.ok && resJson.messages && resJson.messages.length > 0) {
          const wamid = resJson.messages[0].id; // Provider message ID
          console.log(`[Worker] Sent message ${item.id} -> WAMID: ${wamid}`);

          // Update outbox to sent
          await supabase
            .from("whatsapp_outbox")
            .update({
              status: "sent",
              provider_message_id: wamid,
              error_message: null,
              updated_at: new Date().toISOString(),
            })
            .eq("id", item.id);

          // Update audit logs
          await supabase
            .from("whatsapp_notification_logs")
            .update({
              status: "sent",
              provider_message_id: wamid,
              sent_at: new Date().toISOString(),
            })
            .eq("outbox_id", item.id);

          results.push({ id: item.id, status: "sent", wamid });
        } else {
          // Meta API returned error
          const errorMsg = resJson.error?.message || "Meta API error";
          const newRetryCount = item.retry_count + 1;
          const backoffSeconds = Math.pow(2, newRetryCount) * 30; // Exponential backoff: 60s, 120s, 240s...
          const nextRetry = new Date(Date.now() + backoffSeconds * 1000).toISOString();
          const finalStatus = newRetryCount >= item.max_retries ? "failed" : "failed";

          console.error(`[Worker] Failed sending message ${item.id}: ${errorMsg}. Retry: ${newRetryCount}`);

          await supabase
            .from("whatsapp_outbox")
            .update({
              status: finalStatus,
              retry_count: newRetryCount,
              next_retry_at: nextRetry,
              error_message: errorMsg,
              updated_at: new Date().toISOString(),
            })
            .eq("id", item.id);

          await supabase
            .from("whatsapp_notification_logs")
            .update({
              status: finalStatus,
              error_message: errorMsg,
            })
            .eq("outbox_id", item.id);

          results.push({ id: item.id, status: "error", error: errorMsg, retry_count: newRetryCount });
        }
      } catch (sendErr: any) {
        // Network timeout or unexpected failure
        const errorMsg = sendErr.name === "AbortError" ? "HTTP Timeout (10s)" : sendErr.message;
        const newRetryCount = item.retry_count + 1;
        const backoffSeconds = Math.pow(2, newRetryCount) * 30;
        const nextRetry = new Date(Date.now() + backoffSeconds * 1000).toISOString();

        await supabase
          .from("whatsapp_outbox")
          .update({
            status: "failed",
            retry_count: newRetryCount,
            next_retry_at: nextRetry,
            error_message: errorMsg,
            updated_at: new Date().toISOString(),
          })
          .eq("id", item.id);

        results.push({ id: item.id, status: "exception", error: errorMsg });
      }
    }

    return new Response(
      JSON.stringify({ message: "Outbox processing completed.", processed: results.length, details: results }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[Worker Fatal Error]", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
