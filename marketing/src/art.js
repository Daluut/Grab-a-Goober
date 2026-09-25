// Grab a Goober - shared vector art kit (trailer, thumbnails, icons).
// Every function returns an SVG string. Coordinates are in the 1920x1080 (or 512x512) stage.
const INK = "#1b0f33";

function defs() {
	return `<defs>
	<linearGradient id="rainbow" x1="0" y1="0" x2="1" y2="1">
		<stop offset="0" stop-color="#ff4d6d"/><stop offset=".2" stop-color="#ffa24d"/><stop offset=".4" stop-color="#ffe34d"/>
		<stop offset=".6" stop-color="#4dea7a"/><stop offset=".8" stop-color="#4dafff"/><stop offset="1" stop-color="#b56bff"/>
	</linearGradient>
	<linearGradient id="rainbowText" x1="0" y1="0" x2="1" y2="0">
		<stop offset="0" stop-color="#ff5a7a"/><stop offset=".25" stop-color="#ffb347"/><stop offset=".5" stop-color="#fff35c"/>
		<stop offset=".75" stop-color="#5cf08a"/><stop offset="1" stop-color="#5cc2ff"/>
	</linearGradient>
	<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6a8"/><stop offset=".55" stop-color="#ffd23f"/><stop offset="1" stop-color="#ff9f1c"/></linearGradient>
	<linearGradient id="lime" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e9ff8a"/><stop offset=".55" stop-color="#8cf23c"/><stop offset="1" stop-color="#3fbf2a"/></linearGradient>
	<linearGradient id="white" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#dfe6ff"/></linearGradient>
	<linearGradient id="hot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe0f0"/><stop offset=".5" stop-color="#ff6fb5"/><stop offset="1" stop-color="#e0308a"/></linearGradient>
	<linearGradient id="redT" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd0c4"/><stop offset=".5" stop-color="#ff5a4a"/><stop offset="1" stop-color="#c81e2e"/></linearGradient>
	<linearGradient id="water" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7ff0ff"/><stop offset=".45" stop-color="#2fa8ff"/><stop offset="1" stop-color="#1450c8"/></linearGradient>
	<linearGradient id="waterFace" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#bff8ff"/><stop offset="1" stop-color="#46c3ff"/></linearGradient>
	<linearGradient id="galaxy" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2a0f6b"/><stop offset=".5" stop-color="#7b3dff"/><stop offset="1" stop-color="#ff7ae0"/></linearGradient>
	<radialGradient id="shine" cx=".35" cy=".3" r=".7"><stop offset="0" stop-color="#fff" stop-opacity=".75"/><stop offset=".45" stop-color="#fff" stop-opacity=".12"/><stop offset="1" stop-color="#000" stop-opacity=".18"/></radialGradient>
	<radialGradient id="vignette" cx=".5" cy=".5" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient>
	<radialGradient id="redVignette" cx=".5" cy=".5" r=".75"><stop offset=".45" stop-color="#ff0030" stop-opacity="0"/><stop offset="1" stop-color="#ff0030" stop-opacity=".6"/></radialGradient>
	<pattern id="scales" width="36" height="30" patternUnits="userSpaceOnUse">
		<path d="M0 30 A18 18 0 0 1 36 30 M-18 15 A18 18 0 0 1 18 15 M18 15 A18 18 0 0 1 54 15" fill="none" stroke="#fff" stroke-width="3" stroke-opacity=".55"/>
	</pattern>
	<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
	<filter id="bigGlow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="28"/></filter>
	<filter id="drop" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="14" stdDeviation="6" flood-color="#150630" flood-opacity=".6"/></filter>
	</defs>`;
}

