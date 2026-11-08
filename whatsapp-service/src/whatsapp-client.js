import pkg from "whatsapp-web.js";
const { Client, LocalAuth, MessageMedia } = pkg;
import qrcode from "qrcode-terminal";
import path from "path";
import fs from "fs";

let clientInstance = null;
let clientReady = false;
let latestQr = null;

/**
 * Normalize phone number to WhatsApp JID format (<country_code><digits>@c.us)
 */
export function formatToWhatsAppJid(phone) {
  if (!phone) return null;
  const digits = String(phone).replace(/\D/g, "");
  // Prefix India country code (91) if 10 digits
  const cleanDigits = digits.length === 10 ? `91${digits}` : digits;
  return `${cleanDigits}@c.us`;
}

/**
 * Initialize and launch the whatsapp-web.js client
 */
export function initWhatsAppClient() {
  if (clientInstance) {
    return clientInstance;
  }

  const authDir = path.join(process.cwd(), ".wwebjs_auth");
  if (!fs.existsSync(authDir)) {
    fs.mkdirSync(authDir, { recursive: true });
  }

  // Clean up any stale Chromium devtools/lock files left by previous killed runs
  const sessionDir = path.join(authDir, "session");
  if (fs.existsSync(sessionDir)) {
    const devToolsFile = path.join(sessionDir, "DevToolsActivePort");
    const lockFile = path.join(sessionDir, "lockfile");
    try {
      if (fs.existsSync(devToolsFile)) fs.unlinkSync(devToolsFile);
      if (fs.existsSync(lockFile)) fs.unlinkSync(lockFile);
    } catch (_) {}
  }

  console.log("------------------------------------------------------------");
  console.log("[WhatsAppClient] Initializing WhatsApp Personal Client...");
  console.log("[WhatsAppClient] LocalAuth Directory:", authDir);
  console.log("------------------------------------------------------------");

  clientInstance = new Client({
    authStrategy: new LocalAuth({
      dataPath: authDir,
    }),
    puppeteer: {
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-accelerated-2d-canvas",
        "--no-first-run",
        "--no-zygote",
        "--disable-gpu",
      ],
    },
  });

  clientInstance.on("qr", (qr) => {
    latestQr = qr;
    clientReady = false;
    console.log("\n============================================================");
    console.log("📱 SCAN THIS QR CODE WITH YOUR PERSONAL WHATSAPP TO CONNECT:");
    console.log("   (WhatsApp -> Settings -> Linked Devices -> Link a Device)");
    console.log("============================================================\n");
    qrcode.generate(qr, { small: true });
    console.log("\nWaiting for QR scan...\n");
  });

  clientInstance.on("loading_screen", (percent, message) => {
    console.log(`[WhatsAppClient] ⏳ Loading screen: ${percent}% — ${message}`);
  });

  clientInstance.on("change_state", (state) => {
    console.log(`[WhatsAppClient] 🔄 State changed: ${state}`);
  });

  clientInstance.on("authenticated", () => {
    latestQr = null;
    console.log("[WhatsAppClient] ✅ Session Authenticated successfully!");
  });

  clientInstance.on("auth_failure", (msg) => {
    clientReady = false;
    console.error("[WhatsAppClient] ❌ Authentication failure:", msg);
  });

  clientInstance.on("ready", () => {
    clientReady = true;
    latestQr = null;
    console.log("============================================================");
    console.log("[WhatsAppClient] 🚀 Client is READY and connected to WhatsApp!");
    console.log("============================================================");
  });

  clientInstance.on("disconnected", (reason) => {
    clientReady = false;
    console.warn("[WhatsAppClient] ⚠️ Client disconnected:", reason);
    console.log("[WhatsAppClient] Attempting re-initialization in 5 seconds...");
    setTimeout(() => {
      try {
        clientInstance.initialize();
      } catch (err) {
        console.error("[WhatsAppClient] Reconnection error:", err.message);
      }
    }, 5000);
  });

  try {
    clientInstance.initialize();
  } catch (err) {
    console.error("[WhatsAppClient] Error initializing client:", err);
  }

  return clientInstance;
}

/**
 * Check if the client is connected and ready
 */
