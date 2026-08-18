import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = resolve(root, "images");
mkdirSync(outputDir, { recursive: true });

const C = {
  navy: "#071827",
  navy2: "#0f2740",
  blue: "#2563eb",
  teal: "#0f766e",
  cyan: "#14b8a6",
  mint: "#5eead4",
  coral: "#f97360",
  amber: "#f59e0b",
  paper: "#ffffff",
  light: "#f7fafc",
  soft: "#eef6ff",
  text: "#172033",
  muted: "#5f6f89",
  border: "#dbe4ef",
};

const esc = (value) => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;");

const text = (x, y, value, size = 26, weight = 600, fill = C.text, anchor = "start") =>
  `<text x="${x}" y="${y}" font-family="Arial, Helvetica, sans-serif" font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}">${esc(value)}</text>`;

const rounded = (x, y, width, height, fill = C.paper, radius = 20, stroke = C.border, strokeWidth = 2) =>
  `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="${radius}" fill="${fill}" stroke="${stroke}" stroke-width="${strokeWidth}"/>`;

const pill = (x, y, width, value, fill = "#d8faf4", color = C.teal) =>
  `${rounded(x, y, width, 42, fill, 21, "none", 0)}${text(x + width / 2, y + 28, value, 18, 700, color, "middle")}`;

const base = ({ title, subtitle, status, body }) => `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="720" viewBox="0 0 1200 720" role="img" aria-labelledby="title desc">
  <title id="title">${esc(title)}</title>
  <desc id="desc">${esc(subtitle)}. Concept preview using fictional data.</desc>
  <defs>
    <linearGradient id="header" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${C.navy}"/>
      <stop offset="1" stop-color="${C.navy2}"/>
    </linearGradient>
    <linearGradient id="tealFade" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="${C.blue}"/>
      <stop offset="1" stop-color="${C.cyan}"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#071827" flood-opacity="0.12"/>
    </filter>
  </defs>
  <rect width="1200" height="720" rx="30" fill="${C.light}"/>
  <rect width="1200" height="100" rx="30" fill="url(#header)"/>
  <rect y="72" width="1200" height="28" fill="url(#header)"/>
  <rect x="42" y="25" width="52" height="52" rx="14" fill="${C.mint}"/>
  ${text(68, 60, "PM", 23, 900, C.navy, "middle")}
  ${text(116, 50, title, 27, 800, C.paper)}
  ${text(116, 77, subtitle, 16, 500, "#cfe0f3")}
  ${pill(875, 29, 280, status, "#16344f", "#c9fff5")}
  ${body}
</svg>`;

const kpi = (x, label, value, note, accent = C.cyan) => `
  <g filter="url(#shadow)">
    ${rounded(x, 126, 252, 128)}
  </g>
  <rect x="${x}" y="126" width="9" height="128" rx="5" fill="${accent}"/>
  ${text(x + 28, 158, label.toUpperCase(), 15, 800, C.muted)}
  ${text(x + 28, 205, value, 34, 900, C.text)}
  ${text(x + 28, 233, note, 15, 500, C.muted)}
`;

const panel = (x, y, width, height, titleValue, content) => `
  ${rounded(x, y, width, height, C.paper, 22)}
  ${text(x + 26, y + 38, titleValue, 20, 800, C.text)}
  ${content}
`;

const lineChart = (x, y, width, height, values, labels, color = C.blue) => {
  const min = Math.min(...values) * 0.92;
  const max = Math.max(...values) * 1.06;
  const points = values.map((value, index) => {
    const px = x + (index * width) / (values.length - 1);
    const py = y + height - ((value - min) / (max - min || 1)) * height;
    return [px, py];
  });
  const path = points.map(([px, py], index) => `${index ? "L" : "M"}${px.toFixed(1)} ${py.toFixed(1)}`).join(" ");
  return `
    <line x1="${x}" y1="${y + height}" x2="${x + width}" y2="${y + height}" stroke="${C.border}" stroke-width="2"/>
    <line x1="${x}" y1="${y + height / 2}" x2="${x + width}" y2="${y + height / 2}" stroke="${C.border}" stroke-width="1" stroke-dasharray="6 8"/>
    <path d="${path}" fill="none" stroke="${color}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
    ${points.map(([px, py]) => `<circle cx="${px}" cy="${py}" r="7" fill="${C.paper}" stroke="${color}" stroke-width="5"/>`).join("")}
    ${labels.map((label, index) => text(x + (index * width) / (labels.length - 1), y + height + 28, label, 14, 600, C.muted, "middle")).join("")}
  `;
};

