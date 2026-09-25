// Grab a Goober - trailer cutscenes, thumbnails and icons (all drawn from art.js)
const SCENES = {};
const W = 1920, H = 1080;
const lerp = (a, b, k) => a + (b - a) * k;

// a candy-striped diagonal band that sweeps across the screen between cutscenes
function wipe(k) {
	if (k <= 0 || k >= 1) return "";
	const x = lerp(-1400, W + 400, k);
	let s = `<g transform="translate(${x} 0) skewX(-18)">`;
	const cols = ["#ff5fa8", "#ffd23f", "#6fe36b", "#4db8ff", "#b46bff"];
	for (let i = 0; i < cols.length; i++) s += `<rect x="${i * 200}" y="-50" width="200" height="${H + 100}" fill="${cols[i]}"/>`;
	return s + `<rect x="0" y="-50" width="1000" height="${H + 100}" fill="url(#vignette)" opacity=".3"/></g>`;
}
function shake(t, amt) {
	return `translate(${Math.sin(t * 91) * amt} ${Math.cos(t * 77) * amt})`;
}
function speedLines(t, x0, count = 10) {
	let s = "";
	for (let i = 0; i < count; i++) {
		const y = 180 + ((i * 97) % 700), len = 120 + (i % 4) * 60, x = x0 + ((t * 1800 + i * 211) % 700);
		s += `<rect x="${x}" y="${y}" width="${len}" height="8" rx="4" fill="#fff" opacity=".6"/>`;
	}
	return s;
}
function pill(x, y, w, h, fill, text, size) {
	return `<g filter="url(#drop)"><rect x="${x - w / 2}" y="${y - h / 2}" width="${w}" height="${h}" rx="${h / 2}" fill="${fill}" stroke="#1b0f33" stroke-width="10"/>
	<rect x="${x - w / 2 + 16}" y="${y - h / 2 + 10}" width="${w - 32}" height="${h * 0.3}" rx="${h * 0.15}" fill="#fff" opacity=".35"/></g>` + candyText(text, x, y + size * 0.36, size, "url(#white)");
}
function confetti(t, count = 40, seed = 1) {
	let s = "";
	const cols = ["#ff5fa8", "#ffd23f", "#6fe36b", "#4db8ff", "#b46bff", "#fff"];
	for (let i = 0; i < count; i++) {
		const x = (i * 173 * seed) % W, y = ((t * (200 + (i % 5) * 60) + i * 97) % (H + 100)) - 50;
		s += `<rect x="${x}" y="${y}" width="18" height="30" rx="4" fill="${cols[i % cols.length]}" transform="rotate(${t * 200 + i * 40} ${x + 9} ${y + 15})"/>`;
	}
	return s;
}

// ================= TRAILER (10 s) =================
const CUTS = [0, 2.2, 4.4, 6.8, 8.6, 10];
SCENES.trailer = function (t) {
	let b = "";
	if (t < CUTS[1]) b += s1(t);
	else if (t < CUTS[2]) b += s2(t - CUTS[1]);
	else if (t < CUTS[3]) b += s3(t - CUTS[2]);
	else if (t < CUTS[4]) b += s4(t - CUTS[3]);
	else b += s5(t - CUTS[4]);
	for (let i = 1; i < 5; i++) b += wipe((t - CUTS[i] + 0.22) / 0.44); // wipe centred on each cut
	b += `<rect width="${W}" height="${H}" fill="#fff" opacity="${Math.max(0, 1 - Math.abs(t - 0.62) * 8) * 0.8}"/>`; // flash on the title slam
	if (t < 0.12) b += `<rect width="${W}" height="${H}" fill="#000" opacity="${1 - t / 0.12}"/>`;
	if (t > 9.75) b += `<rect width="${W}" height="${H}" fill="#000" opacity="${(t - 9.75) / 0.25}"/>`;
	return [W, H, b];
};