export function isWhatsAppReady() {
  return clientReady && clientInstance !== null;
}

/**
 * Get current QR code if pending
 */
export function getLatestQr() {
  return latestQr;
}

/**
 * Send media document ensuring proper chat model memoization in WhatsApp Web
 */
async function sendMediaDocumentWithModel(chatId, filePath, caption) {
  const media = MessageMedia.fromFilePath(filePath);
  return await clientInstance.sendMessage(chatId, media, {
    caption: caption,
    sendMediaAsDocument: true,
  });
}

/**
 * Dispatch text summary, PDF, and Excel attachments to Admin's WhatsApp
 */
export async function sendReportToAdmin({
  phone,
  textMessage,
  pdfPath = null,
  excelPath = null,
}) {
  if (!clientReady || !clientInstance) {
    throw new Error(
      "WhatsApp Client is not ready. Please scan the QR code first."
    );
  }

  const digits = String(phone).replace(/\D/g, "");
  const cleanDigits = digits.length === 10 ? `91${digits}` : digits;

  console.log(`[WhatsAppClient] Validating destination WhatsApp registration for +${cleanDigits}...`);
  const targetChatId = `${cleanDigits}@c.us`;

  try {
    const numberId = await clientInstance.getNumberId(cleanDigits);
    if (numberId) {
      console.log(`[WhatsAppClient] Verified recipient is registered on WhatsApp.`);
    } else {
      throw new Error(
        `The destination phone number +${cleanDigits} is not registered on WhatsApp. Please check the recipient number.`
      );
    }
  } catch (err) {
    if (err.message.includes("not registered")) {
      throw err;
    }
    console.warn(`[WhatsAppClient] getNumberId notice: ${err.message}. Proceeding to ${targetChatId}...`);
  }

  console.log(`[WhatsAppClient] Sending consolidated attendance report to ${targetChatId}...`);
  const messageIds = [];

  // 1. Send Text Summary Message
  if (textMessage) {
    try {
      const textRes = await clientInstance.sendMessage(targetChatId, textMessage);
      const msgId = textRes?.id?._serialized || textRes?.id?.id || `msg_${Date.now()}`;
      messageIds.push(msgId);
      console.log(`[WhatsAppClient] 💬 Text summary sent. ID: ${msgId}`);
    } catch (textErr) {
      console.error(`[WhatsAppClient] Error sending text:`, textErr.message);
    }
  }

  // Small delay between attachments for message ordering
  await new Promise((r) => setTimeout(r, 2000));

  // 2. Send PDF Document Attachment
  if (pdfPath && fs.existsSync(pdfPath)) {
    try {
      const pdfRes = await sendMediaDocumentWithModel(
        targetChatId,
        pdfPath,
        "📄 Vel Tech High Tech — Consolidated Attendance Report (PDF)"
      );
      const pdfId = pdfRes?.id?._serialized || pdfRes?.id?.id || `pdf_${Date.now()}`;
      messageIds.push(pdfId);
      console.log(`[WhatsAppClient] 📄 PDF document sent. ID: ${pdfId}`);
    } catch (pdfErr) {
      console.error(`[WhatsAppClient] Warning: Could not send PDF attachment:`, pdfErr);
    }
  }

  await new Promise((r) => setTimeout(r, 2000));

  // 3. Send Excel Workbook Attachment
  if (excelPath && fs.existsSync(excelPath)) {
    try {
      const excelRes = await sendMediaDocumentWithModel(
        targetChatId,
        excelPath,
        "📊 Vel Tech High Tech — Detailed Attendance Workbook (Excel)"
      );
      const excelId = excelRes?.id?._serialized || excelRes?.id?.id || `excel_${Date.now()}`;
      messageIds.push(excelId);
      console.log(`[WhatsAppClient] 📊 Excel spreadsheet sent. ID: ${excelId}`);
    } catch (excelErr) {
      console.error(`[WhatsAppClient] Warning: Could not send Excel attachment:`, excelErr);
    }
  }

  if (messageIds.length === 0) {
    throw new Error("Failed to deliver any messages to recipient.");
  }

  return {
    success: true,
    destination: targetChatId,
    messageIds,
  };
}

