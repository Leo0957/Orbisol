import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("/Users/leo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright");

const outDir = resolve("DesignMockups/png");
mkdirSync(outDir, { recursive: true });

const files = [
  ["DesignMockups/01-horloges.svg", "01-horloges.png"],
  ["DesignMockups/02-meteo.svg", "02-meteo.png"],
  ["DesignMockups/03-grand-format.svg", "03-grand-format.png"],
  ["DesignMockups/04-reglages.svg", "04-reglages.png"],
];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
});

for (const [input, output] of files) {
  const url = pathToFileURL(resolve(input)).href;
  await page.goto(url);
  await page.screenshot({ path: resolve(outDir, output), omitBackground: true });
}

await browser.close();
console.log(`PNG previews written to ${outDir}`);
