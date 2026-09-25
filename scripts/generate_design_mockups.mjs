import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const outDir = "DesignMockups";
mkdirSync(outDir, { recursive: true });

const W = 390;
const H = 844;
const colors = {
  paper: "#EAEAE6",
  ink: "#1A1917",
  dim: "#85847C",
  faint: "#C2BFB7",
  line: "#D7D3CA",
  accent: "#E38A1D",
  glass: "rgba(255,255,255,.54)",
  blue: "#6FA9D7",
  green: "#7DAA82",
  rose: "#D58D74",
};

const font = `font-family:-apple-system,BlinkMacSystemFont,SF Pro Display,Helvetica Neue,Arial,sans-serif`;
const mono = `font-family:SF Mono,SFMono-Regular,Menlo,monospace`;

function svg(name, active, body) {
  const tabs = [
    ["Horloges", "clock"],
    ["Météo", "weather"],
    ["Grand format", "gauge"],
    ["Réglages", "gear"],
  ];

  const tabWidth = 88;
  const tabX = 19;
  const tabItems = tabs.map(([label, icon], index) => {
    const x = tabX + index * tabWidth;
    const isActive = label === active;
    return `
      ${isActive ? `<rect x="${x + 5}" y="766" width="78" height="52" rx="26" fill="rgba(255,255,255,.72)" stroke="rgba(255,255,255,.92)"/>` : ""}
      ${iconGlyph(icon, x + 44, 784, isActive ? colors.ink : colors.dim)}
      <text x="${x + 44}" y="806" text-anchor="middle" style="${font};font-size:8.2px;font-weight:800;letter-spacing:.6px" fill="${isActive ? colors.ink : colors.dim}">${label.toUpperCase()}</text>`;
  }).join("");

  const doc = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
    <defs>
      <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="12" stdDeviation="16" flood-color="#000" flood-opacity=".16"/>
        <feDropShadow dx="0" dy="1" stdDeviation="2" flood-color="#000" flood-opacity=".08"/>
      </filter>
      <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#1A1917" flood-opacity=".10"/>
      </filter>
      <linearGradient id="addGradient" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#F6CC88"/>
        <stop offset=".45" stop-color="#9ED1E2"/>
        <stop offset="1" stop-color="#5F92C9"/>
      </linearGradient>
      <linearGradient id="skyBand" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#EEC778"/>
        <stop offset=".55" stop-color="#EAEAE6"/>
        <stop offset="1" stop-color="#91B6D6"/>
      </linearGradient>
      <clipPath id="screenClip"><rect x="0" y="0" width="${W}" height="${H}" rx="38"/></clipPath>
    </defs>
    <rect width="${W}" height="${H}" rx="38" fill="${colors.paper}"/>
    <g clip-path="url(#screenClip)">
      ${topBar()}
      <line x1="0" x2="${W}" y1="92" y2="92" stroke="${colors.line}"/>
      ${body}
      <g filter="url(#shadow)">
        <rect x="14" y="758" width="362" height="68" rx="34" fill="${colors.glass}" stroke="rgba(255,255,255,.72)"/>
        <rect x="14.5" y="758.5" width="361" height="67" rx="33.5" fill="none" stroke="rgba(26,25,23,.08)"/>
        ${tabItems}
      </g>
    </g>
  </svg>`;

  writeFileSync(join(outDir, name), doc.trim());
}

function topBar() {
  return `
    <g transform="translate(22 55)">
      <path d="M2 4 L8.5 20 L15 5 L21.5 20 L28 4" fill="none" stroke="${colors.ink}" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="30" cy="16" r="2.7" fill="${colors.accent}"/>
    </g>
    <g transform="translate(286 52)">
      <rect width="82" height="31" rx="8" fill="none" stroke="${colors.faint}"/>
      <rect x="4" y="4" width="36" height="23" rx="6" fill="${colors.ink}"/>
      <text x="22" y="20" text-anchor="middle" style="${font};font-size:10.5px;font-weight:800" fill="${colors.paper}">12h</text>
      <text x="60" y="20" text-anchor="middle" style="${font};font-size:10.5px;font-weight:800" fill="${colors.ink}">24h</text>
    </g>`;
}

function iconGlyph(type, cx, cy, color) {
  if (type === "clock") return `<circle cx="${cx}" cy="${cy}" r="8" fill="none" stroke="${color}" stroke-width="1.7"/><path d="M${cx} ${cy - 5} V${cy + 1} L${cx + 4} ${cy + 3}" fill="none" stroke="${color}" stroke-width="1.7" stroke-linecap="round"/>`;
  if (type === "weather") return `<circle cx="${cx - 4}" cy="${cy - 4}" r="5" fill="none" stroke="${color}" stroke-width="1.6"/><path d="M${cx - 11} ${cy + 5} H${cx + 9} C${cx + 15} ${cy + 5} ${cx + 15} ${cy - 4} ${cx + 8} ${cy - 3} C${cx + 6} ${cy - 10} ${cx - 5} ${cy - 9} ${cx - 6} ${cy - 2}" fill="none" stroke="${color}" stroke-width="1.7" stroke-linecap="round"/>`;
  if (type === "gauge") return `<path d="M${cx - 10} ${cy + 7} A10 10 0 0 1 ${cx + 10} ${cy + 7}" fill="none" stroke="${color}" stroke-width="1.7" stroke-linecap="round"/><path d="M${cx} ${cy + 6} L${cx + 6} ${cy - 2}" stroke="${color}" stroke-width="1.8" stroke-linecap="round"/><circle cx="${cx}" cy="${cy + 6}" r="1.8" fill="${color}"/>`;
  return `<circle cx="${cx}" cy="${cy}" r="7" fill="none" stroke="${color}" stroke-width="1.7"/><path d="M${cx} ${cy - 12} V${cy - 9} M${cx} ${cy + 9} V${cy + 12} M${cx - 12} ${cy} H${cx - 9} M${cx + 9} ${cy} H${cx + 12}" stroke="${color}" stroke-width="1.7" stroke-linecap="round"/>`;
}

function text(x, y, value, size, weight = 600, fill = colors.ink, extra = "") {
  return `<text x="${x}" y="${y}" style="${font};font-size:${size}px;font-weight:${weight};${extra}" fill="${fill}">${value}</text>`;
}

function monoText(x, y, value, size, weight = 500, fill = colors.ink, extra = "") {
  return `<text x="${x}" y="${y}" style="${mono};font-size:${size}px;font-weight:${weight};${extra}" fill="${fill}">${value}</text>`;
}

function divider(y) {
  return `<line x1="20" x2="370" y1="${y}" y2="${y}" stroke="${colors.line}"/>`;
}

function chip(x, y, w, label, active = false) {
  return `<rect x="${x}" y="${y}" width="${w}" height="25" rx="7" fill="${active ? colors.ink : "transparent"}" stroke="${active ? colors.ink : colors.faint}"/><text x="${x + w / 2}" y="${y + 17}" text-anchor="middle" style="${font};font-size:10.5px;font-weight:800" fill="${active ? colors.paper : colors.ink}">${label}</text>`;
}

function switcher(x, y, on = true) {
  return `<rect x="${x}" y="${y}" width="50" height="29" rx="14.5" fill="${on ? colors.accent : colors.faint}"/><circle cx="${on ? x + 35 : x + 15}" cy="${y + 14.5}" r="11.5" fill="#fff"/>`;
}

svg("01-horloges.svg", "Horloges", `
  <g transform="translate(20 121)">
    ${text(0, 0, "HORLOGES", 12, 800, colors.accent, "letter-spacing:2.4px")}
    ${text(0, 31, "Villes suivies", 28, 750)}
    ${text(0, 53, "Fuseaux, météo rapide et pluie à venir", 12, 500, colors.dim)}
  </g>
  <g transform="translate(20 195)">
    ${cityRow(0, "UTC+2", "PARIS", "France", "18° · ciel clair", "08:42", "am", true)}
    ${cityRow(99, "UTC-4", "NEW YORK", "États-Unis", "21° · pluie vers 11 am", "02:42", "am")}
    ${cityRow(198, "UTC+9", "TOKYO", "Japon", "26° · couvert", "15:42", "pm")}
    ${cityRow(297, "UTC+1", "LONDRES", "Royaume-Uni", "17° · vent léger", "07:42", "am")}
  </g>
  <g transform="translate(20 606)" filter="url(#soft)">
    <rect width="350" height="132" rx="24" fill="url(#addGradient)"/>
    <circle cx="49" cy="43" r="21" fill="rgba(255,255,255,.28)"/>
    <path d="M48 22 V12 M48 74 V64 M27 43 H17 M79 43 H69 M33 28 L26 21 M63 59 L70 66 M33 59 L26 66 M63 28 L70 21" stroke="rgba(255,255,255,.75)" stroke-width="2" stroke-linecap="round"/>
    ${text(20, 99, "Ajouter une ville", 15, 750, "#fff")}
    ${text(20, 118, "ville · pays · région", 11, 500, "rgba(255,255,255,.85)")}
    <circle cx="317" cy="34" r="19" fill="#fff"/>
    <path d="M317 25 V43 M308 34 H326" stroke="${colors.ink}" stroke-width="2.2" stroke-linecap="round"/>
  </g>
`);

function cityRow(y, utc, name, sub, wx, timeValue, suffix, starred = false) {
  return `<g transform="translate(0 ${y})">
    ${text(0, 0, utc, 10.5, 800, colors.dim, "letter-spacing:1.5px")}
    ${text(0, 30, name, 20, 750, colors.ink, "letter-spacing:.7px")}
    ${starred ? `<path d="M84 17 L87 23 L94 24 L89 29 L90 36 L84 32 L78 36 L79 29 L74 24 L81 23 Z" fill="${colors.accent}"/>` : ""}
    ${text(0, 50, sub, 11.5, 500, colors.dim)}
    <circle cx="7" cy="68" r="5" fill="none" stroke="${colors.accent}" stroke-width="1.5"/>
    ${text(19, 72, wx, 12.5, 650)}
    ${monoText(196, 37, timeValue, 42, 500, colors.ink, "letter-spacing:1px")}
    <circle cx="332" cy="14" r="2.1" fill="${colors.dim}"/>
    ${text(325, 35, suffix, 9, 800, colors.dim, "letter-spacing:1px")}
    ${divider(88)}
  </g>`;
}

svg("02-meteo.svg", "Météo", `
  <g transform="translate(20 127)">
    ${text(0, 0, "PARIS", 13, 800, colors.accent, "letter-spacing:2px")}
    ${text(0, 30, "Jeudi,", 15, 700, colors.dim)}
    ${text(0, 52, "3 septembre", 15, 750, colors.ink)}
    ${monoText(228, 48, "18°", 58, 800, colors.ink)}
    ${text(265, 71, "CIEL CLAIR", 11.5, 750, colors.dim, "letter-spacing:1.2px")}
    ${text(67, 91, "PAS DE PLUIE PRÉVUE — 24 H", 10, 800, colors.dim, "letter-spacing:1.4px")}
  </g>
  <g transform="translate(45 256)">
    <circle cx="150" cy="150" r="139" fill="url(#skyBand)" opacity=".42"/>
    ${globeDots()}
    <circle cx="178" cy="96" r="7" fill="${colors.accent}"/>
    <circle cx="178" cy="96" r="14" fill="none" stroke="${colors.accent}" stroke-width="1.4"/>
    <circle cx="85" cy="141" r="4" fill="${colors.dim}"/>
    <circle cx="233" cy="126" r="4" fill="${colors.dim}"/>
  </g>
  <g transform="translate(27 582)">
    ${sunCell(0, "☀", "06:58", "LEVER")}
    ${text(147, 21, "13 h 12", 14, 650, colors.dim, `${mono}`)}
    ${text(156, 39, "DURÉE", 9, 800, colors.dim, "letter-spacing:1.6px")}
    ${sunCell(266, "◐", "20:10", "COUCHER")}
  </g>
  <path d="M24 687 C114 610 276 610 366 687" fill="none" stroke="${colors.ink}" stroke-width="2.3" stroke-linecap="round" stroke-dasharray="0.1 9"/>
  <path d="M24 687 C114 610 276 610 366 687" fill="none" stroke="${colors.faint}" stroke-width="1.8" stroke-linecap="round" stroke-dasharray="0.1 8"/>
  <circle cx="238" cy="633" r="6" fill="${colors.accent}"/>
`);

function globeDots() {
  let dots = "";
  for (let row = -10; row <= 10; row++) {
    const y = 150 + row * 12;
    const span = Math.sqrt(Math.max(0, 1 - (row / 10.5) ** 2)) * 126;
    for (let x = -span; x <= span; x += 12) {
      const wobble = Math.sin((x + row * 17) * 0.035) * 3;
      const fill = (x + row * 7) % 5 === 0 ? colors.dim : colors.faint;
      dots += `<circle cx="${150 + x}" cy="${y + wobble}" r="1.9" fill="${fill}" opacity=".72"/>`;
    }
  }
  return dots;
}

function sunCell(x, icon, value, label) {
  return `<g transform="translate(${x} 0)">
    <text x="0" y="24" style="${font};font-size:18px;font-weight:700" fill="${colors.accent}">${icon}</text>
    ${monoText(28, 22, value, 15, 650)}
    ${text(28, 40, label, 9.5, 800, colors.dim, "letter-spacing:1.6px")}
  </g>`;
}

svg("03-grand-format.svg", "Grand format", `
  <g transform="translate(20 128)">
    ${text(0, 0, "PARIS", 17, 800, colors.ink, "letter-spacing:.6px")}
    ${text(0, 22, "France", 12, 500, colors.dim)}
    ${text(305, 10, "UTC+2", 11, 800, colors.accent, "letter-spacing:1.4px")}
  </g>
  <g transform="translate(20 178)">
    ${monoText(0, 92, "08", 104, 200, colors.faint, "letter-spacing:2px")}
    ${text(148, 86, "h", 13, 750, colors.dim)}
    ${divider(117)}
    ${monoText(18, 209, "42", 104, 300, colors.dim, "letter-spacing:2px")}
    ${text(166, 203, "min", 13, 750, colors.dim)}
    ${divider(234)}
    ${monoText(18, 326, "17", 84, 800, colors.ink, "letter-spacing:2px")}
    ${text(143, 315, "sec", 13, 750, colors.dim)}
  </g>
  <g transform="translate(20 592)">
    <path d="M22 118 A153 153 0 0 1 328 118" fill="none" stroke="${colors.faint}" stroke-width="1.2" stroke-dasharray="0.1 7" stroke-linecap="round"/>
    <path d="M48 96 L58 90 M86 54 L94 63 M175 31 L175 44 M264 54 L256 63 M302 96 L292 90" stroke="${colors.faint}" stroke-width="1.1" stroke-linecap="round"/>
    ${dialCity(82, 88, "NYC")}
    ${dialCity(268, 88, "TYO")}
    ${dialCity(211, 51, "LDN")}
    <circle cx="175" cy="20" r="5.5" fill="${colors.accent}"/>
    <circle cx="175" cy="20" r="10.5" fill="none" stroke="${colors.accent}" stroke-width="1.4"/>
    ${text(164, 2, "PAR", 13, 850)}
    ${text(134, 154, "PARIS", 11, 850, colors.ink, "letter-spacing:3px")}
    <circle cx="175" cy="169" r="3" fill="${colors.accent}"/>
  </g>
`);

function dialCity(x, y, label) {
  return `<circle cx="${x}" cy="${y}" r="3" fill="${colors.dim}"/>${text(x - 10, y - 12, label, 10, 750, colors.dim)}`;
}

svg("04-reglages.svg", "Réglages", `
  <g transform="translate(20 124)">
    ${text(0, 0, "RÉGLAGES", 12, 800, colors.accent, "letter-spacing:2.4px")}
    ${text(0, 32, "Préférences", 28, 750)}
    ${text(0, 55, "Unités, alertes pluie et synchronisation", 12, 500, colors.dim)}
  </g>
  <g transform="translate(20 205)">
    ${actionRow(0, "+", "Ajouter une ville")}
    ${actionRow(54, "⌖", "Ma position")}
    ${divider(123)}
  </g>
  <g transform="translate(20 332)">
    ${settingRow(0, "UNITÉ", chip(242, -22, 48, "°C", true) + chip(294, -22, 48, "°F"))}
    ${settingRow(52, "FORMAT", chip(224, -22, 54, "12h", true) + chip(282, -22, 54, "24h"))}
    ${settingRow(104, "DONNÉES", `<text x="282" y="-3" style="${font};font-size:12px;font-weight:800" fill="${colors.accent}">Actualiser</text>`)}
    ${settingRow(156, "PLUIE", `<text x="199" y="-4" style="${font};font-size:11px;font-weight:500" fill="${colors.dim}">11 am · 55 %</text>${switcher(292, -24, true)}`)}
    ${settingRow(208, "SEUIL", chip(188, -22, 48, "40 %") + chip(240, -22, 48, "55 %", true) + chip(292, -22, 48, "70 %"))}
    ${settingRow(260, "PRÉAVIS", chip(172, -22, 58, "30 min") + chip(234, -22, 45, "1 h", true) + chip(283, -22, 45, "2 h"))}
    ${settingRow(312, "SYNC ICLOUD", switcher(292, -24, true))}
    ${settingRow(364, "VILLES", `<text x="279" y="-3" style="${font};font-size:12px;font-weight:800" fill="#B04132">Tout effacer</text>`)}
  </g>
`);

function actionRow(y, symbol, label) {
  return `<g transform="translate(0 ${y})">
    <circle cx="11" cy="-4" r="11" fill="${colors.accent}" opacity=".14"/>
    <text x="11" y="1" text-anchor="middle" style="${font};font-size:15px;font-weight:800" fill="${colors.accent}">${symbol}</text>
    ${text(32, 1, label, 15, 750)}
    <path d="M338 -12 L348 -4 L338 4" fill="none" stroke="${colors.faint}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>
  </g>`;
}

function settingRow(y, label, control) {
  return `<g transform="translate(0 ${y})">
    ${text(0, 0, label, 10, 800, colors.dim, "letter-spacing:2px")}
    ${control}
    <line x1="0" x2="350" y1="28" y2="28" stroke="${colors.line}"/>
  </g>`;
}

console.log(`Design mockups written to ${outDir}`);