// ---------- backgrounds ----------
function sunburst(w, h, c1, c2, rot = 0, cx = w / 2, cy = h / 2) {
	const rays = 24;
	let s = `<rect width="${w}" height="${h}" fill="${c1}"/>`;
	const R = Math.hypot(w, h);
	for (let i = 0; i < rays; i += 2) {
		const a0 = ((i / rays) * 360 + rot) * Math.PI / 180, a1 = (((i + 1) / rays) * 360 + rot) * Math.PI / 180;
		s += `<path d="M${cx} ${cy} L${cx + Math.cos(a0) * R} ${cy + Math.sin(a0) * R} L${cx + Math.cos(a1) * R} ${cy + Math.sin(a1) * R}Z" fill="${c2}"/>`;
	}
	return s + `<rect width="${w}" height="${h}" fill="url(#vignette)"/>`;
}
function sky(w, h, top = "#7fd3ff", bottom = "#c9a2ff") {
	return `<linearGradient id="skyG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset="1" stop-color="${bottom}"/></linearGradient><rect width="${w}" height="${h}" fill="url(#skyG)"/>`;
}
function clouds(w, y, offset = 0) {
	let s = "";
	for (let i = 0; i < 6; i++) {
		const x = ((i * 380 + offset) % (w + 400)) - 200, yy = y + (i % 3) * 60;
		s += `<g opacity=".85" fill="#fff"><ellipse cx="${x}" cy="${yy}" rx="110" ry="40"/><ellipse cx="${x + 60}" cy="${yy - 25}" rx="70" ry="45"/><ellipse cx="${x - 55}" cy="${yy - 10}" rx="60" ry="35"/></g>`;
	}
	return s;
}
// the grassy runway seen from the side, scrolling by "offset"
function ground(w, h, y, offset = 0, color = "#6fd36b", dark = "#3f9e45") {
	let s = `<rect x="0" y="${y}" width="${w}" height="${h - y}" fill="${color}"/><rect x="0" y="${y}" width="${w}" height="14" fill="${dark}" opacity=".6"/>`;
	for (let i = -1; i < w / 160 + 2; i++) {
		const x = i * 160 - (offset % 160);
		s += `<rect x="${x}" y="${y + 40}" width="80" height="18" rx="9" fill="${dark}" opacity=".35"/>`;
	}
	return s;
}

