import dotenv from "dotenv";
dotenv.config();

import { compileAndDispatchDailyReport } from "./src/services/report-coordinator.js";
import { initWhatsAppClient, isWhatsAppReady } from "./src/whatsapp-client.js";

console.log("============================================================");
console.log(" Vel Tech High Tech — Instant Manual WhatsApp Report Dispatch");
console.log("============================================================");

const client = initWhatsAppClient();

async function runTest() {
  console.log("Waiting for WhatsApp Web to sync and be ready (up to 90 seconds)...");
  let waitCount = 0;
  while (!isWhatsAppReady() && waitCount < 90) {
    await new Promise((r) => setTimeout(r, 1000));
    waitCount++;
    if (waitCount % 10 === 0) {
      console.log(`[WhatsAppClient] Still syncing chats with WhatsApp Web (${waitCount}s / 90s)...`);
    }
  }

  if (!isWhatsAppReady()) {
    console.error("❌ WhatsApp client is not connected. Make sure you scanned the QR code.");
    process.exit(1);
  }

  console.log("✅ Client is ready! Compiling and dispatching report now...");
  try {
    const res = await compileAndDispatchDailyReport({
      targetPhone: process.env.DEFAULT_ADMIN_PHONE,
    });
    console.log("🎉 SUCCESS! Report dispatched to Admin:", res.destination);
    console.log("Message IDs:", res.messageIds);
    try {
      await client.destroy();
    } catch (_) {}
    process.exit(0);
  } catch (err) {
    console.error("❌ Error dispatching report:", err);
    try {
      await client.destroy();
    } catch (_) {}
    process.exit(1);
  }
}

runTest();