const bars = (x, y, values, labels, width = 310, barHeight = 28, color = C.teal) => values.map((value, index) => {
  const yy = y + index * 58;
  return `
    ${text(x, yy + 18, labels[index], 15, 700, C.text)}
    <rect x="${x + 118}" y="${yy}" width="${width}" height="${barHeight}" rx="${barHeight / 2}" fill="#e8eef5"/>
    <rect x="${x + 118}" y="${yy}" width="${Math.max(8, width * value / 100)}" height="${barHeight}" rx="${barHeight / 2}" fill="${color}"/>
    ${text(x + 118 + width + 18, yy + 20, `${value}%`, 15, 800, C.muted)}
  `;
}).join("");

const output = (name, svg) => writeFileSync(resolve(outputDir, name), `${svg}\n`, "utf8");

output("essential-insights-preview.svg", base({
  title: "Essential Insights",
  subtitle: "Readiness, descriptives, supported visuals, and findings",
  status: "Concept preview • Fictional data",
  body: `
    ${kpi(42, "Rows reviewed", "1,248", "one eligible CSV", C.blue)}
    ${kpi(314, "Fields reviewed", "12", "structured variables", C.cyan)}
    ${kpi(586, "Readiness score", "84 / 100", "review recommended", C.teal)}
    ${kpi(858, "Priority checks", "3", "before final use", C.coral)}
    ${panel(42, 282, 708, 390, "Records by reporting month", `
      ${text(68, 344, "A stable monthly pattern with a small increase in June", 16, 500, C.muted)}
      ${lineChart(90, 386, 610, 185, [168, 184, 177, 203, 222, 248], ["Jan", "Feb", "Mar", "Apr", "May", "Jun"], C.blue)}
      ${pill(68, 610, 246, "Supported static visual", "#e9f2ff", C.blue)}
    `)}
    ${panel(774, 282, 384, 390, "Data-quality checks", `
      ${bars(800, 358, [97, 99, 94], ["Complete", "Unique", "Valid"], 170, 24, C.cyan)}
      <rect x="800" y="548" width="332" height="92" rx="16" fill="#fff4ef" stroke="#ffd1c7"/>
      ${text(822, 580, "Priority finding", 16, 800, C.coral)}
      ${text(822, 607, "Review missing outcome dates", 16, 700, C.text)}
      ${text(822, 630, "before interpreting trends.", 15, 500, C.muted)}
    `)}
  `,
}));