// ---------- characters ----------
// A Goober: round body, big shiny eyes, blush, a sprout on top. expr: happy | shock | angry | cheeky
function goober({ x, y, r, color = "#8ee04a", expr = "happy", sprout = true, rainbow = false, galaxy = false, look = 0, rot = 0, squash = 1, leaf2 = "#ff7eb8", shadow = true }) {
	const sw = Math.max(3, r * 0.075);
	const fill = rainbow ? "url(#rainbow)" : galaxy ? "url(#galaxy)" : color;
	let s = `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${1 / Math.sqrt(squash)} ${squash})">`;
	if (shadow) s += `<ellipse cx="0" cy="${r * 1.02}" rx="${r * 0.8}" ry="${r * 0.14}" fill="#000" opacity=".22"/>`;
	// feet
	s += `<ellipse cx="${-r * 0.38}" cy="${r * 0.9}" rx="${r * 0.26}" ry="${r * 0.15}" fill="${shade(color, -0.35)}" stroke="${INK}" stroke-width="${sw}"/>`;
	s += `<ellipse cx="${r * 0.38}" cy="${r * 0.9}" rx="${r * 0.26}" ry="${r * 0.15}" fill="${shade(color, -0.35)}" stroke="${INK}" stroke-width="${sw}"/>`;
	if (sprout) {
		s += `<path d="M0 ${-r * 0.95} C ${r * 0.05} ${-r * 1.15}, ${-r * 0.05} ${-r * 1.25}, ${r * 0.02} ${-r * 1.35}" stroke="${INK}" stroke-width="${sw * 1.8}" fill="none" stroke-linecap="round"/>`;
		s += `<path d="M0 ${-r * 0.95} C ${r * 0.05} ${-r * 1.15}, ${-r * 0.05} ${-r * 1.25}, ${r * 0.02} ${-r * 1.35}" stroke="#4caf3a" stroke-width="${sw * 0.9}" fill="none" stroke-linecap="round"/>`;
		s += `<path d="M${r * 0.02} ${-r * 1.3} C ${r * 0.3} ${-r * 1.6}, ${r * 0.65} ${-r * 1.45}, ${r * 0.62} ${-r * 1.28} C ${r * 0.45} ${-r * 1.12}, ${r * 0.15} ${-r * 1.15}, ${r * 0.02} ${-r * 1.3}Z" fill="#6fd64a" stroke="${INK}" stroke-width="${sw}"/>`;
		s += `<path d="M${r * 0.02} ${-r * 1.3} C ${-r * 0.25} ${-r * 1.58}, ${-r * 0.58} ${-r * 1.42}, ${-r * 0.55} ${-r * 1.25} C ${-r * 0.4} ${-r * 1.1}, ${-r * 0.12} ${-r * 1.15}, ${r * 0.02} ${-r * 1.3}Z" fill="${rainbow ? leaf2 : "#8ee85a"}" stroke="${INK}" stroke-width="${sw}"/>`;
	}
	// body
	s += `<circle r="${r}" fill="${fill}" stroke="${INK}" stroke-width="${sw}"/>`;
	if (rainbow) s += `<circle r="${r - sw / 2}" fill="url(#scales)"/>`;
	if (galaxy) for (let i = 0; i < 9; i++) s += `<circle cx="${Math.cos(i * 2.4) * r * 0.7 * ((i % 3) / 3 + 0.3)}" cy="${Math.sin(i * 2.4) * r * 0.6 * ((i % 3) / 3 + 0.4)}" r="${r * 0.03}" fill="#fff"/>`;
	s += `<circle r="${r - sw / 2}" fill="url(#shine)"/>`;
	s += `<ellipse cx="${-r * 0.4}" cy="${-r * 0.5}" rx="${r * 0.22}" ry="${r * 0.12}" transform="rotate(-30 ${-r * 0.4} ${-r * 0.5})" fill="#fff" opacity=".7"/>`;
	// blush
	s += `<ellipse cx="${-r * 0.55}" cy="${r * 0.22}" rx="${r * 0.14}" ry="${r * 0.08}" fill="#ff6f9c" opacity=".65"/>`;
	s += `<ellipse cx="${r * 0.55}" cy="${r * 0.22}" rx="${r * 0.14}" ry="${r * 0.08}" fill="#ff6f9c" opacity=".65"/>`;
	// eyes
	const ey = -r * 0.1, ex = r * 0.3, erx = r * 0.2, ery = expr === "shock" ? r * 0.27 : r * 0.24;
	const pr = expr === "shock" ? r * 0.08 : expr === "angry" ? r * 0.1 : r * 0.12;
	for (const sx of [-1, 1]) {
		s += `<ellipse cx="${sx * ex}" cy="${ey}" rx="${erx}" ry="${ery}" fill="#fff" stroke="${INK}" stroke-width="${sw * 0.8}"/>`;
		s += `<circle cx="${sx * ex + look * r * 0.07}" cy="${ey + (expr === "angry" ? r * 0.05 : r * 0.02)}" r="${pr}" fill="${INK}"/>`;
		s += `<circle cx="${sx * ex + look * r * 0.07 - pr * 0.35}" cy="${ey - pr * 0.4}" r="${pr * 0.4}" fill="#fff"/>`;
		if (expr === "angry") s += `<path d="M${sx * (ex + erx * 1.1)} ${ey - ery * 1.25} L${sx * (ex - erx * 0.9)} ${ey - ery * 0.55}" stroke="${INK}" stroke-width="${sw * 2.2}" stroke-linecap="round"/>`;
		if (expr === "shock") s += `<path d="M${sx * (ex + erx)} ${ey - ery * 1.5} Q${sx * ex} ${ey - ery * 2} ${sx * (ex - erx)} ${ey - ery * 1.45}" stroke="${INK}" stroke-width="${sw * 1.2}" fill="none" stroke-linecap="round"/>`;
	}
	// mouth
	const my = r * 0.38;
	if (expr === "happy") s += `<path d="M${-r * 0.22} ${my - r * 0.04} Q0 ${my + r * 0.28} ${r * 0.22} ${my - r * 0.04} Z" fill="#6a1b3a" stroke="${INK}" stroke-width="${sw * 0.8}" stroke-linejoin="round"/><ellipse cx="0" cy="${my + r * 0.1}" rx="${r * 0.09}" ry="${r * 0.05}" fill="#ff7b9c"/>`;
	if (expr === "cheeky") s += `<path d="M${-r * 0.2} ${my} Q0 ${my + r * 0.16} ${r * 0.2} ${my}" stroke="${INK}" stroke-width="${sw}" fill="none" stroke-linecap="round"/><ellipse cx="${r * 0.08}" cy="${my + r * 0.12}" rx="${r * 0.07}" ry="${r * 0.09}" fill="#ff7b9c" stroke="${INK}" stroke-width="${sw * 0.6}"/>`;
	if (expr === "shock") s += `<ellipse cx="0" cy="${my + r * 0.05}" rx="${r * 0.13}" ry="${r * 0.17}" fill="#5a1530" stroke="${INK}" stroke-width="${sw * 0.8}"/>`;
	if (expr === "angry") {
		s += `<rect x="${-r * 0.3}" y="${my - r * 0.06}" width="${r * 0.6}" height="${r * 0.2}" rx="${r * 0.06}" fill="#fff" stroke="${INK}" stroke-width="${sw * 0.8}"/>`;
		for (let i = 1; i < 4; i++) s += `<line x1="${-r * 0.3 + i * r * 0.15}" y1="${my - r * 0.06}" x2="${-r * 0.3 + i * r * 0.15}" y2="${my + r * 0.14}" stroke="${INK}" stroke-width="${sw * 0.5}"/>`;
	}
	return s + `</g>`;
}

