import dotenv from "dotenv";
dotenv.config();

import { initWhatsAppClient } from "./whatsapp-client.js";
import { startOutboxWorker, stopOutboxWorker } from "./workers/outbox-worker.js";
import { startDailyReportScheduler } from "./scheduler.js";

console.log("============================================================");
console.log(" Vel Tech High Tech — Personal WhatsApp Attendance Daemon");
console.log("============================================================");

// 1. Initialize WhatsApp Web Client
const client = initWhatsAppClient();

// 2. Start Outbox Processing Worker (polls every 5 seconds)
const pollInterval = parseInt(process.env.POLL_INTERVAL_MS || "5000", 10);
startOutboxWorker(pollInterval);

// 3. Start 2:00 PM Mon-Sat Automated Scheduler
startDailyReportScheduler().catch((err) => {
  console.error("[Main] Error starting scheduler:", err.message);
});

// Handle graceful shutdown
function handleShutdown(signal) {
  console.log(`\n[Main] Received ${signal}. Shutting down cleanly...`);
  stopOutboxWorker();
  try {
    if (client) {
      client.destroy();
    }
  } catch (_) {}
  process.exit(0);
}

process.on("SIGINT", () => handleShutdown("SIGINT"));
process.on("SIGTERM", () => handleShutdown("SIGTERM"));