// 1) title: goobers pop in, GRAB A GOOBER! slams down
function s1(t) {
	let b = sunburst(W, H, "#ff79c6", "#ff9ad6", t * 25);
	const pops = [
		{ x: 260, y: 780, r: 150, color: "#8ee04a", expr: "happy", at: 0.1 },
		{ x: 1660, y: 780, r: 150, color: "#ff5a4a", expr: "angry", at: 0.22 },
		{ x: 560, y: 900, r: 110, rainbow: true, expr: "shock", at: 0.34 },
		{ x: 1360, y: 900, r: 110, galaxy: true, expr: "cheeky", at: 0.46 },
	];
	for (const p of pops) {
		const k = easeOutBack((t - p.at) / 0.35);
		if (k > 0) b += `<g transform="translate(${p.x} ${p.y}) scale(${k}) translate(${-p.x} ${-p.y})">${goober({ ...p, y: p.y + Math.sin(t * 6 + p.x) * 10, squash: 1 + Math.sin(t * 12 + p.x) * 0.04 })}</g>`;
	}
	const land = (t - 0.35) / 0.3;
	if (land > 0) {
		const sc = land < 1 ? lerp(3.2, 1, easeIn(land)) : 1 + Math.max(0, 0.08 - (t - 0.65) * 0.3) * Math.sin((t - 0.65) * 40);
		b += `<g transform="${t > 0.65 && t < 1 ? shake(t, 18 * (1 - t)) : ""}">${candyText("GRAB A GOOBER!", 960, 420, 190, "url(#lime)", { scale: sc, font: "Luckiest" })}</g>`;
	}
	const sub = easeOutBack((t - 1.0) / 0.4);
	if (sub > 0) b += candyText("ESCAPE THE FLOOD!", 960, 600, 110, "url(#water)", { scale: sub, rot: -3 });
	for (let i = 0; i < 6; i++) b += sparkle(300 + i * 270, 180 + (i % 2) * 520, 22 + 10 * Math.sin(t * 8 + i), "#fff");
	return b;
}

// 2) the 0.01% Goober: rarities flash past, then the runner grabs it
function s2(u) {
	let b = sunburst(W, H, "#2b1a5c", "#3c2478", u * 15, 960, 520);
	b += `<circle cx="960" cy="520" r="${320 + Math.sin(u * 10) * 20}" fill="url(#rainbow)" opacity=".45" filter="url(#bigGlow)"/>`;
	const RAR = [["COMMON", "url(#white)"], ["RARE", "#4db8ff"], ["EPIC", "#b46bff"], ["LEGENDARY", "url(#gold)"], ["0.01% SECRET!!", "url(#rainbowText)"]];
	const idx = Math.min(RAR.length - 1, Math.floor(Math.max(0, u - 0.05) / 0.28));
	const r = RAR[idx];
	const pop = easeOutBack(((u - 0.05) % 0.28) / 0.15);
	b += candyText(r[0], 960, 150, idx === 4 ? 130 : 110, r[1], { scale: idx === 4 ? Math.max(pop, u > 1.4 ? 1 : 0) : pop, font: "Luckiest" });
	const grabbed = u > 1.45;
	const rx = grabbed ? lerp(960, 820, easeOut((u - 1.45) / 0.3)) : 960;
	const ry = grabbed ? lerp(560, 430, easeOut((u - 1.45) / 0.3)) : 560 + Math.sin(u * 5) * 16;
	if (!grabbed) {
		for (let i = 0; i < 5; i++) if (Math.sin(u * 40 + i * 3) > -0.2) b += bolt(960 + Math.cos(i * 1.3) * 230, 560 + Math.sin(i * 1.3) * 220, 150, i * 70 + u * 30);
	}
	b += goober({ x: rx, y: ry, r: grabbed ? 130 : 190, rainbow: true, expr: "shock", rot: Math.sin(u * 9) * 5 });
	if (u > 0.7) {
		const rk = easeOut((u - 0.7) / 0.7);
		b += runner({ x: lerp(-250, 820, rk), y: 800, s: 1.55, phase: u * 16 * (1 - (grabbed ? 1 : 0)), holding: grabbed });
	}
	if (u > 1.5) b += candyText("GRAB RARE GOOBERS!", 960, 1010, 110, "url(#gold)", { scale: easeOutBack((u - 1.5) / 0.3) });
	for (let i = 0; i < 8; i++) b += sparkle(960 + Math.cos(i + u * 3) * 380, 520 + Math.sin(i + u * 3) * 300, 16 + 8 * Math.sin(u * 10 + i), "#fff7a8");
	return b;
}