output("studio-concept-preview.svg", base({
  title: "ProgramMetrics Studio",
  subtitle: "A bounded, browser-based analysis workflow",
  status: "Planned private-app concept",
  body: `
    ${kpi(42, "Data boundary", "De-identified", "structured CSV only", C.cyan)}
    ${kpi(314, "Processing design", "Browser-local", "by default", C.blue)}
    ${kpi(586, "Access model", "Plan limits", "monthly allowance", C.teal)}
    ${kpi(858, "Current status", "Planned", "subscriptions unavailable", C.coral)}
    ${panel(42, 282, 760, 390, "Planned analysis path", `
      <line x1="154" y1="470" x2="690" y2="470" stroke="${C.border}" stroke-width="8" stroke-linecap="round"/>
      ${[
        [92, "1", "Readiness", "check structure"],
        [274, "2", "Descriptives", "summarize data"],
        [456, "3", "Visuals", "show patterns"],
        [638, "4", "Findings", "support review"],
      ].map(([x, number, label, note], index) => `
        <circle cx="${x + 54}" cy="470" r="42" fill="${index === 3 ? C.coral : index === 2 ? C.cyan : index === 1 ? C.teal : C.blue}"/>
        ${text(x + 54, 479, number, 26, 900, C.paper, "middle")}
        ${text(x + 54, 548, label, 18, 800, C.text, "middle")}
        ${text(x + 54, 573, note, 14, 500, C.muted, "middle")}
      `).join("")}
      ${pill(68, 616, 336, "Customer review remains required", "#e8faf7", C.teal)}
    `)}
    ${panel(826, 282, 332, 390, "Defined outputs", `
      ${[
        [340, "PDF summary", "Readiness and findings", C.blue],
        [430, "Analysis CSV", "Structured results", C.teal],
        [520, "Combined PNG", "Supported visuals", C.coral],
      ].map(([y, label, note, accent]) => `
        <rect x="852" y="${y}" width="280" height="74" rx="15" fill="${C.light}" stroke="${C.border}"/>
        <rect x="852" y="${y}" width="8" height="74" rx="4" fill="${accent}"/>
        ${text(878, y + 30, label, 17, 800, C.text)}
        ${text(878, y + 55, note, 14, 500, C.muted)}
      `).join("")}
      ${text(992, 628, "Availability is stated before access.", 14, 600, C.muted, "middle")}
    `)}
  `,
}));

output("starter-workbooks-preview.svg", base({
  title: "Starter Workbook Collection",
  subtitle: "Formula-driven Excel starters for defined reporting tasks",
  status: "Release pending • Fictional data",
  body: `
    ${[
      [42, 132, "Program Evaluation", "Measures • targets • trends", C.blue, [42, 68, 55, 84]],
      [610, 132, "Monthly Reporting", "Due dates • checks • readiness", C.teal, [72, 85, 78, 96]],
      [42, 406, "Referral & Service Tracking", "Connections • follow-up • gaps", C.coral, [34, 58, 71, 77]],
      [610, 406, "Survey Reporting", "Completion • scores • waves", C.cyan, [66, 73, 81, 89]],
    ].map(([x, y, titleValue, subtitleValue, accent, values]) => `
      <g filter="url(#shadow)">${rounded(x, y, 548, 234, C.paper, 22)}</g>
      <rect x="${x}" y="${y}" width="10" height="234" rx="5" fill="${accent}"/>
      ${text(x + 30, y + 43, titleValue, 23, 800, C.text)}
      ${text(x + 30, y + 72, subtitleValue, 15, 500, C.muted)}
      <line x1="${x + 32}" y1="${y + 186}" x2="${x + 510}" y2="${y + 186}" stroke="${C.border}" stroke-width="2"/>
      ${values.map((value, index) => `<rect x="${x + 54 + index * 100}" y="${y + 190 - value}" width="58" height="${value}" rx="8" fill="${index === values.length - 1 ? accent : "#cbd8e8"}"/>`).join("")}
      ${pill(x + 338, y + 24, 178, "Planned Starter", "#eef4fb", C.muted)}
    `).join("")}
  `,
}));

