import ExcelJS from "exceljs";
import path from "path";
import fs from "fs";

/**
 * Generate a styled multi-sheet Excel attendance report using ExcelJS
 * @param {Object} params
 * @param {string} params.dateStr - Date in YYYY-MM-DD
 * @param {string} params.generatedAtStr - Formatted timestamp
 * @param {Array} params.classDataList - List of class statistics and rosters
 * @param {string} params.reportStatus - 'FINAL' or 'PRELIMINARY'
 * @param {string} params.outputPath - Output file path
 * @returns {Promise<string>} File path of generated Excel
 */
export async function generateAttendanceExcel({
  dateStr,
  generatedAtStr = new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }),
  classDataList = [],
  reportStatus = "PRELIMINARY",
  outputPath = null,
}) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Student Attendance Management System";
  workbook.lastModifiedBy = "Admin Automation";
  workbook.created = new Date();
  workbook.modified = new Date();

  // Color Palette
  const NAVY_HEADER = "1E3A8A";
  const BLUE_HEADER = "2563EB";
  const LIGHT_BLUE_FILL = "EFF6FF";
  const LIGHT_GRAY_FILL = "F3F4F6";
  const BORDER_COLOR = "D1D5DB";

  // --------------------------------------------------------------------------
  // SHEET 1: Campus Overview & Class Summary
  // --------------------------------------------------------------------------
  const summarySheet = workbook.addWorksheet("Campus Overview", {
    views: [{ showGridLines: true }],
  });

  // College Header
  summarySheet.mergeCells("A1:Q1");
  const cellA1 = summarySheet.getCell("A1");
  cellA1.value = "VEL TECH HIGH TECH DR.RANGARAJAN DR.SAKUNTHALA ENGINEERING COLLEGE";
  cellA1.font = { name: "Arial", size: 14, bold: true, color: { argb: "FFFFFFFF" } };
  cellA1.alignment = { horizontal: "center", vertical: "middle" };
  cellA1.fill = { type: "pattern", pattern: "solid", fgColor: { argb: NAVY_HEADER } };
  summarySheet.getRow(1).height = 30;

  summarySheet.mergeCells("A2:Q2");
  const cellA2 = summarySheet.getCell("A2");
  cellA2.value = "Autonomous - Affiliated to Anna University | Avadi, Chennai";
  cellA2.font = { name: "Arial", size: 10, italic: true, color: { argb: "FFE0E7FF" } };
  cellA2.alignment = { horizontal: "center", vertical: "middle" };
  cellA2.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_HEADER } };
  summarySheet.getRow(2).height = 20;

  summarySheet.mergeCells("A3:Q3");
  const cellA3 = summarySheet.getCell("A3");
  cellA3.value = `CONSOLIDATED DAILY ATTENDANCE REPORT — [${reportStatus.toUpperCase()}]`;
  cellA3.font = { name: "Arial", size: 11, bold: true, color: { argb: "FF1E293B" } };
  cellA3.alignment = { horizontal: "center", vertical: "middle" };
  cellA3.fill = { type: "pattern", pattern: "solid", fgColor: { argb: LIGHT_BLUE_FILL } };
  summarySheet.getRow(3).height = 24;

  summarySheet.mergeCells("A4:Q4");
  const cellA4 = summarySheet.getCell("A4");
  cellA4.value = `Date: ${dateStr}   |   Generated At: ${generatedAtStr} IST   |   Scope: All Active Campus Classes`;
  cellA4.font = { name: "Arial", size: 9, bold: true, color: { argb: "FF475569" } };
  cellA4.alignment = { horizontal: "center", vertical: "middle" };
  summarySheet.getRow(4).height = 18;

  // Blank row
  summarySheet.addRow([]);

  // Table Headers
  const summaryHeaders = [
    "S.No",
    "Class Name",
    "Department",
    "Academic Year",
    "Total Enrolled",
    "Morning Present",
    "Morning Absent",
    "Morning OD",
    "Morning Unmarked",
    "Morning %",
    "Afternoon Present",
    "Afternoon Absent",
    "Afternoon OD",
    "Afternoon Bunk",
    "Afternoon Unmarked",
    "Afternoon %",
    "Status",
  ];

  const headerRow = summarySheet.addRow(summaryHeaders);
  headerRow.height = 24;
  headerRow.eachCell((cell) => {
    cell.font = { name: "Arial", size: 9, bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: NAVY_HEADER } };
    cell.alignment = { horizontal: "center", vertical: "middle", wrapText: true };
    cell.border = {
      top: { style: "thin", color: { argb: BORDER_COLOR } },
      left: { style: "thin", color: { argb: BORDER_COLOR } },
      bottom: { style: "medium", color: { argb: "FF0F172A" } },
      right: { style: "thin", color: { argb: BORDER_COLOR } },
    };
  });

  // Totals Accumulators
  let grandEnrolled = 0;
  let grandMPres = 0, grandMAbs = 0, grandMOd = 0, grandMUnmarked = 0;
  let grandAPres = 0, grandAAbs = 0, grandAOd = 0, grandABunk = 0, grandAUnmarked = 0;

  // Add Data Rows
  classDataList.forEach((cls, idx) => {
    grandEnrolled += cls.totalEnrolled || 0;
    grandMPres += cls.morning?.present || 0;
    grandMAbs += cls.morning?.absent || 0;
    grandMOd += cls.morning?.od || 0;
    grandMUnmarked += cls.morning?.unmarked || 0;

    grandAPres += cls.afternoon?.present || 0;
    grandAAbs += cls.afternoon?.absent || 0;
    grandAOd += cls.afternoon?.od || 0;
    grandABunk += cls.afternoon?.bunk || 0;
    grandAUnmarked += cls.afternoon?.unmarked || 0;

    const rowData = [
      idx + 1,
      cls.className,
      cls.department,
      cls.academicYear,
      cls.totalEnrolled,
      cls.morning?.present || 0,
      cls.morning?.absent || 0,
      cls.morning?.od || 0,
      cls.morning?.unmarked || 0,
      `${cls.morning?.percentage || "0.0"}%`,
      cls.afternoon?.present || 0,
      cls.afternoon?.absent || 0,
      cls.afternoon?.od || 0,
      cls.afternoon?.bunk || 0,
      cls.afternoon?.unmarked || 0,
      `${cls.afternoon?.percentage || "0.0"}%`,
      cls.afternoon?.status === "Completed" && cls.morning?.status === "Completed"
        ? "Completed"
        : "Incomplete",
    ];

    const row = summarySheet.addRow(rowData);
    row.height = 20;

    const isEven = idx % 2 === 0;
    row.eachCell((cell, colNum) => {
      cell.font = { name: "Arial", size: 9 };
      cell.alignment = {
        vertical: "middle",
        horizontal: colNum === 2 || colNum === 3 ? "left" : "center",
      };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: isEven ? "FFFFFFFF" : LIGHT_GRAY_FILL },
      };
      cell.border = {
        top: { style: "thin", color: { argb: BORDER_COLOR } },
        left: { style: "thin", color: { argb: BORDER_COLOR } },
        bottom: { style: "thin", color: { argb: BORDER_COLOR } },
        right: { style: "thin", color: { argb: BORDER_COLOR } },
      };
    });
  });

  // Grand Total Row
  const totalMMarked = grandMPres + grandMAbs + grandMOd;
  const grandMPct = totalMMarked > 0 ? (((grandMPres + grandMOd) / totalMMarked) * 100).toFixed(1) : "0.0";

  const totalAMarked = grandAPres + grandAAbs + grandAOd + grandABunk;
  const grandAPct = totalAMarked > 0 ? (((grandAPres + grandAOd) / totalAMarked) * 100).toFixed(1) : "0.0";

  const totalRowData = [
    "TOTAL",
    "CAMPUS SUMMARY",
    "-",
    "-",
    grandEnrolled,
    grandMPres,
    grandMAbs,
    grandMOd,
    grandMUnmarked,
    `${grandMPct}%`,
    grandAPres,
    grandAAbs,
    grandAOd,
    grandABunk,
    grandAUnmarked,
    `${grandAPct}%`,
    reportStatus === "FINAL" ? "Completed" : "Partial",
  ];

  const totalRow = summarySheet.addRow(totalRowData);
  totalRow.height = 24;
  totalRow.eachCell((cell, colNum) => {
    cell.font = { name: "Arial", size: 9, bold: true, color: { argb: "FF0F172A" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE2E8F0" } };
    cell.alignment = {
      vertical: "middle",
      horizontal: colNum <= 2 ? "left" : "center",
    };
    cell.border = {
      top: { style: "medium", color: { argb: "FF0F172A" } },
      bottom: { style: "double", color: { argb: "FF0F172A" } },
      left: { style: "thin", color: { argb: BORDER_COLOR } },
      right: { style: "thin", color: { argb: BORDER_COLOR } },
    };
  });

  // Adjust Summary Sheet Column Widths
  summarySheet.columns = [
    { width: 6 },  // S.No
    { width: 18 }, // Class Name
    { width: 26 }, // Department
    { width: 14 }, // Year
    { width: 13 }, // Enrolled
    { width: 14 }, // M Pres
    { width: 13 }, // M Abs
    { width: 12 }, // M OD
    { width: 16 }, // M Unmarked
    { width: 12 }, // M %
    { width: 14 }, // A Pres
    { width: 13 }, // A Abs
    { width: 12 }, // A OD
    { width: 13 }, // A Bunk
    { width: 16 }, // A Unmarked
    { width: 12 }, // A %
    { width: 14 }, // Status
  ];

  // --------------------------------------------------------------------------
  // SHEET 2: Full Categorized Student Roster
  // --------------------------------------------------------------------------
  const rosterSheet = workbook.addWorksheet("Student Attendance Roster", {
    views: [{ showGridLines: true }],
  });

  // Header Row
  rosterSheet.addRow([
    "S.No",
    "Register Number",
    "Student Full Name",
    "Class & Section",
    "Department",
    "Morning Status",
    "Afternoon Status",
    "Attendance Note",
  ]);

  rosterSheet.getRow(1).height = 24;
  rosterSheet.getRow(1).eachCell((cell) => {
    cell.font = { name: "Arial", size: 9, bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: BLUE_HEADER } };
    cell.alignment = { horizontal: "center", vertical: "middle" };
  });

  let globalStudentCount = 0;
  classDataList.forEach((cls) => {
    (cls.roster || []).forEach((st) => {
      globalStudentCount++;
      const m = (st.morningStatus || "unmarked").toUpperCase();
      const a = (st.afternoonStatus || "unmarked").toUpperCase();

      let note = "Normal";
      if (m === "PRESENT" && a === "ABSENT") note = "Left After Morning";
      else if (m === "PRESENT" && a === "BUNK") note = "Bunked Afternoon";
      else if (m === "ABSENT" && a === "PRESENT") note = "Joined in Afternoon";
      else if (m === "ABSENT" && a === "ABSENT") note = "Full Day Absent";
      else if (m === "OD" || a === "OD") note = "On Duty";

      const row = rosterSheet.addRow([
        globalStudentCount,
        st.registerNumber,
        st.fullName,
        cls.className,
        cls.department,
        m,
        a,
        note,
      ]);

      row.height = 18;
      row.eachCell((cell, colNum) => {
        cell.font = { name: "Arial", size: 9 };
        cell.alignment = {
          vertical: "middle",
          horizontal: colNum === 3 || colNum === 5 ? "left" : "center",
        };

        // Status highlight fills
        if (colNum === 6 || colNum === 7) {
          const val = cell.value;
          if (val === "PRESENT") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFDCFCE7" } };
          else if (val === "ABSENT") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFEE2E2" } };
          else if (val === "OD") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE0E7FF" } };
          else if (val === "BUNK") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFEDD5" } };
          else cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFF1F5F9" } };
        }
      });
    });
  });

  rosterSheet.columns = [
    { width: 8 },  // S.No
    { width: 18 }, // Reg No
    { width: 28 }, // Full Name
    { width: 16 }, // Class
    { width: 26 }, // Department
    { width: 16 }, // Morning Status
    { width: 16 }, // Afternoon Status
    { width: 22 }, // Note
  ];

  // --------------------------------------------------------------------------
  // SHEET 3: Absentees & OD Students
  // --------------------------------------------------------------------------
  const absSheet = workbook.addWorksheet("Absentees & OD List", {
    views: [{ showGridLines: true }],
  });

  absSheet.addRow([
    "S.No",
    "Register Number",
    "Student Name",
    "Class",
    "Department",
    "Morning Status",
    "Afternoon Status",
    "Reason / Category",
  ]);

  absSheet.getRow(1).height = 24;
  absSheet.getRow(1).eachCell((cell) => {
    cell.font = { name: "Arial", size: 9, bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFB91C1C" } };
    cell.alignment = { horizontal: "center", vertical: "middle" };
  });

  let absCount = 0;
  classDataList.forEach((cls) => {
    (cls.roster || []).forEach((st) => {
      const m = (st.morningStatus || "unmarked").toUpperCase();
      const a = (st.afternoonStatus || "unmarked").toUpperCase();

      const isAbsentOrOd =
        m === "ABSENT" || a === "ABSENT" || m === "OD" || a === "OD" || a === "BUNK";

      if (isAbsentOrOd) {
        absCount++;
        let category = "Absent";
        if (m === "OD" || a === "OD") category = "On Duty (OD)";
        if (a === "BUNK") category = "Bunked Class";

        const row = absSheet.addRow([
          absCount,
          st.registerNumber,
          st.fullName,
          cls.className,
          cls.department,
          m,
          a,
          category,
        ]);
        row.height = 18;
        row.eachCell((cell, colNum) => {
          cell.font = { name: "Arial", size: 9 };
          cell.alignment = {
            vertical: "middle",
            horizontal: colNum === 3 || colNum === 5 ? "left" : "center",
          };
          if (colNum === 6 || colNum === 7) {
            const val = cell.value;
            if (val === "ABSENT") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFEE2E2" } };
            else if (val === "OD") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFE0E7FF" } };
            else if (val === "BUNK") cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFEDD5" } };
          }
        });
      }
    });
  });

  absSheet.columns = [
    { width: 8 },  // S.No
    { width: 18 }, // Reg No
    { width: 28 }, // Full Name
    { width: 16 }, // Class
    { width: 26 }, // Department
    { width: 16 }, // Morning Status
    { width: 16 }, // Afternoon Status
    { width: 22 }, // Category
  ];

  // Output destination
  const targetPath =
    outputPath ||
    path.join(
      process.cwd(),
      "temp",
      `Attendance_Report_${dateStr.replace(/-/g, "")}.xlsx`
    );

  const dir = path.dirname(targetPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  await workbook.xlsx.writeFile(targetPath);
  return targetPath;
}

