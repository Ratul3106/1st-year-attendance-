import { claimOutboxBatch, updateOutboxStatus } from "../services/supabase-client.js";
import { compileAndDispatchDailyReport } from "../services/report-coordinator.js";
import { sendReportToAdmin, isWhatsAppReady } from "../whatsapp-client.js";

let isProcessing = false;
let workerInterval = null;

/**
 * Process a single outbox record
 */
async function processOutboxItem(item) {
  console.log(`[OutboxWorker] Processing outbox item: ${item.id} (${item.notification_type})...`);

  // Type 1: Consolidated Attendance Report
  if (
    item.notification_type === "attendance_report" ||
    item.notification_type === "daily_report_preliminary" ||
    item.notification_type === "daily_report_final"
  ) {
    const reportDate = item.payload?.report_date || item.created_at?.split("T")[0];
    const targetPhone = item.recipient_phone;

    await compileAndDispatchDailyReport({
      targetDate: reportDate,
      targetPhone,
      outboxId: item.id,
    });
    return;
  }

  // Type 2: General Text Notification (e.g. absence alert or manual alert)
  const targetPhone = item.recipient_phone;
  let text = item.payload?.message_text;

  if (!text && Array.isArray(item.template_parameters) && item.template_parameters.length > 0) {
    text = item.template_parameters[0];
  }

  if (!text) {
    text = `College Attendance Alert for ${item.recipient_name || "Staff"}`;
  }

  const res = await sendReportToAdmin({
    phone: targetPhone,
    textMessage: text,
  });

  const msgId = res.messageIds?.[0] || null;
  await updateOutboxStatus(item.id, "sent", null, msgId);
  console.log(`[OutboxWorker] ✅ Item ${item.id} delivered to ${targetPhone}.`);
}

/**
 * Poll and drain pending queued items
 */
export async function pollAndProcessOutbox() {
  if (isProcessing) return;
  if (!isWhatsAppReady()) {
    // Client not ready yet (waiting for QR code scan)
    return;
  }

  isProcessing = true;
  try {
    const batch = await claimOutboxBatch(5);
    if (batch && batch.length > 0) {
      console.log(`[OutboxWorker] Claimed ${batch.length} queued WhatsApp messages.`);
      for (const item of batch) {
        try {
          await processOutboxItem(item);
        } catch (itemErr) {
          console.error(`[OutboxWorker] Error processing item ${item.id}:`, itemErr.message);
          await updateOutboxStatus(item.id, "failed", itemErr.message);
        }
      }
    }
  } catch (err) {
    console.error("[OutboxWorker] Error during polling batch:", err.message);
  } finally {
    isProcessing = false;
  }
}

/**
 * Start the continuous background polling loop
 */
export function startOutboxWorker(intervalMs = 5000) {
  if (workerInterval) clearInterval(workerInterval);
  console.log(`[OutboxWorker] Started listening to outbox queue (polling every ${intervalMs / 1000}s)...`);
  workerInterval = setInterval(pollAndProcessOutbox, intervalMs);
}

/**
 * Stop the background polling loop
 */
export function stopOutboxWorker() {
  if (workerInterval) {
    clearInterval(workerInterval);
    workerInterval = null;
    console.log("[OutboxWorker] Stopped.");
  }
}

