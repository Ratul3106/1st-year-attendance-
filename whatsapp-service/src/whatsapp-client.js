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

  const jid = formatToWhatsAppJid(phone);
  if (!jid) {
    throw new Error(`Invalid destination phone number: ${phone}`);
  }

  console.log(`[WhatsAppClient] Sending consolidated attendance report to ${jid}...`);
  const messageIds = [];

  // 1. Send Text Summary Message
  if (textMessage) {
    const textRes = await clientInstance.sendMessage(jid, textMessage);
    messageIds.push(textRes.id._serialized || textRes.id.id);
    console.log(`[WhatsAppClient] 💬 Text summary sent. ID: ${messageIds[0]}`);
  }

  // Small delay between attachments for message ordering
  await new Promise((r) => setTimeout(r, 1000));

  // 2. Send PDF Document Attachment
  if (pdfPath && fs.existsSync(pdfPath)) {
    const pdfMedia = MessageMedia.fromFilePath(pdfPath);
    const pdfRes = await clientInstance.sendMessage(jid, pdfMedia, {
      sendMediaAsDocument: true,
      caption: "📄 Vel Tech High Tech — Consolidated Attendance Report (PDF)",
    });
    const pdfId = pdfRes.id._serialized || pdfRes.id.id;
    messageIds.push(pdfId);
    console.log(`[WhatsAppClient] 📄 PDF document sent. ID: ${pdfId}`);
  }

  await new Promise((r) => setTimeout(r, 1000));

  // 3. Send Excel Workbook Attachment
  if (excelPath && fs.existsSync(excelPath)) {
    const excelMedia = MessageMedia.fromFilePath(excelPath);
    const excelRes = await clientInstance.sendMessage(jid, excelMedia, {
      sendMediaAsDocument: true,
      caption: "📊 Vel Tech High Tech — Detailed Attendance Workbook (Excel)",
    });
    const excelId = excelRes.id._serialized || excelRes.id.id;
    messageIds.push(excelId);
    console.log(`[WhatsAppClient] 📊 Excel spreadsheet sent. ID: ${excelId}`);
  }

  return {
    success: true,
    destination: jid,
    messageIds,
  };
}