output("product-paths-preview.svg", base({
  title: "Choose a ProgramMetrics Path",
  subtitle: "Each offer has its own scope, access, and terms",
  status: "Current public offer map",
  body: `
    ${[
      [42, "Essential Insights", "Controlled beta", "$49 fixed scope", "One eligible CSV", "PDF • analysis CSV • PNG", C.blue],
      [426, "Studio", "Planned", "Recurring access", "Defined plan limits", "Private application", C.teal],
      [810, "Starter Workbooks", "Release pending", "Separate tools", "Defined reporting tasks", "Future license terms", C.coral],
    ].map(([x, titleValue, statusValue, line1, line2, line3, accent]) => `
      <g filter="url(#shadow)">${rounded(x, 142, 348, 502, C.paper, 24)}</g>
      <rect x="${x}" y="142" width="348" height="12" rx="6" fill="${accent}"/>
      <circle cx="${x + 58}" cy="214" r="26" fill="${accent}" opacity="0.16"/>
      <circle cx="${x + 58}" cy="214" r="10" fill="${accent}"/>
      ${text(x + 100, 207, titleValue, 23, 800, C.text)}
      ${text(x + 100, 234, statusValue, 16, 700, accent)}
      <line x1="${x + 28}" y1="268" x2="${x + 320}" y2="268" stroke="${C.border}" stroke-width="2"/>
      ${[
        [320, line1], [384, line2], [448, line3]
      ].map(([y, value]) => `
        <circle cx="${x + 46}" cy="${y - 7}" r="7" fill="${accent}"/>
        ${text(x + 68, y, value, 17, 700, C.text)}
      `).join("")}
      <rect x="${x + 28}" y="520" width="292" height="88" rx="16" fill="${C.light}"/>
      ${text(x + 174, 555, x === 42 ? "Available to selected testers" : "Public access unavailable", 15, 800, C.text, "middle")}
      ${text(x + 174, 583, "Review scope before access", 14, 500, C.muted, "middle")}
    `).join("")}
  `,
}));

output("program-evaluation-dashboard-preview.svg", base({
  title: "Program Evaluation Dashboard",
  subtitle: "Activity, service connection, outcomes, and targets",
  status: "Concept preview • Fictional data",
  body: `
    ${kpi(42, "People served", "246", "+18 this quarter", C.blue)}
    ${kpi(314, "Connected", "78%", "of eligible referrals", C.teal)}
    ${kpi(586, "Outcome target", "92%", "goal progress", C.cyan)}
    ${kpi(858, "Reporting period", "Q3 2026", "synthetic example", C.coral)}
    ${panel(42, 282, 694, 390, "Monthly participation", `
      ${lineChart(84, 372, 610, 188, [31, 38, 35, 44, 46, 52], ["Apr", "May", "Jun", "Jul", "Aug", "Sep"], C.blue)}
      ${pill(68, 610, 216, "Goal line: 45 / month", "#e9f2ff", C.blue)}
    `)}
    ${panel(760, 282, 398, 390, "Outcome progress", `
      ${bars(788, 356, [92, 78, 68], ["Goal", "Connected", "Follow-up"], 176, 25, C.teal)}
      <rect x="788" y="548" width="342" height="90" rx="16" fill="#eef9f7" stroke="#bdebe2"/>
      ${text(810, 580, "Leadership note", 16, 800, C.teal)}
      ${text(810, 608, "Connection rate improved 6 points", 15, 700, C.text)}
      ${text(810, 631, "from the prior quarter.", 14, 500, C.muted)}
    `)}
  `,
}));

output("monthly-reporting-dashboard-preview.svg", base({
  title: "Monthly Reporting Automation",
  subtitle: "Source status, validation checks, deadlines, and readiness",
  status: "Concept preview • Fictional data",
  body: `
    ${kpi(42, "Sources received", "8 / 8", "all expected files", C.blue)}
    ${kpi(314, "Validation", "Complete", "rules applied", C.teal)}
    ${kpi(586, "Items to review", "2", "before final report", C.coral)}
    ${kpi(858, "Report status", "Ready", "for staff review", C.cyan)}
    ${panel(42, 282, 650, 390, "Six-month reporting volume", `
      ${lineChart(84, 382, 560, 176, [142, 159, 151, 171, 166, 184], ["Mar", "Apr", "May", "Jun", "Jul", "Aug"], C.teal)}
      ${pill(68, 610, 264, "Recurring monthly summary", "#e8faf7", C.teal)}
    `)}
    ${panel(716, 282, 442, 390, "Reporting checklist", `
      ${[
        [352, "Source refresh", "Complete", C.teal],
        [420, "Required fields", "Complete", C.teal],
        [488, "Outlier review", "2 items", C.coral],
        [556, "Leadership export", "Ready", C.blue],
      ].map(([y, label, statusValue, accent]) => `
        <circle cx="752" cy="${y - 6}" r="10" fill="${accent}"/>
        ${text(778, y, label, 16, 700, C.text)}
        ${text(1122, y, statusValue, 15, 800, accent, "end")}
        <line x1="752" y1="${y + 24}" x2="1128" y2="${y + 24}" stroke="${C.border}"/>
      `).join("")}
      ${text(936, 638, "Formula-driven Starter workbook", 14, 600, C.muted, "middle")}
    `)}
  `,
}));