// 3) the flood: side-scrolling chase, the wave closes in
function s3(u) {
	const off = u * 1100;
	let b = sky(W, H, "#8fdcff", "#d7b8ff") + clouds(W, 150, -off * 0.3) + ground(W, H, 860, -off);
	const waveX = lerp(W + 150, 1150, easeOut(u / 2.2));
	const inner = runner({ x: 700, y: 700, s: 1.45, phase: u * 16, holding: true }) +
		goober({ x: 700, y: 360 + Math.abs(Math.sin(u * 16)) * -14, r: 105, rainbow: true, expr: "shock", rot: Math.sin(u * 16) * 6, shadow: false });
	b += speedLines(u, 820);
	b += `<g transform="${shake(u, 8)}">${inner}${wave({ x: waveX, base: 870, h: 620, w: 1600, t: u })}</g>`;
	b += candyText("ESCAPE THE FLOOD!", 700, 170, 150, "url(#water)", { scale: easeOutBack(u / 0.35), rot: -3, font: "Luckiest" });
	if (u > 1.2) b += candyText("RUN!!", 360, 520, 130, "url(#redT)", { scale: 1 + Math.sin(u * 20) * 0.06, rot: -10 });
	return b;
}

// 4) the boss: a giant angry Goober hunts you down
function s4(u) {
	const off = u * 1200;
	let b = sky(W, H, "#ff9b8a", "#7b2bd6") + clouds(W, 140, -off * 0.3) + ground(W, H, 860, -off, "#b55a45", "#7a3326");
	const hop = Math.abs(Math.sin(u * 7));
	b += speedLines(u, 900, 8);
	b += runner({ x: 560, y: 700, s: 1.45, phase: u * 18, holding: true });
	b += goober({ x: 560, y: 360 - Math.abs(Math.sin(u * 18)) * 14, r: 100, color: "#8ee04a", expr: "shock", shadow: false, rot: Math.sin(u * 18) * 6 });
	b += goober({ x: 1350 - easeOut(u / 1.8) * 120, y: 580 - hop * 90, r: 280, color: "#ff4a3d", expr: "angry", squash: 1 - (1 - hop) * 0.12, look: -1, rot: -6 });
	b += `<g transform="translate(1560 ${300 - hop * 60})">${candyText("!", 0, 0, 170, "url(#gold)", { font: "Luckiest" })}</g>`;
	b += `<rect width="${W}" height="${H}" fill="url(#redVignette)" opacity="${0.5 + 0.5 * Math.sin(u * 14)}"/>`;
	b += `<g transform="${shake(u, 6)}">${candyText("OUTRUN THE BOSS!", 600, 170, 112, "url(#redT)", { scale: easeOutBack(u / 0.35), rot: -3, font: "Luckiest" })}</g>`;
	return b;
}