// A blocky Roblox-style runner. phase = run cycle (radians). holding = arms up over the head.
function runner({ x, y, s = 1, phase = 0, holding = false, flip = false, face = "grit" }) {
	const sw = 6;
	const leg = Math.sin(phase) * 32, arm = Math.sin(phase + Math.PI) * 38;
	const skin = "#f3e1cf", jacket = "#23222c", pants = "#2f6b3a", shirt = "#3f7fe0";
	let g = `<g transform="translate(${x} ${y}) scale(${flip ? -s : s} ${s})">`;
	g += `<ellipse cx="0" cy="150" rx="70" ry="12" fill="#000" opacity=".2"/>`;
	// legs
	g += `<g transform="rotate(${leg} -16 40)"><rect x="-34" y="40" width="34" height="96" rx="8" fill="${pants}" stroke="${INK}" stroke-width="${sw}"/><rect x="-38" y="124" width="42" height="22" rx="8" fill="#1a1a22" stroke="${INK}" stroke-width="${sw}"/></g>`;
	g += `<g transform="rotate(${-leg} 16 40)"><rect x="0" y="40" width="34" height="96" rx="8" fill="${pants}" stroke="${INK}" stroke-width="${sw}"/><rect x="-4" y="124" width="42" height="22" rx="8" fill="#1a1a22" stroke="${INK}" stroke-width="${sw}"/></g>`;
	// back arm
	g += holding ? `<g transform="rotate(168 -49 -46)"><rect x="-64" y="-52" width="30" height="92" rx="10" fill="${jacket}" stroke="${INK}" stroke-width="${sw}"/><rect x="-64" y="28" width="30" height="24" rx="8" fill="${skin}" stroke="${INK}" stroke-width="${sw}"/></g>`
		: `<g transform="rotate(${-arm} -40 -48)"><rect x="-64" y="-52" width="30" height="92" rx="10" fill="${jacket}" stroke="${INK}" stroke-width="${sw}"/><rect x="-64" y="28" width="30" height="24" rx="8" fill="${skin}" stroke="${INK}" stroke-width="${sw}"/></g>`;
	// torso
	g += `<rect x="-40" y="-56" width="80" height="102" rx="12" fill="${jacket}" stroke="${INK}" stroke-width="${sw}"/><rect x="-16" y="-54" width="32" height="96" fill="${shirt}"/><path d="M-16 -54 L0 -30 L16 -54" fill="${skin}" stroke="${INK}" stroke-width="3"/>`;
	// head
	g += `<g transform="translate(0 -104) rotate(${Math.sin(phase * 2) * 3})">`;
	g += `<rect x="-44" y="-46" width="88" height="88" rx="22" fill="${skin}" stroke="${INK}" stroke-width="${sw}"/>`;
	g += `<path d="M-50 -20 C-56 -62, 30 -78, 52 -34 L52 -14 C40 -30, 20 -34, 6 -26 C-10 -38, -30 -34, -50 -8Z" fill="#8a4b22" stroke="${INK}" stroke-width="${sw}" stroke-linejoin="round"/>`;
	if (face === "grit") {
		g += `<path d="M-30 -6 L-8 2 M30 -6 L8 2" stroke="${INK}" stroke-width="7" stroke-linecap="round"/><circle cx="-18" cy="10" r="6" fill="${INK}"/><circle cx="18" cy="10" r="6" fill="${INK}"/>`;
		g += `<rect x="-20" y="22" width="40" height="14" rx="4" fill="#fff" stroke="${INK}" stroke-width="4"/><line x1="-7" y1="22" x2="-7" y2="36" stroke="${INK}" stroke-width="3"/><line x1="7" y1="22" x2="7" y2="36" stroke="${INK}" stroke-width="3"/>`;
	} else {
		g += `<circle cx="-18" cy="6" r="7" fill="${INK}"/><circle cx="18" cy="6" r="7" fill="${INK}"/><path d="M-16 24 Q0 36 16 24" stroke="${INK}" stroke-width="5" fill="none" stroke-linecap="round"/>`;
	}
	g += `</g>`;
	// front arm
	g += holding ? `<g transform="rotate(-168 49 -46)"><rect x="34" y="-52" width="30" height="92" rx="10" fill="${jacket}" stroke="${INK}" stroke-width="${sw}"/><rect x="34" y="28" width="30" height="24" rx="8" fill="${skin}" stroke="${INK}" stroke-width="${sw}"/></g>`
		: `<g transform="rotate(${arm} 40 -48)"><rect x="34" y="-52" width="30" height="92" rx="10" fill="${jacket}" stroke="${INK}" stroke-width="${sw}"/><rect x="34" y="28" width="30" height="24" rx="8" fill="${skin}" stroke="${INK}" stroke-width="${sw}"/></g>`;
	return g + `</g>`;
}