output("referral-tracker-dashboard-preview.svg", base({
  title: "Referral & Service Tracking",
  subtitle: "Connections, elapsed days, follow-up, and service gaps",
  status: "Concept preview • Fictional data",
  body: `
    ${kpi(42, "Referrals", "312", "current period", C.blue)}
    ${kpi(314, "Connected", "74%", "service connection", C.teal)}
    ${kpi(586, "Median days", "6", "referral to service", C.cyan)}
    ${kpi(858, "Follow-up due", "18", "needs staff review", C.coral)}
    ${panel(42, 282, 686, 390, "Referral flow", `
      ${[
        [84, 362, 580, "Referred", "312", C.blue],
        [116, 428, 516, "Contacted", "278", C.cyan],
        [148, 494, 452, "Connected", "231", C.teal],
        [180, 560, 388, "Completed follow-up", "196", C.navy2],
      ].map(([x, y, width, label, value, accent]) => `
        <rect x="${x}" y="${y}" width="${width}" height="46" rx="13" fill="${accent}" opacity="0.92"/>
        ${text(x + 18, y + 30, label, 16, 800, C.paper)}
        ${text(x + width - 18, y + 30, value, 17, 900, C.paper, "end")}
      `).join("")}
      ${text(385, 642, "Each stage uses de-identified operational records", 14, 600, C.muted, "middle")}
    `)}
    ${panel(752, 282, 406, 390, "Follow-up status", `
      ${bars(780, 356, [58, 29, 13], ["On time", "Due soon", "Overdue"], 170, 25, C.coral)}
      <rect x="780" y="548" width="350" height="90" rx="16" fill="#fff4ef" stroke="#ffd1c7"/>
      ${text(804, 581, "Action queue", 16, 800, C.coral)}
      ${text(804, 609, "18 follow-ups need review", 16, 700, C.text)}
      ${text(804, 632, "before the next reporting cycle.", 14, 500, C.muted)}
    `)}
  `,
}));

output("survey-reporting-dashboard-preview.svg", base({
  title: "Survey Reporting Dashboard",
  subtitle: "Response monitoring, scores, waves, and broad group views",
  status: "Concept preview • Fictional data",
  body: `
    ${kpi(42, "Responses", "184", "structured records", C.blue)}
    ${kpi(314, "Completion", "91%", "required items", C.teal)}
    ${kpi(586, "Average score", "4.2 / 5", "fictional scale", C.cyan)}
    ${kpi(858, "Survey waves", "3", "current comparison", C.coral)}
    ${panel(42, 282, 670, 390, "Average score by survey wave", `
      ${lineChart(84, 382, 580, 176, [3.6, 3.9, 4.2], ["Wave 1", "Wave 2", "Wave 3"], C.blue)}
      ${pill(68, 610, 264, "Scores shown without open text", "#e9f2ff", C.blue)}
    `)}
    ${panel(736, 282, 422, 390, "Response distribution", `
      ${bars(764, 350, [12, 18, 27, 43], ["1–2", "3", "4", "5"], 174, 25, C.cyan)}
      <rect x="764" y="586" width="366" height="52" rx="15" fill="#eef9f7"/>
      ${text(947, 619, "Broad groups only • fictional data", 14, 700, C.teal, "middle")}
    `)}
  `,
}));

console.log("Generated 8 ProgramMetrics site visuals in images/.");