// 5) end card: logo, PLAY NOW, the whole gang bouncing
function s5(u) {
	let b = sunburst(W, H, "#5fd96b", "#8cf07a", u * 30);
	b += confetti(u, 50);
	const gang = [
		{ x: 330, color: "#8ee04a", expr: "happy" }, { x: 690, color: "#ff5a4a", expr: "angry" },
		{ x: 1230, rainbow: true, expr: "shock" }, { x: 1590, galaxy: true, expr: "cheeky" },
	];
	gang.forEach((g, i) => {
		const hop = Math.abs(Math.sin(u * 6 + i));
		b += goober({ ...g, y: 935 - hop * 50, r: 115, squash: 1 - (1 - hop) * 0.08 });
	});
	b += candyText("GRAB A GOOBER!", 960, 360, 200, "url(#lime)", { scale: easeOutBack(u / 0.4), font: "Luckiest" });
	b += candyText("ESCAPE THE FLOOD!", 960, 510, 90, "url(#water)", { scale: easeOutBack((u - 0.15) / 0.4), rot: -2 });
	const btn = easeOutBack((u - 0.3) / 0.4) * (1 + Math.sin(u * 9) * 0.04);
	if (btn > 0) b += `<g transform="translate(960 670) scale(${btn}) translate(-960 -670)">${pill(960, 670, 560, 140, "#2f8cff", "PLAY NOW!", 90)}</g>`;
	b += `<g transform="rotate(12 1730 120)">${candyText("0.01%", 1730, 150, 95, "url(#rainbowText)", { scale: 1 + Math.sin(u * 8) * 0.06 })}</g>`;
	return b;
}

// ================= THUMBNAILS (1920x1080) =================
SCENES.thumb = function (_, n) {
	let b = "";
	if (n === 1) { // THE 0.01% GOOBER
		b += sunburst(W, H, "#2b1a5c", "#3f2690", 0, 1180, 520);
		b += `<circle cx="1180" cy="520" r="360" fill="url(#rainbow)" opacity=".5" filter="url(#bigGlow)"/>`;
		for (let i = 0; i < 6; i++) b += bolt(1180 + Math.cos(i * 1.1) * 300, 520 + Math.sin(i * 1.1) * 280, 170, i * 60 + 10);
		b += goober({ x: 1180, y: 640, r: 230, rainbow: true, expr: "shock", rot: -6 });
		b += runner({ x: 460, y: 700, s: 1.9, phase: 0.9, face: "grit" });
		b += candyText("GRAB THE", 960, 140, 120, "url(#white)", { font: "Luckiest", rot: -2 });
		b += candyText("0.01% GOOBER!", 960, 290, 160, "url(#rainbowText)", { font: "Luckiest", rot: -2 });
		for (let i = 0; i < 10; i++) b += sparkle(900 + Math.cos(i * 0.9) * 560, 560 + Math.sin(i * 0.9) * 420, 24, "#fff7a8");
	} else if (n === 2) { // ESCAPE THE FLOOD
		b += sky(W, H, "#8fdcff", "#d7b8ff") + clouds(W, 140, 0) + ground(W, H, 880, 0);
		b += runner({ x: 640, y: 790, s: 1.4, phase: 0.8, holding: true });
		b += goober({ x: 640, y: 470, r: 100, color: "#8ee04a", expr: "shock", shadow: false });
		b += speedLines(0.2, 760, 8);
		b += wave({ x: 1050, base: 890, h: 640, w: 1400, t: 0.4 });
		b += candyText("ESCAPE THE", 520, 130, 115, "url(#white)", { font: "Luckiest", rot: -3 });
		b += candyText("FLOOD!", 520, 280, 175, "url(#water)", { font: "Luckiest", rot: -3 });
		b += `<rect width="${W}" height="${H}" fill="url(#vignette)" opacity=".6"/>`;
	} else if (n === 3) { // OUTRUN THE BOSS
		b += sky(W, H, "#ff9b8a", "#6b22c8") + ground(W, H, 880, 0, "#b55a45", "#7a3326");
		b += goober({ x: 1330, y: 540, r: 360, color: "#ff4a3d", expr: "angry", look: -1, rot: -6 });
		b += runner({ x: 500, y: 800, s: 1.4, phase: 1.1, holding: true });
		b += goober({ x: 500, y: 480, r: 95, color: "#8ee04a", expr: "shock", shadow: false });
		b += candyText("!", 1700, 250, 190, "url(#gold)", { font: "Luckiest", rot: 12 });
		b += `<rect width="${W}" height="${H}" fill="url(#redVignette)"/>`;
		b += candyText("OUTRUN THE", 500, 125, 110, "url(#white)", { font: "Luckiest", rot: -3 });
		b += candyText("BOSS!", 500, 270, 170, "url(#redT)", { font: "Luckiest", rot: -3 });
	} else { // NEW MUTATIONS update
		b += sunburst(W, H, "#3a1d7a", "#5a2ea8", 5);
		b += goober({ x: 520, y: 640, r: 210, galaxy: true, expr: "cheeky", rot: -8 });
		b += goober({ x: 960, y: 700, r: 230, color: "#7a4424", expr: "happy" });
		b += goober({ x: 1400, y: 640, r: 210, color: "#9dff3c", expr: "shock", rot: 8 });
		for (let i = 0; i < 12; i++) b += sparkle(520 + Math.cos(i) * 280, 640 + Math.sin(i) * 250, 14 + (i % 3) * 6, "#fff");
		b += candyText("GALAXY", 520, 960, 90, "url(#rainbowText)", { font: "Luckiest" });
		b += candyText("CHOCOLATE", 960, 1030, 90, "url(#gold)", { font: "Luckiest" });
		b += candyText("TOXIC", 1400, 960, 90, "url(#lime)", { font: "Luckiest" });
		b += candyText("NEW MUTATIONS!", 900, 250, 150, "url(#hot)", { font: "Luckiest", rot: -2 });
		b += `<g transform="rotate(14 1730 100)">${pill(1730, 100, 280, 100, "#ff3b5c", "NEW!", 66)}</g>`;
	}
	return [W, H, b];
};