// A big curling flood wave. x = front edge, travelling LEFT. h = height.
function wave({ x, base, h, w = 1400, t = 0, rainbow = false }) {
	const lip = h * 0.35;
	const body = `M${x + w} ${base} L${x + 30} ${base} C ${x - 20} ${base - h * 0.35}, ${x + 10} ${base - h * 0.8}, ${x + h * 0.35} ${base - h}
		C ${x + h * 0.55} ${base - h * 1.08}, ${x + h * 0.2} ${base - h * 1.2}, ${x - lip * 0.3} ${base - h * 0.92}
		C ${x - lip * 0.55} ${base - h * 0.8}, ${x - lip * 0.2} ${base - h * 0.68}, ${x + lip * 0.1} ${base - h * 0.74}
		C ${x + h * 0.6} ${base - h * 0.95}, ${x + h * 1.2} ${base - h * 0.75}, ${x + w} ${base - h * 0.6} Z`;
	let s = `<path d="${body}" fill="${rainbow ? "url(#rainbow)" : "url(#water)"}" stroke="${INK}" stroke-width="8" stroke-linejoin="round"/>`;
	// the dark hollow under the curling lip
	s += `<path d="M${x - lip * 0.2} ${base - h * 0.88} C ${x + h * 0.05} ${base - h * 0.78}, ${x + h * 0.22} ${base - h * 0.8}, ${x + h * 0.36} ${base - h * 0.92} C ${x + h * 0.3} ${base - h * 0.7}, ${x + h * 0.12} ${base - h * 0.66}, ${x - lip * 0.2} ${base - h * 0.88}Z" fill="#0d3a8f" opacity=".55"/>`;
	// lighter face + foam curl
	s += `<path d="M${x + 30} ${base} C ${x - 10} ${base - h * 0.35}, ${x + 15} ${base - h * 0.72}, ${x + h * 0.3} ${base - h * 0.9} L${x + h * 0.42} ${base - h * 0.6} C ${x + h * 0.2} ${base - h * 0.4}, ${x + h * 0.18} ${base - h * 0.2}, ${x + h * 0.3} ${base}Z" fill="url(#waterFace)" opacity=".55"/>`;
	for (let i = 0; i < 14; i++) {
		const a = i / 13;
		const fx = x - lip * 0.25 + a * h * 0.9 + Math.sin(t * 9 + i) * 6, fy = base - h * 0.93 - Math.sin(a * Math.PI) * h * 0.13 + Math.cos(t * 7 + i * 2) * 5;
		s += `<circle cx="${fx}" cy="${fy}" r="${h * (0.05 + 0.03 * ((i * 7) % 3))}" fill="#fff" stroke="${INK}" stroke-width="4"/>`;
	}
	// spray droplets
	for (let i = 0; i < 18; i++) {
		const k = (t * 1.7 + i * 0.37) % 1;
		const sx = x - 40 - k * 160 - (i % 4) * 30, sy = base - h * 0.95 + (k * k) * h * 0.9 - (i % 3) * 30;
		s += `<circle cx="${sx}" cy="${sy}" r="${10 - k * 6}" fill="#e8fbff" opacity="${1 - k}"/>`;
	}
	// ground foam
	for (let i = 0; i < 8; i++) s += `<ellipse cx="${x + 20 + i * 60 + Math.sin(t * 8 + i) * 8}" cy="${base - 6}" rx="44" ry="16" fill="#fff" opacity=".9"/>`;
	return s;
}

