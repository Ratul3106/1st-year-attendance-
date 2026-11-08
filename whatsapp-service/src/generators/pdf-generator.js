import PDFDocument from "pdfkit";
import fs from "fs";
import path from "path";

/**
 * Generate a professional college attendance PDF report using PDFKit
 * @param {Object} params
 * @param {string} params.dateStr - Date in YYYY-MM-DD
 * @param {string} params.generatedAtStr - Formatted timestamp
 * @param {Array} params.classDataList - List of class statistics and rosters
 * @param {string} params.reportStatus - 'FINAL' or 'PRELIMINARY'
 * @param {string} params.adminPhone - Recipient phone
 * @param {string} params.outputPath - Output file path
 * @returns {Promise<string>} File path of generated PDF
 */
export function generateAttendancePDF({
  dateStr,
  generatedAtStr = new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }),
  classDataList = [],
  reportStatus = "PRELIMINARY",
  adminPhone = "+919876543200",
  outputPath = null,
}) {
  return new Promise((resolve, reject) => {
    try {
      const targetPath =
        outputPath ||
        path.join(
          process.cwd(),
          "temp",
          `Attendance_Report_${dateStr.replace(/-/g, "")}.pdf`
        );

      const dir = path.dirname(targetPath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }

      const doc = new PDFDocument({
        size: "A4",
        margin: 36,
        bufferPages: true,
      });

      const writeStream = fs.createWriteStream(targetPath);
      doc.pipe(writeStream);

      // Colors
      const primaryColor = "#1E3A8A"; // Navy Blue
      const secondaryColor = "#2563EB"; // Blue
      const accentGreen = "#059669";
      const accentRed = "#DC2626";
      const textDark = "#0F172A";
      const textMuted = "#475569";
      const borderLine = "#E2E8F0";

      // ----------------------------------------------------------------------
      // Header Section
      // ----------------------------------------------------------------------
      const logoPath = path.join(process.cwd(), "assets", "college_logo.png");
      if (fs.existsSync(logoPath)) {
        try {
          doc.image(logoPath, 36, 32, { width: 50 });
        } catch (e) {
          console.warn("[PDFGenerator] Warning: Could not embed logo image:", e.message);
        }
      }

      doc
        .font("Helvetica-Bold")
        .fontSize(12)
        .fillColor(primaryColor)
        .text("VEL TECH HIGH TECH DR.RANGARAJAN DR.SAKUNTHALA ENGINEERING COLLEGE", 96, 34, {
          align: "left",
        });

      doc
        .font("Helvetica")
        .fontSize(8)
        .fillColor(textMuted)
        .text("An Autonomous Institution - Affiliated to Anna University | Avadi, Chennai - 600062", 96, 48, {
          align: "left",
        });

      doc
        .font("Helvetica-Bold")
        .fontSize(11)
        .fillColor(secondaryColor)
        .text(`DAILY ATTENDANCE REPORT — [${reportStatus.toUpperCase()}]`, 96, 60, {
          align: "left",
        });

      // Divider Line
      doc
        .moveTo(36, 82)
        .lineTo(559, 82)
        .lineWidth(1)
        .strokeColor(primaryColor)
        .stroke();

      // Metadata Sub-bar
      doc.rect(36, 88, 523, 24).fill("#F1F5F9");
      doc
        .font("Helvetica-Bold")
        .fontSize(8)
        .fillColor(textDark)
        .text(`Date: ${dateStr}`, 44, 95)
        .text(`Generated At: ${generatedAtStr} IST`, 150, 95)
        .text(`Destination: Admin (${adminPhone})`, 330, 95);

      // ----------------------------------------------------------------------
      // Campus Overview Summary Cards
      // ----------------------------------------------------------------------
      let grandEnrolled = 0;
      let grandMPres = 0, grandMAbs = 0, grandMOd = 0;
      let grandAPres = 0, grandAAbs = 0, grandAOd = 0, grandABunk = 0;

      classDataList.forEach((cls) => {
        grandEnrolled += cls.totalEnrolled || 0;
        grandMPres += cls.morning?.present || 0;
        grandMAbs += cls.morning?.absent || 0;
        grandMOd += cls.morning?.od || 0;

        grandAPres += cls.afternoon?.present || 0;
        grandAAbs += cls.afternoon?.absent || 0;
        grandAOd += cls.afternoon?.od || 0;
        grandABunk += cls.afternoon?.bunk || 0;
      });

      const mMarked = grandMPres + grandMAbs + grandMOd;
      const mPct = mMarked > 0 ? (((grandMPres + grandMOd) / mMarked) * 100).toFixed(1) : "0.0";

      const aMarked = grandAPres + grandAAbs + grandAOd + grandABunk;
      const aPct = aMarked > 0 ? (((grandAPres + grandAOd) / aMarked) * 100).toFixed(1) : "0.0";

      const cardY = 122;
      const cardWidth = 124;
      const cardHeight = 44;
      const gap = 9;

      const cards = [
        { label: "Total Enrolled", val: `${grandEnrolled}`, color: primaryColor },
        { label: "Morning Attended", val: `${grandMPres + grandMOd} (${mPct}%)`, color: accentGreen },
        { label: "Morning Absentees", val: `${grandMAbs}`, color: accentRed },
        { label: "Afternoon Attended", val: `${grandAPres + grandAOd} (${aPct}%)`, color: secondaryColor },
      ];

      cards.forEach((c, i) => {
        const cx = 36 + i * (cardWidth + gap);
        doc.rect(cx, cardY, cardWidth, cardHeight).fill("#F8FAFC");
        doc.rect(cx, cardY, cardWidth, cardHeight).lineWidth(0.5).strokeColor(borderLine).stroke();

        doc
          .font("Helvetica")
          .fontSize(7.5)
          .fillColor(textMuted)
          .text(c.label, cx + 6, cardY + 7);

        doc
          .font("Helvetica-Bold")
          .fontSize(11)
          .fillColor(c.color)
          .text(c.val, cx + 6, cardY + 22);
      });

      // ----------------------------------------------------------------------
      // Section: Class-by-Class Attendance Table
      // ----------------------------------------------------------------------
      let curY = 178;

      doc
        .font("Helvetica-Bold")
        .fontSize(9.5)
        .fillColor(primaryColor)
        .text("Class-by-Class Attendance Summary", 36, curY);

      curY += 15;

      // Table Header Bar
      doc.rect(36, curY, 523, 18).fill(primaryColor);
      doc
        .font("Helvetica-Bold")
        .fontSize(7.5)
        .fillColor("#FFFFFF")
        .text("Class Name", 40, curY + 5)
        .text("Dept", 140, curY + 5)
        .text("Enrolled", 220, curY + 5, { width: 40, align: "center" })
        .text("Morning (P/A/OD)", 265, curY + 5, { width: 75, align: "center" })
        .text("Morning %", 345, curY + 5, { width: 50, align: "center" })
        .text("Afternoon (P/A/B)", 400, curY + 5, { width: 80, align: "center" })
        .text("Afternoon %", 485, curY + 5, { width: 50, align: "center" });

      curY += 18;

      classDataList.forEach((cls, idx) => {
        // Page break check
        if (curY > 750) {
          doc.addPage();
          curY = 36;
        }

        const isEven = idx % 2 === 0;
        doc.rect(36, curY, 523, 16).fill(isEven ? "#FFFFFF" : "#F8FAFC");

        const mStats = `${cls.morning?.present || 0}/${cls.morning?.absent || 0}/${cls.morning?.od || 0}`;
        const aStats = `${cls.afternoon?.present || 0}/${cls.afternoon?.absent || 0}/${cls.afternoon?.bunk || 0}`;

        doc
          .font("Helvetica-Bold")
          .fontSize(7.5)
          .fillColor(textDark)
          .text(cls.className, 40, curY + 4, { width: 95, ellipsis: true });

        doc
          .font("Helvetica")
          .fontSize(7)
          .fillColor(textMuted)
          .text(cls.department, 140, curY + 4, { width: 75, ellipsis: true });

        doc
          .font("Helvetica")
          .fontSize(7.5)
          .fillColor(textDark)
          .text(`${cls.totalEnrolled}`, 220, curY + 4, { width: 40, align: "center" })
          .text(mStats, 265, curY + 4, { width: 75, align: "center" })
          .text(`${cls.morning?.percentage || "0.0"}%`, 345, curY + 4, { width: 50, align: "center" })
          .text(aStats, 400, curY + 4, { width: 80, align: "center" })
          .text(`${cls.afternoon?.percentage || "0.0"}%`, 485, curY + 4, { width: 50, align: "center" });

        doc
          .moveTo(36, curY + 16)
          .lineTo(559, curY + 16)
          .lineWidth(0.5)
          .strokeColor(borderLine)
          .stroke();

        curY += 16;
      });

      // ----------------------------------------------------------------------
      // Section: Absentees and OD Students Roster
      // ----------------------------------------------------------------------
      curY += 16;
      if (curY > 700) {
        doc.addPage();
        curY = 36;
      }

      doc
        .font("Helvetica-Bold")
        .fontSize(9.5)
        .fillColor(accentRed)
        .text("Campus Absentee & OD Summary Roster", 36, curY);

      curY += 14;

      doc.rect(36, curY, 523, 16).fill("#FEE2E2");
      doc
        .font("Helvetica-Bold")
        .fontSize(7.5)
        .fillColor("#991B1B")
        .text("Reg. Number", 42, curY + 4)
        .text("Student Name", 140, curY + 4)
        .text("Class", 280, curY + 4)
        .text("Morning", 380, curY + 4, { width: 60, align: "center" })
        .text("Afternoon", 445, curY + 4, { width: 60, align: "center" });

      curY += 16;

      let absListed = 0;
      for (const cls of classDataList) {
        for (const st of cls.roster || []) {
          const m = (st.morningStatus || "").toUpperCase();
          const a = (st.afternoonStatus || "").toUpperCase();

          if (m === "ABSENT" || a === "ABSENT" || m === "OD" || a === "OD" || a === "BUNK") {
            absListed++;
            if (curY > 760) {
              doc.addPage();
              curY = 36;
            }

            const rowBg = absListed % 2 === 0 ? "#FFFFFF" : "#FFF7ED";
            doc.rect(36, curY, 523, 14).fill(rowBg);

            doc
              .font("Helvetica-Bold")
              .fontSize(7)
              .fillColor(textDark)
              .text(st.registerNumber || "-", 42, curY + 3);

            doc
              .font("Helvetica")
              .fontSize(7)
              .fillColor(textDark)
              .text(st.fullName || "-", 140, curY + 3, { width: 135, ellipsis: true });

            doc
              .font("Helvetica")
              .fontSize(7)
              .fillColor(textMuted)
              .text(cls.className, 280, curY + 3);

            doc
              .font("Helvetica-Bold")
              .fontSize(7)
              .fillColor(m === "ABSENT" ? accentRed : m === "OD" ? secondaryColor : accentGreen)
              .text(m, 380, curY + 3, { width: 60, align: "center" });

            doc
              .font("Helvetica-Bold")
              .fontSize(7)
              .fillColor(a === "ABSENT" || a === "BUNK" ? accentRed : a === "OD" ? secondaryColor : accentGreen)
              .text(a, 445, curY + 3, { width: 60, align: "center" });

            curY += 14;
          }
        }
      }

      if (absListed === 0) {
        doc.rect(36, curY, 523, 18).fill("#F0FDF4");
        doc
          .font("Helvetica")
          .fontSize(8)
          .fillColor(accentGreen)
          .text("Zero absentees reported across all campus sessions today.", 42, curY + 5);
        curY += 18;
      }

      // ----------------------------------------------------------------------
      // Page Numbering Footer
      // ----------------------------------------------------------------------
      const pages = doc.bufferedPageRange();
      for (let i = 0; i < pages.count; i++) {
        doc.switchToPage(i);
        doc
          .font("Helvetica")
          .fontSize(7)
          .fillColor(textMuted)
          .text(
            `Vel Tech High Tech Attendance System  |  Page ${i + 1} of ${pages.count}  |  Official Confidential Document`,
            36,
            800,
            { align: "center", width: 523 }
          );
      }

      doc.end();

      writeStream.on("finish", () => {
        resolve(targetPath);
      });

      writeStream.on("error", (err) => {
        reject(err);
      });
    } catch (err) {
      reject(err);
    }
  });
}