// ================= ICONS (512x512) =================
SCENES.icon = function (_, n) {
	const S = 512;
	let b = "";
	if (n === 1) { // the classic: runner lifting a Goober, angry Goober behind
		b += sky(S, S, "#8fdcff", "#ffd6a0") + `<rect y="380" width="${S}" height="132" fill="#f7d58a"/><rect y="380" width="${S}" height="10" fill="#e0b060"/>`;
		b += goober({ x: 365, y: 255, r: 125, color: "#ff4a3d", expr: "angry", look: -1 });
		b += runner({ x: 165, y: 355, s: 0.8, phase: 0.8, holding: true });
		b += goober({ x: 165, y: 185, r: 64, color: "#8ee04a", expr: "happy", shadow: false });
	} else if (n === 2) { // the 0.01% Goober
		b += sunburst(S, S, "#2b1a5c", "#4a2c9a", 0);
		b += `<circle cx="256" cy="270" r="190" fill="url(#rainbow)" opacity=".5" filter="url(#bigGlow)"/>`;
		for (let i = 0; i < 5; i++) b += bolt(256 + Math.cos(i * 1.3) * 170, 280 + Math.sin(i * 1.3) * 160, 90, i * 72, "#7dff5a", 8);
		b += goober({ x: 256, y: 265, r: 135, rainbow: true, expr: "shock" });
		b += `<g transform="rotate(-8 256 455)">${candyText("0.01%", 256, 470, 86, "url(#rainbowText)", { font: "Luckiest" })}</g>`;
	} else { // a Goober fleeing the wave
		b += sky(S, S, "#8fdcff", "#d7b8ff") + `<rect y="430" width="${S}" height="82" fill="#6fd36b"/>`;
		b += wave({ x: 260, base: 440, h: 330, w: 400, t: 0.5 });
		b += goober({ x: 150, y: 330, r: 115, color: "#8ee04a", expr: "shock", look: -1, rot: -10 });
		b += speedLines(0.1, 260, 3);
	}
	return [S, S, b];
};

SCENES.sheet = function (t) {
	return SCENES.trailer(t);
};