function bolt(x, y, len, rot, color = "#7dff5a", width = 10) {
	const pts = [[0, 0], [len * 0.28, -len * 0.08], [len * 0.36, len * 0.12], [len * 0.7, 0], [len * 0.62, len * 0.18], [len, len * 0.1]];
	const d = "M" + pts.map((p) => p.join(" ")).join(" L");
	return `<g transform="translate(${x} ${y}) rotate(${rot})" filter="url(#glow)"><path d="${d}" stroke="${color}" stroke-width="${width}" fill="none" stroke-linejoin="round" stroke-linecap="round"/><path d="${d}" stroke="#fff" stroke-width="${width * 0.35}" fill="none" stroke-linejoin="round" stroke-linecap="round"/></g>`;
}

function sparkle(x, y, r, color = "#fff") {
	return `<path transform="translate(${x} ${y})" d="M0 ${-r} Q${r * 0.15} ${-r * 0.15} ${r} 0 Q${r * 0.15} ${r * 0.15} 0 ${r} Q${-r * 0.15} ${r * 0.15} ${-r} 0 Q${-r * 0.15} ${-r * 0.15} 0 ${-r}Z" fill="${color}"/>`;
}

// Chunky outlined candy text: dark outline + drop shadow + gradient fill
function candyText(text, x, y, size, fill = "url(#lime)", { anchor = "middle", rot = 0, font = "Lilita", outline = INK, scale = 1, letter = 0 } = {}) {
	const fam = font === "Luckiest" ? "'Luckiest Guy'" : font === "Fredoka" ? "'Fredoka'" : "'Lilita One'";
	const common = `x="0" y="0" font-family="${fam}" font-size="${size}" text-anchor="${anchor}" letter-spacing="${letter}"`;
	return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${scale})">
		<text ${common} transform="translate(0 ${size * 0.08})" fill="${outline}" stroke="${outline}" stroke-width="${size * 0.2}" stroke-linejoin="round" opacity=".55">${text}</text>
		<text ${common} fill="${outline}" stroke="${outline}" stroke-width="${size * 0.2}" stroke-linejoin="round">${text}</text>
		<text ${common} fill="#fff" stroke="#fff" stroke-width="${size * 0.06}" stroke-linejoin="round">${text}</text>
		<text ${common} fill="${fill}">${text}</text>
	</g>`;
}

function shade(hex, amt) {
	if (!hex || hex[0] !== "#") return "#335";
	const n = parseInt(hex.slice(1), 16);
	let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
	const f = (c) => Math.max(0, Math.min(255, Math.round(amt < 0 ? c * (1 + amt) : c + (255 - c) * amt)));
	return "#" + ((1 << 24) + (f(r) << 16) + (f(g) << 8) + f(b)).toString(16).slice(1);
}

// easing helpers
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const easeOutBack = (v) => { const c1 = 1.70158, c3 = c1 + 1; v = clamp01(v); return 1 + c3 * Math.pow(v - 1, 3) + c1 * Math.pow(v - 1, 2); };
const easeOut = (v) => 1 - Math.pow(1 - clamp01(v), 3);
const easeIn = (v) => Math.pow(clamp01(v), 3);
