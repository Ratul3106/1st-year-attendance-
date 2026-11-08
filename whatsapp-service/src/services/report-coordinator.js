import {
  getWhatsAppConfig,
  generateConsolidatedReport,
  getFullAttendanceData,
  updateOutboxStatus,
} from "./supabase-client.js";
import { generateAttendancePDF } from "../generators/pdf-generator.js";
import { generateAttendanceExcel } from "../generators/excel-generator.js";
import { sendReportToAdmin, isWhatsAppReady } from "../whatsapp-client.js";

/**
 * Compile and dispatch the consolidated daily attendance report
 * @param {Object} options
 * @param {string} [options.targetDate] - YYYY-MM-DD (defaults to today in IST)
 * @param {string} [options.targetPhone] - Recipient phone number
 * @param {string} [options.outboxId] - Existing outbox ID if fulfilling a queue item
 * @returns {Promise<Object>} Result of the compilation and delivery
 */
export async function compileAndDispatchDailyReport(options = {}) {
  const config = await getWhatsAppConfig();

  // Resolve current date in IST
  const nowIst = new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Kolkata" })
  );
  const year = nowIst.getFullYear();
  const month = String(nowIst.getMonth() + 1).padStart(2, "0");
  const day = String(nowIst.getDate()).padStart(2, "0");
  const todayStr = `${year}-${month}-${day}`;

  const dateStr = options.targetDate || todayStr;
  const adminPhone =
    options.targetPhone ||
    config?.admin_phone ||
    process.env.DEFAULT_ADMIN_PHONE ||
    "+918072459331";

  const generatedAtStr = new Date().toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    hour12: true,
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "short",
    year: "numeric",
  });

  console.log("============================================================");
  console.log(`[ReportCoordinator] Starting Report for Date: ${dateStr}`);
  console.log(`[ReportCoordinator] Destination Admin Mobile: ${adminPhone}`);
  console.log("============================================================");

  // 1. Invoke PostgreSQL function for metrics & summary text
  let rpcResult = null;
  let outboxId = options.outboxId || null;
  let summaryText = "";
  let reportStatus = "PRELIMINARY";

  try {
    rpcResult = await generateConsolidatedReport(dateStr, adminPhone);
    summaryText = rpcResult?.message_text || "";
    reportStatus =
      rpcResult?.report_status?.includes("FINAL") ? "FINAL" : "PRELIMINARY";
    if (!outboxId && rpcResult?.outbox_id) {
      outboxId = rpcResult.outbox_id;
    }
  } catch (err) {
    console.warn(
      "[ReportCoordinator] Warning: Could not run generate_consolidated_daily_report RPC, building fallback text:",
      err.message
    );
  }

  // 2. Fetch full attendance data for Excel and PDF rosters
  const classDataList = await getFullAttendanceData(dateStr);

  // If RPC failed to yield text, format fallback summary text
  if (!summaryText) {
    let grandEnrolled = 0;
    let grandMPre = 0,
      grandMAbs = 0;
    let classLines = [];

    classDataList.forEach((cls) => {
      grandEnrolled += cls.totalEnrolled || 0;
      grandMPre += cls.morning?.present || 0;
      grandMAbs += cls.morning?.absent || 0;
      classLines.push(
        `• *${cls.className}* (${cls.department}): Enrolled: ${cls.totalEnrolled} | M: ${cls.morning?.present || 0} Pres, ${cls.morning?.absent || 0} Abs (${cls.morning?.percentage || "0.0"}%) | A: ${cls.afternoon?.present || 0} Pres`
      );
    });

    const mTotal = grandMPre + grandMAbs;
    const mOverallPct =
      mTotal > 0 ? ((grandMPre / mTotal) * 100).toFixed(1) : "0.0";

    summaryText =
      `🎓 *VEL TECH HIGH TECH DR.RANGARAJAN DR.SAKUNTHALA ENGINEERING COLLEGE*\n` +
      `📋 *CONSOLIDATED DAILY ATTENDANCE REPORT — [${reportStatus}]*\n` +
      `📅 Date: ${dateStr} | Time: ${generatedAtStr} IST\n` +
      `👤 Destination: Administrator (${adminPhone})\n\n` +
      classLines.join("\n") +
      `\n\n📊 *Overall Campus Attendance:* ${mOverallPct}%\n` +
      `Total Enrolled: ${grandEnrolled} | Morning Present: ${grandMPre} | Morning Absent: ${grandMAbs}\n\n` +
      `Attached: PDF Report & Detailed Excel Workbook.\n` +
      `Student Attendance Management System`;
  }

  // 3. Generate PDF Report via PDFKit
  console.log("[ReportCoordinator] Generating PDF report via PDFKit...");
  const pdfPath = await generateAttendancePDF({
    dateStr,
    generatedAtStr,
    classDataList,
    reportStatus,
    adminPhone,
  });
  console.log(`[ReportCoordinator] ✅ PDF generated at: ${pdfPath}`);

  // 4. Generate Excel Report via ExcelJS
  console.log("[ReportCoordinator] Generating Excel workbook via ExcelJS...");
  const excelPath = await generateAttendanceExcel({
    dateStr,
    generatedAtStr,
    classDataList,
    reportStatus,
  });
  console.log(`[ReportCoordinator] ✅ Excel generated at: ${excelPath}`);

  // 5. Check if WhatsApp is ready to deliver
  if (!isWhatsAppReady()) {
    const errorMsg =
      "WhatsApp client is not ready (QR code not scanned or disconnected).";
    console.error(`[ReportCoordinator] ❌ ${errorMsg}`);
    if (outboxId) {
      await updateOutboxStatus(outboxId, "failed", errorMsg);
    }
    return {
      success: false,
      error: errorMsg,
      pdfPath,
      excelPath,
    };
  }

  // 6. Send via Personal WhatsApp
  try {
    const sendResult = await sendReportToAdmin({
      phone: adminPhone,
      textMessage: summaryText,
      pdfPath,
      excelPath,
    });

    // 7. Update Outbox and Notification Logs
    if (outboxId) {
      const primaryMsgId = sendResult.messageIds?.[0] || null;
      await updateOutboxStatus(outboxId, "sent", null, primaryMsgId);
    }

    console.log(
      `[ReportCoordinator] 🚀 Full package (Text + PDF + Excel) delivered successfully to ${adminPhone}!`
    );

    return {
      success: true,
      destination: adminPhone,
      date: dateStr,
      reportStatus,
      pdfPath,
      excelPath,
      messageIds: sendResult.messageIds,
      outboxId,
    };
  } catch (sendErr) {
    console.error("[ReportCoordinator] ❌ Delivery failure:", sendErr.message);
    if (outboxId) {
      await updateOutboxStatus(outboxId, "failed", sendErr.message);
    }
    throw sendErr;
  }
}

