// node render.js <mode> <n> <out> [frames fps]   - screenshots draw(t) frames with Playwright/Chromium
const { chromium } = require("playwright");
const path = require("path");
(async () => {
	const [mode, n, out, frames, fps, start = "0"] = process.argv.slice(2);
	const size = { trailer: [1920, 1080], thumb: [1920, 1080], icon: [512, 512], sheet: [1920, 1080] }[mode];
	const browser = await chromium.launch();
	const page = await browser.newPage({ viewport: { width: size[0], height: size[1] } });
	await page.goto("file://" + path.join(__dirname, "page.html") + `?mode=${mode}&n=${n}`);
	await page.evaluate(() => document.fonts.ready);
	await page.evaluate(() => Promise.all([...document.fonts].map((f) => f.load())));
	if (frames) {
		for (let i = +start; i < +start + +frames; i++) {
			await page.evaluate((t) => window.draw(t), i / +fps);
			await page.screenshot({ path: `${out}/f${String(i).padStart(4, "0")}.png`, clip: { x: 0, y: 0, width: size[0], height: size[1] } });
		}
	} else {
		await page.evaluate((t) => window.draw(t), mode === "sheet" ? +n : 0);
		await page.screenshot({ path: out, clip: { x: 0, y: 0, width: size[0], height: size[1] } });
	}
	await browser.close();
})();
