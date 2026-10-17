// Supabase Edge Function: whatsapp-webhook
// Meta WhatsApp Business Platform Webhook Handler
// Verifies incoming webhooks, validates HMAC-SHA256 signatures,
// deduplicates events, and updates delivery statuses in outbox & logs.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-hub-signature-256",
};

// SubtleCrypto helper for HMAC-SHA256 signature verification
async function verifyMetaSignature(
  rawBody: string,
  signatureHeader: string | null,
  appSecret: string
): Promise<boolean> {
  if (!signatureHeader || !appSecret) return false;

  const expectedPrefix = "sha256=";
  if (!signatureHeader.startsWith(expectedPrefix)) return false;
  const providedSignatureHex = signatureHeader.slice(expectedPrefix.length);

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(appSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(rawBody)
  );

  const hashArray = Array.from(new Uint8Array(signatureBuffer));
  const calculatedHex = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

  return calculatedHex.toLowerCase() === providedSignatureHex.toLowerCase();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);

  // 1. Meta Webhook Verification Challenge (GET)
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");

    const expectedToken = Deno.env.get("WHATSAPP_WEBHOOK_VERIFY_TOKEN") || "attendance_whatsapp_secret_token";

    if (mode === "subscribe" && token === expectedToken) {
      console.log("[Webhook] Successfully verified Meta challenge.");
      return new Response(challenge, { status: 200 });
    } else {
      console.warn("[Webhook] Verification challenge failed - token mismatch.");
      return new Response("Forbidden", { status: 403 });
    }
  }

  // 2. Incoming Event Notification (POST)
  if (req.method === "POST") {
    try {
      const rawBody = await req.text();
      const appSecret = Deno.env.get("WHATSAPP_APP_SECRET");

      // Verify HMAC-SHA256 signature (fail-closed security model)
      if (!appSecret) {
        console.error("[Webhook Error] WHATSAPP_APP_SECRET is not configured on server.");
        return new Response(
          JSON.stringify({ error: "Webhook signature secret unconfigured on server" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const signature = req.headers.get("x-hub-signature-256");
      const isValid = await verifyMetaSignature(rawBody, signature, appSecret);
      if (!isValid) {
        console.error("[Webhook] Invalid HMAC-SHA256 signature.");
        return new Response(JSON.stringify({ error: "Invalid signature" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const payload = JSON.parse(rawBody);
      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      const entries = payload.entry || [];
      const processedEvents = [];

      for (const entry of entries) {
        const changes = entry.changes || [];
        for (const change of changes) {
          const value = change.value || {};
          const statuses = value.statuses || [];

          for (const statusObj of statuses) {
            const wamid = statusObj.id; // Meta Message ID
            const status = statusObj.status; // sent, delivered, read, failed
            const timestamp = statusObj.timestamp;
            const recipientPhone = statusObj.recipient_id;
            const errors = statusObj.errors || null;

            // Deterministic event ID for deduplication
            const eventId = `${wamid}_${status}_${timestamp}`;

            // Deduplicate incoming webhook event
            const { error: dedupError } = await supabase
              .from("whatsapp_webhook_events")
              .insert({
                event_id: eventId,
                provider_message_id: wamid,
                event_type: "status_update",
                recipient_phone: recipientPhone,
                status: status,
                error_details: errors,
                raw_payload: statusObj,
              });

            if (dedupError) {
              // Event already recorded, skip to avoid duplicate processing
              console.log(`[Webhook] Duplicate event skipped: ${eventId}`);
              continue;
            }

            // Map Meta status to our delivery enum
            let mappedStatus = "processing";
            if (status === "sent") mappedStatus = "sent";
            else if (status === "delivered") mappedStatus = "delivered";
            else if (status === "read") mappedStatus = "read";
            else if (status === "failed") mappedStatus = "failed";

            // Update outbox record
            await supabase
              .from("whatsapp_outbox")
              .update({
                status: mappedStatus,
                error_message: errors ? JSON.stringify(errors) : null,
                updated_at: new Date().toISOString(),
              })
              .eq("provider_message_id", wamid);

            // Update corresponding audit log
            const logUpdate: any = {
              status: mappedStatus,
              error_code: errors?.[0]?.code ? String(errors[0].code) : null,
              error_message: errors?.[0]?.title || null,
            };

            if (status === "sent") logUpdate.sent_at = new Date(parseInt(timestamp) * 1000).toISOString();
            if (status === "delivered") logUpdate.delivered_at = new Date(parseInt(timestamp) * 1000).toISOString();
            if (status === "read") logUpdate.read_at = new Date(parseInt(timestamp) * 1000).toISOString();

            await supabase
              .from("whatsapp_notification_logs")
              .update(logUpdate)
              .eq("provider_message_id", wamid);

            processedEvents.push({ wamid, status: mappedStatus });
          }
        }
      }

      return new Response(
        JSON.stringify({ success: true, processed: processedEvents.length, events: processedEvents }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } catch (err: any) {
      console.error("[Webhook Error]", err);
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  return new Response("Method Not Allowed", { status: 405 });
});
