import cron from "node-cron";
import { getWhatsAppConfig } from "./services/supabase-client.js";
import { compileAndDispatchDailyReport } from "./services/report-coordinator.js";

let scheduledTask = null;

/**
 * Initialize the scheduled automated 2:00 PM IST Monday-Saturday report job
 */
export async function startDailyReportScheduler() {
  const config = await getWhatsAppConfig();
  const timezone = config?.timezone || process.env.TIMEZONE || "Asia/Kolkata";

  // Parse time: default to 14:00 (2:00 PM)
  const reportTimeStr = config?.report_time || "14:00";
  const [hStr, mStr] = reportTimeStr.split(":");
  const hour = parseInt(hStr || "14", 10);
  const minute = parseInt(mStr || "0", 10);

  // Standard Cron: Minute Hour * * 1-6 (Mon-Sat)
  const cronExpression = `${minute} ${hour} * * 1-6`;

  console.log("------------------------------------------------------------");
  console.log("[Scheduler] ⏰ Initializing Automated Daily Attendance Report");
  console.log(`[Scheduler] Schedule: Monday–Saturday at ${reportTimeStr} IST (${cronExpression})`);
  console.log(`[Scheduler] Timezone: ${timezone}`);
  console.log("------------------------------------------------------------");

  if (scheduledTask) {
    scheduledTask.stop();
  }

  scheduledTask = cron.schedule(
    cronExpression,
    async () => {
      console.log(`\n[Scheduler] 🔔 CRON TRIGGERED: Running scheduled 14:00 IST daily report...`);
      try {
        const freshConfig = await getWhatsAppConfig();
        if (freshConfig && freshConfig.reports_enabled === false) {
          console.log("[Scheduler] ⏸️ Automated reports are disabled in configuration. Skipping.");
          return;
        }

        const result = await compileAndDispatchDailyReport();
        console.log("[Scheduler] ✅ Automated daily report successfully dispatched!", result.destination);
      } catch (err) {
        console.error("[Scheduler] ❌ Error executing scheduled report:", err.message);
      }
    },
    {
      timezone,
    }
  );

  return scheduledTask;
}

