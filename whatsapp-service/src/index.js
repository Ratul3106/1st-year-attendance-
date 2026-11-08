import http from "http";
import dotenv from "dotenv";
dotenv.config();

import { initWhatsAppClient, isWhatsAppReady, getLatestQr, sendReportToAdmin } from "./whatsapp-client.js";
import { startOutboxWorker, stopOutboxWorker } from "./workers/outbox-worker.js";
import { startDailyReportScheduler } from "./scheduler.js";
import { compileAndDispatchDailyReport } from "./services/report-coordinator.js";

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

// 4. Start Local HTTP Trigger API for Flutter Web Portal
const PORT = parseInt(process.env.HTTP_PORT || "3001", 10);

const server = http.createServer(async (req, res) => {
  // Enable CORS for Flutter Web running on localhost
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

  const sendJson = (statusCode, data) => {
    res.writeHead(statusCode, { "Content-Type": "application/json" });
    res.end(JSON.stringify(data));
  };

  const readJsonBody = () =>
    new Promise((resolve) => {
      let body = "";
      req.on("data", (chunk) => (body += chunk));
      req.on("end", () => {
        try {
          resolve(body ? JSON.parse(body) : {});
        } catch (_) {
          resolve({});
        }
      });
    });

  // GET /api/status
  if (req.method === "GET" && url.pathname === "/api/status") {
    return sendJson(200, {
      ready: isWhatsAppReady(),
      qr: getLatestQr(),
      timestamp: new Date().toISOString(),
    });
  }

  // POST /api/send-report
  if (req.method === "POST" && url.pathname === "/api/send-report") {
    if (!isWhatsAppReady()) {
      return sendJson(503, {
        success: false,
        error: "Personal WhatsApp client is still connecting or syncing. Please wait a moment and try again.",
      });
    }

    try {
      const body = await readJsonBody();
      const phone = body.phone || process.env.DEFAULT_ADMIN_PHONE;
      const date = body.date || null;

      console.log(`[HTTP API] Admin portal triggered report dispatch for ${phone}...`);
      const result = await compileAndDispatchDailyReport({
        targetPhone: phone,
        targetDate: date,
      });

      return sendJson(200, {
        success: true,
        message: `Consolidated daily report (Text summary, PDF & Excel) dispatched successfully to ${result.destination}.`,
        destination: result.destination,
        messageIds: result.messageIds,
      });
    } catch (err) {
      console.error("[HTTP API] Error dispatching report:", err);
      return sendJson(500, {
        success: false,
        error: err.message || "Failed to dispatch report",
      });
    }
  }

  // POST /api/test-message
  if (req.method === "POST" && url.pathname === "/api/test-message") {
    if (!isWhatsAppReady()) {
      return sendJson(503, {
        success: false,
        error: "Personal WhatsApp client is still connecting or syncing. Please wait a moment and try again.",
      });
    }

    try {
      const body = await readJsonBody();
      const phone = body.phone || process.env.DEFAULT_ADMIN_PHONE;
      const text = body.message || "Vel Tech High Tech Attendance System — WhatsApp Test Connection Successful! ✅";

      console.log(`[HTTP API] Admin portal triggered test message to ${phone}...`);
      const result = await sendReportToAdmin({
        phone,
        textMessage: text,
      });

      return sendJson(200, {
        success: true,
        message: `Test message dispatched successfully to ${phone}.`,
        messageIds: result.messageIds,
      });
    } catch (err) {
      console.error("[HTTP API] Error dispatching test message:", err);
      return sendJson(500, {
        success: false,
        error: err.message || "Failed to dispatch test message",
      });
    }
  }

  sendJson(404, { error: "Endpoint not found" });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[HTTP API] 🌐 Personal WhatsApp Dispatch API listening on http://127.0.0.1:${PORT}`);
});

// Handle graceful shutdown
function handleShutdown(signal) {
  console.log(`\n[Main] Received ${signal}. Shutting down cleanly...`);
  stopOutboxWorker();
  try {
    server.close();
  } catch (_) {}
  try {
    if (client) {
      client.destroy();
    }
  } catch (_) {}
  process.exit(0);
}

process.on("SIGINT", () => handleShutdown("SIGINT"));
process.on("SIGTERM", () => handleShutdown("SIGTERM"));

