// The film's places, each a stack of lit paper sheets. No human figure appears anywhere.
import { mulberry, clamp, lerp, seg, ss, eio, eo, back } from '/core/lib.js';
import { W, H, cv, sheet, put, camAt, glow, poly, ridge, cutWith } from './paper.js';
import { LIGHTNING, FLIPS, SPLASH, JAW_OPEN, JAW_CLOSE, LAMP_OFF } from './data.js';

export const EV = [];
const ev = (t, type, o = {}) => EV.push({ t: +t.toFixed(3), type, ...o });
const flick = (t, i = 0) => 1 + .06 * Math.sin(7.3 * t + i) * Math.sin(3.1 * t + i * .7);
const drift = t => ({ x: Math.sin(t * .7) * 1.6 + Math.sin(t * 1.9) * .7, y: Math.cos(t * .6) * 1.2 });
function birdShape(ctx, x, y, s, f, col) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); ctx.fillStyle = col;
  ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(-18, -14 - f * 18, -38, -4 - f * 26); ctx.quadraticCurveTo(-18, -4, 0, 6); ctx.quadraticCurveTo(18, -4, 38, -4 - f * 26); ctx.quadraticCurveTo(18, -14 - f * 18, 0, 0); ctx.fill(); ctx.restore(); }

// ---------------------------------------------------------------- moon
let _moon;
function moonSprite() {
  if (_moon) return _moon;
  const n = 300, c = cv(n, n), x = c.getContext('2d'), r = mulberry(5);
  x.fillStyle = '#fff3d6'; x.beginPath(); x.arc(n / 2, n / 2, n / 2 - 4, 0, 7); x.fill();
  x.globalCompositeOperation = 'source-atop';
  for (let i = 0; i < 14; i++) { x.fillStyle = `rgba(214,190,150,${.12 + r() * .14})`; x.beginPath(); x.arc(40 + r() * 220, 40 + r() * 220, 10 + r() * 34, 0, 7); x.fill(); }
  return (_moon = c);
}
function moon(ctx, x, y, r, a = 1) {
  if (a <= 0) return;
  glow(ctx, x, y, r * 6, .5 * a, '255,226,170'); glow(ctx, x, y, r * 2.2, .55 * a, '255,240,205');
  ctx.save(); ctx.globalAlpha = a; ctx.drawImage(moonSprite(), x - r, y - r, r * 2, r * 2); ctx.restore();
}

// ---------------------------------------------------------------- palms, houses
function palm(x, bx, by, h, lean, seed) {
  const r = mulberry(seed), tx = bx + lean, ty = by - h;
  x.lineWidth = 16; x.beginPath(); x.moveTo(bx, by); x.quadraticCurveTo(bx + lean * .2, by - h * .5, tx, ty); x.stroke();
  for (let i = 0; i < 9; i++) {
    const a = -Math.PI / 2 + (i - 4) * .38 + (r() - .5) * .2, L = 120 + r() * 50;
    const ex = tx + Math.cos(a) * L, ey = ty + Math.sin(a) * L * .55 + L * .35;
    x.beginPath(); x.moveTo(tx, ty);
    x.quadraticCurveTo(tx + Math.cos(a) * L * .5, ty + Math.sin(a) * L * .5 - 18, ex, ey);
    x.quadraticCurveTo(tx + Math.cos(a) * L * .45, ty + Math.sin(a) * L * .5 + 6, tx, ty + 6); x.fill();
  }
}
function houses(x, w, base, seed, o) {
  const r = mulberry(seed), wins = [];
  let px = 0;
  while (px < w) {
    const bw = o.wmin + r() * (o.wmax - o.wmin), bh = o.hmin + r() * (o.hmax - o.hmin), top = base - bh;
    x.fillRect(px, top, bw + 2, bh + 400);
    // parapet teeth
    for (let k = px + 6; k < px + bw - 10; k += 22) x.fillRect(k, top - 10, 11, 12);
    if (r() < o.dome) { x.beginPath(); x.ellipse(px + bw / 2, top, bw * .28, bw * .22, 0, Math.PI, 0); x.fill(); }
    // windows: a grid, arched tops
    const cols = Math.max(1, Math.floor(bw / o.wg)), rows = Math.max(1, Math.floor(bh / o.hg));
    for (let i = 0; i < cols; i++) for (let j = 0; j < rows; j++) {
      if (r() < o.skip) continue;
      const ww = o.ww, wh = o.wh, wx = px + (i + .5) * (bw / cols) - ww / 2, wy = top + 22 + j * o.hg;
      if (wy + wh > base - 6) continue;
      wins.push({ x: wx, y: wy, w: ww, h: wh, r: r(), arch: o.arch });
    }
    px += bw + (r() < .25 ? 18 + r() * 50 : 0);
  }
  return wins;
}
function winPath(c, w) {
  c.beginPath();
  if (w.arch) { c.moveTo(w.x, w.y + w.h); c.lineTo(w.x, w.y + w.w / 2); c.arc(w.x + w.w / 2, w.y + w.w / 2, w.w / 2, Math.PI, 0); c.lineTo(w.x + w.w, w.y + w.h); c.closePath(); }
  else c.rect(w.x, w.y, w.w, w.h);
}

// ---------------------------------------------------------------- Nineveh
const X0 = -560, LW = 3100;
export function buildCity() {
  const r = mulberry(901);
  const moonP = [1120 - X0, 300 + 220];
  const sky = sheet(LW, 1520, '#0a1330', x => x.fillRect(0, 0, LW, 1520), { trans: .2, light: [moonP[0], moonP[1], 1100], lightCol: '255,214,150', rim: 0, shade: 0, shadow: false });
  const stars = Array.from({ length: 70 }, () => ({ x: r() * W * 1.3 - W * .15, y: r() * 430, s: .8 + r() * 1.8, ph: r() * 6 }));
  const hills = sheet(LW, 560, '#6a86c2', (x, w, h) => ridge(x, w, h, 150, 120, 31, 40, .55), { trans: .2, light: [moonP[0], -150, 1200], lightCol: '255,214,150' });
  let farW = [];
  const far = sheet(LW, 600, '#3f5a92', (x, w, h) => {
    x.fillRect(0, 320, w, h); for (let k = 0; k < w; k += 30) x.fillRect(k, 304, 16, 18);
    // ziggurat
    const zx = 1700; [[460, 60], [350, 60], [240, 60], [130, 60]].forEach(([zw, zh], i) => x.fillRect(zx - zw / 2, 320 - (i + 1) * zh, zw, zh + 2));
    x.fillRect(zx - 6, 320 - 4 * 60 - 40, 12, 40);
    farW = houses(x, w, 330, 77, { wmin: 70, wmax: 170, hmin: 50, hmax: 150, dome: .12, wg: 34, hg: 36, ww: 9, wh: 14, skip: .35, arch: false })
      .filter(q => !(q.x > zx - 240 && q.x < zx + 240));
    // gate with arches
    x.fillRect(560, 170, 260, 160); cutWith(x, c => { c.beginPath(); c.moveTo(640, 330); c.lineTo(640, 250); c.arc(690, 250, 50, Math.PI, 0); c.lineTo(740, 330); c.fill(); });
  }, { trans: .2, light: [moonP[0], 0, 1200], lightCol: '255,214,150' });
  let nearW = [];
  const near = sheet(LW, 560, '#22346a', (x, w, h) => {
    nearW = houses(x, w, 300, 123, { wmin: 110, wmax: 230, hmin: 90, hmax: 210, dome: .3, wg: 52, hg: 58, ww: 16, wh: 26, skip: .3, arch: true });
    x.fillRect(0, 290, w, h);
    [260, 1240, 2380].forEach((px, i) => palm(x, px, 300, 230 + i * 30, (i - 1) * 40, 50 + i));
  }, { trans: .12, light: [moonP[0], -300, 1300], lightCol: '255,214,150' });
  const river = sheet(LW, 300, '#14214a', (x, w, h) => { x.beginPath(); x.moveTo(0, 30); for (let k = 0; k <= w; k += 60) x.lineTo(k, 26 + Math.sin(k * .02) * 6); x.lineTo(w, h); x.lineTo(0, h); x.fill(); }, { trans: .12, light: [moonP[0], 0, 700], lightCol: '255,214,150', rim: .7 });
  const front = sheet(LW, 520, '#070b1e', (x, w, h) => {
    x.beginPath(); x.moveTo(0, 330); for (let k = 0; k <= w; k += 50) x.lineTo(k, 330 + Math.sin(k * .013) * 26 + Math.sin(k * .05) * 8); x.lineTo(w, h); x.lineTo(0, h); x.fill();
    const rr = mulberry(9);
    for (let k = 0; k < w; k += 9 + rr() * 14) { const hh = 40 + rr() * 110, lean = (rr() - .5) * 30; x.beginPath(); x.moveTo(k - 4, 350); x.lineTo(k + lean, 350 - hh); x.lineTo(k + 4, 350); x.fill(); }
    [560 - X0 - 500, 1820 - X0, 2850].forEach((px, i) => palm(x, px, 380, 300 + i * 20, i === 1 ? -70 : 60, 70 + i));
  }, { trans: 0, rim: .55 });
  const wisp = sheet(900, 200, '#33457e', (x) => { const q = mulberry(21); for (let k = 0; k < 9; k++) { x.beginPath(); x.ellipse(120 + k * 80, 100 + (q() - .5) * 40, 110 + q() * 60, 28 + q() * 22, 0, 0, 7); x.fill(); } }, { trans: .35, light: [450, 100, 500], lightCol: '255,214,150', rim: .3, shadow: false });
  const boat = sheet(220, 120, '#0a0f26', (x) => { x.beginPath(); x.moveTo(0, 70); x.quadraticCurveTo(110, 130, 220, 70); x.lineTo(200, 66); x.quadraticCurveTo(110, 100, 20, 66); x.fill(); x.fillRect(104, 6, 6, 70); x.beginPath(); x.moveTo(110, 8); x.lineTo(170, 60); x.lineTo(110, 60); x.fill(); }, { trans: 0, rim: .6 });
  const SHOOT = [16, 22.5, 29, 35.5, 41, 236.5, 241.8, 246.5, 250.5].map((k, i) => ({ k, x: 500 + ((i * 617) % 1200), y: 60 + ((i * 211) % 220) }));
  const flock = Array.from({ length: 7 }, (_, i) => ({ dx: -i * 70 - (i % 2) * 30, dy: (i % 3) * 34 - 20 + i * 8, ph: i * 1.3 }));
  [222, 225.3, 228.4, 230.6].forEach(k => ev(k + .2, 'thunder', { v: .3 }));
  const wins = [...farW.map(w => ({ ...w, L: 'far' })), ...nearW.map(w => ({ ...w, L: 'near' }))];
  // light state, S1: most lit, then go out one by one (the city turns away); S8: light up again
  const rr = mulberry(55);
  wins.forEach((w, i) => { w.i = i; w.lit0 = rr() < .78; w.off = w.lit0 && rr() < .88 ? 15.5 + clamp((w.x - 300) / 2500) * 22 + rr() * 4.5 : 1e9; });
  const keep = wins.filter(w => w.lit0 && w.off > 1e8);
  const offs = wins.filter(w => w.off < 1e8).sort((a, b) => a.off - b.off);
  offs.forEach((w, k) => { if (k % 4 === 0) ev(w.off, 'tap', { v: .5 + (k % 3) * .15, pan: (w.x + X0 - 960) / 1400 }); });
  // return: cascade outward from the centre of the screen
  const cx = 960 - X0;
  const ons = wins.filter(w => !keep.includes(w)).map(w => ({ w, d: Math.abs(w.x - cx) + rr() * 240 })).sort((a, b) => a.d - b.d);
  ons.forEach((o, k) => { o.w.on = 243.4 + 8.6 * Math.pow(k / ons.length, .8); if (k % 5 === 0) ev(o.w.on, 'tap', { v: .45, pan: (o.w.x + X0 - 960) / 1400 }); if (k % 17 === 0) ev(o.w.on, 'chime', { v: .4, pan: (o.w.x + X0 - 960) / 1400 }); });
  // cloud of punishment (return only)
  const cloud = (seed) => sheet(2100, 700, '#140c1c', (x, w, h) => {
    const q = mulberry(seed); x.fillRect(0, 0, w, 330);
    for (let k = 0; k < 46; k++) { const cx = q() * w, cy = 260 + q() * 220 - Math.abs(cx - w / 2) * .06, rad = 70 + q() * 110; x.beginPath(); x.arc(cx, cy, rad, 0, 7); x.fill(); }
  }, { trans: .22, light: [1050, 900, 1400], lightCol: '220,80,60', rim: .35, rimCol: '#ff9a70', shadowBlur: 22 });
  const cl = cloud(3), cr = cloud(4);

  function drawWins(ctx, list, t, mode, lightK) {
    ctx.save();
    for (const w of list) {
      let on;
      if (mode === 'city') on = w.lit0 ? 1 - seg(t, w.off, w.off + .25) : 0;
      else on = keep.includes(w) ? 1 : seg(t, w.on, w.on + .5);
      on *= lightK;
      winPath(ctx, w);
      ctx.fillStyle = '#0a0f26'; ctx.fill();
      if (on > .01) { ctx.globalAlpha = clamp(on * flick(t, w.i)); ctx.fillStyle = '#ffb862'; ctx.fill(); ctx.globalAlpha = 1; glow(ctx, w.x + w.w / 2, w.y + w.h / 2, w.w * 3.2, .32 * on, '255,170,90'); }
    }
    ctx.restore();
  }

  return function draw(ctx, t, o) {
    const mode = o.mode, d = drift(t), cam = { x: (o.cam?.x || 0) + d.x, y: (o.cam?.y || 0) + d.y, s: o.cam?.s || 1 };
    const lightK = o.lightK ?? 1;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#050816'; ctx.fillRect(0, 0, W, H);
    camAt(ctx, cam, 0); put(ctx, sky, X0, -220, { light: .9 * lightK, shadow: false });
    camAt(ctx, cam, .02);
    for (const s of stars) { const a = (.5 + .5 * Math.sin(t * 1.3 + s.ph)) * .8 * lightK * (o.starA ?? 1); ctx.fillStyle = `rgba(255,236,200,${a})`; ctx.fillRect(s.x, s.y, s.s, s.s); }
    camAt(ctx, cam, .05); moon(ctx, 1120, 300, 62, (o.moonA ?? 1) * lightK);
    camAt(ctx, cam, .08);
    for (let i = 0; i < 2; i++) { const wx = 2300 - ((t * 38 + i * 1500) % 3300); put(ctx, wisp, wx, 190 + i * 150, { light: .8 * lightK, alpha: .85, shadow: false }); }
    for (const s of SHOOT) { const u = (t - s.k) / .7; if (u < 0 || u > 1) continue; const hx = s.x - u * 420, hy = s.y + u * 170; const g = ctx.createLinearGradient(hx, hy, hx + 170, hy - 69); g.addColorStop(0, `rgba(255,244,214,${.95 * Math.sin(Math.PI * u)})`); g.addColorStop(1, 'rgba(255,244,214,0)'); ctx.strokeStyle = g; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(hx + 170, hy - 69); ctx.stroke(); }
    const fb = mode === 'city' ? (t - 13.5) / 7 : (t - 244) / 8;
    if (fb > 0 && fb < 1) for (const b of flock) birdShape(ctx, (mode === 'city' ? lerp(-100, 2100, fb) : lerp(2100, -100, fb)) + b.dx, 250 + b.dy + Math.sin(t * 1.3 + b.ph) * 12, .8, Math.sin(t * 8 + b.ph) * .5, '#1b2650');
    if (o.cloud != null) {
      const k = o.cloud; camAt(ctx, cam, .1);
      put(ctx, cl, -1050 - k * 1300, -170 - k * 60, { light: .9 * lightK, sd: [14, 20] });
      put(ctx, cr, 900 + k * 1300, -210 - k * 60, { light: .9 * lightK, sd: [14, 20] });
      for (const q of [222, 225.3, 228.4, 230.6]) { const u = t - q; if (u > 0 && u < .5) glow(ctx, 600 + (q * 37 % 700), 250, 560, .55 * Math.exp(-u * 7), '255,90,60'); }
    }
    camAt(ctx, cam, .15); put(ctx, hills, X0, 470, { light: lightK, sd: [8, 10] });
    camAt(ctx, cam, .35); put(ctx, far, X0, 460, { light: lightK, sd: [8, 12] });
    ctx.save(); ctx.translate(X0, 460); drawWins(ctx, wins.filter(w => w.L === 'far'), t, mode, lightK); ctx.restore();
    camAt(ctx, cam, .55); put(ctx, near, X0, 600, { light: lightK, sd: [10, 14] });
    ctx.save(); ctx.translate(X0, 600); drawWins(ctx, wins.filter(w => w.L === 'near'), t, mode, lightK); ctx.restore();
    camAt(ctx, cam, .72); put(ctx, river, X0, 860, { light: lightK, sd: [8, 10] });
    // moon reflection: broken lit strips on the river
    for (let i = 0; i < 7; i++) { const yy = 905 + i * 22, ww = 120 - i * 12 + Math.sin(t * 1.7 + i) * 18; ctx.fillStyle = `rgba(255,224,170,${.35 * lightK * (o.moonA ?? 1)})`; ctx.fillRect(1150 + Math.sin(t * .9 + i * 1.3) * 10 - ww / 2, yy, ww, 4); }
    { const bx = mode === 'city' ? -300 + (t - 13) * 62 : 2300 - (t - 218) * 50;
      put(ctx, boat, bx, 850 + Math.sin(t * 1.4) * 3, { rot: Math.sin(t * 1.1) * .03, px: 110, py: 60, sd: [6, 8] }); glow(ctx, bx - 8, 800, 60, .6 * lightK * flick(t, 3), '255,180,90'); ctx.fillStyle = `rgba(255,190,110,${lightK})`; ctx.fillRect(bx - 12, 794, 8, 10); }
    camAt(ctx, cam, 1); put(ctx, front, X0, 640, { light: 0, sd: [12, 16], sa: .6 });
    ctx.setTransform(1, 0, 0, 1, 0, 0);
  };
}

// ---------------------------------------------------------------- ship
function shipSheets(hull, sailCol, trans, light) {
  const body = sheet(980, 760, hull, (x) => {
    // hull
    x.beginPath(); x.moveTo(40, 470); x.quadraticCurveTo(110, 520, 200, 560); x.lineTo(780, 560); x.quadraticCurveTo(880, 520, 950, 420);
    x.lineTo(930, 415); x.quadraticCurveTo(860, 490, 770, 500); x.lineTo(210, 500); x.quadraticCurveTo(120, 480, 70, 440); x.closePath(); x.fill();
    x.fillRect(190, 500, 600, 70); x.beginPath(); x.moveTo(200, 570); x.quadraticCurveTo(490, 660, 780, 570); x.fill();
    cutWith(x, c => { for (let k = 240; k < 760; k += 60) { c.fillRect(k, 530, 26, 7); } });
    // cargo: jars, bales, crates (the "laden ship")
    const r = mulberry(14);
    for (let k = 0; k < 11; k++) { const cx = 230 + k * 48, hh = 40 + r() * 50; x.beginPath(); x.ellipse(cx, 500 - hh / 2, 20, hh / 2, 0, 0, 7); x.fill(); x.fillRect(cx - 7, 500 - hh - 12, 14, 14); }
    for (let k = 0; k < 5; k++) { const cx = 300 + k * 90, w = 70 + r() * 20; x.fillRect(cx, 410 - r() * 40, w, 100); }
    x.beginPath(); x.moveTo(600, 500); x.lineTo(640, 400); x.lineTo(700, 400); x.lineTo(720, 500); x.fill();
    // mast, yard, ropes
    x.fillRect(486, 40, 16, 470); x.fillRect(300, 70, 390, 12);
    x.lineWidth = 3; x.beginPath(); x.moveTo(494, 40); x.lineTo(70, 440); x.moveTo(494, 40); x.lineTo(940, 415); x.moveTo(300, 76); x.lineTo(240, 470); x.moveTo(690, 76); x.lineTo(760, 470); x.stroke();
    // stern post and prow
    x.beginPath(); x.moveTo(40, 470); x.quadraticCurveTo(10, 400, 40, 360); x.lineTo(56, 366); x.quadraticCurveTo(36, 410, 70, 450); x.fill();
    x.beginPath(); x.moveTo(930, 415); x.quadraticCurveTo(975, 360, 955, 320); x.lineTo(940, 326); x.quadraticCurveTo(955, 370, 915, 420); x.fill();
  }, { trans: 0, rim: .6 });
  const sail = sheet(400, 340, sailCol, x => { x.beginPath(); x.moveTo(10, 10); x.lineTo(390, 10); x.quadraticCurveTo(410, 170, 370, 330); x.lineTo(30, 330); x.quadraticCurveTo(-10, 170, 10, 10); x.fill();
    cutWith(x, c => { c.lineWidth = 3; for (let k = 70; k < 330; k += 70) { c.beginPath(); c.moveTo(20, k); c.quadraticCurveTo(200, k + 18, 385, k); c.stroke(); } }); }, { trans, light, lightCol: '255,210,150', rim: .4 });
  return { body, sail };
}
function drawShip(ctx, S, x, y, rot, o = {}) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot);
  put(ctx, S.sail, -490 + 296, -560 + 82, { light: o.sailLight ?? .8, sd: [10, 12], sa: .4, sx: 1, sy: 1 });
  put(ctx, S.body, -490, -560, { light: 0, sd: [12, 16] });
  const ft = o.t ?? 0; ctx.fillStyle = '#c8442e'; ctx.beginPath(); ctx.moveTo(4, -524);
  for (let k = 0; k <= 6; k++) ctx.lineTo(4 + k * 16, -524 + Math.sin(ft * 9 - k * .9) * (2 + k * 1.6) + k * 1.2);
  for (let k = 6; k >= 0; k--) ctx.lineTo(4 + k * 16, -500 - k * 2.6 + Math.sin(ft * 9 - k * .9) * (2 + k * 1.6)); ctx.fill();
  ctx.restore();
}

// ---------------------------------------------------------------- harbour at dusk
export function buildHarbour() {
  const sunS = [520, 540];
  const sky = sheet(3400, 1500, '#f0c48a', x => x.fillRect(0, 0, 3400, 1500), { trans: .6, light: [sunS[0] + 700, sunS[1] + 220, 1400], lightCol: '255,215,150', rim: 0, shade: 0, shadow: false });
  const head = sheet(3400, 300, '#c78860', (x, w, h) => ridge(x, w, h, 110, 70, 12, 50, .6), { trans: .45, light: [1200, -200, 1400] });
  const sea = sheet(3400, 560, '#a86a5a', x => x.fillRect(0, 30, 3400, 560), { trans: .3, light: [1200, 0, 900], rim: .7 });
  const pier = sheet(1100, 420, '#6b3b40', x => { x.fillRect(0, 120, 760, 26); for (let k = 20; k < 760; k += 90) x.fillRect(k, 120, 22, 300); x.fillRect(700, 60, 28, 360); x.fillRect(0, 160, 760, 10); x.beginPath(); x.arc(714, 52, 18, 0, 7); x.fill(); }, { trans: .15, light: [200, -100, 800] });
  const ship = shipSheets('#2e1822', '#5a3442', .75, [200, 120, 420]);
  const waves = sheet(3800, 320, '#150b10', (x, w, h) => { x.beginPath(); x.moveTo(0, h); x.lineTo(0, 80); for (let k = 0; k <= w; k += 110) { x.quadraticCurveTo(k + 30, 40, k + 55, 70); x.quadraticCurveTo(k + 80, 95, k + 110, 80); } x.lineTo(w, h); x.fill(); }, { trans: 0, rim: .7 });
  const birds = [{ x0: -200, y: 260, v: 70, ph: 0, s: 1 }, { x0: -380, y: 320, v: 64, ph: 1.7, s: .8 }, { x0: -520, y: 230, v: 76, ph: 3.1, s: .7 }, { x0: 300, y: 180, v: 90, ph: 2.2, s: .6 }, { x0: 60, y: 380, v: 110, ph: .8, s: .9 }, { x0: 700, y: 300, v: 60, ph: 4, s: .55 }];
  for (let i = 0; i < 7; i++) ev(46.2 + i * 2.3 + .85, 'plop', { v: .5, pan: (i % 3 - 1) * .5 });
  ev(45.5, 'gull', { pan: -.4 }); ev(50.8, 'gull', { pan: .2 }); ev(55.4, 'gull', { pan: .5 });
  ev(47, 'creak', { v: .5 }); ev(52.5, 'creak', { v: .45 }); ev(58, 'creak', { v: .5 });
  return function draw(ctx, t) {
    const lt = t - 43.5, d = drift(t);
    const cam = { x: lt * 26 + d.x, y: d.y, s: 1.02 };
    const dim = 1 - .55 * ss(seg(t, 58.5, 63)), sunY = sunS[1] + 110 * seg(t, 45, 63);
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#20100c'; ctx.fillRect(0, 0, W, H);
    camAt(ctx, cam, 0); put(ctx, sky, -700, -220, { light: dim, shadow: false });
    glow(ctx, sunS[0], sunY, 520, .5 * dim, '255,214,150'); glow(ctx, sunS[0], sunY, 130, .9 * dim, '255,244,214');
    ctx.fillStyle = `rgba(255,246,222,${dim})`; ctx.beginPath(); ctx.arc(sunS[0], sunY, 62, 0, 7); ctx.fill();
    camAt(ctx, cam, .18); put(ctx, head, -700, 400, { light: dim });
    camAt(ctx, cam, .3); put(ctx, sea, -700, 560, { light: dim });
    for (let i = 0; i < 8; i++) { const ww = 240 - i * 22 + Math.sin(t * 1.4 + i) * 30; ctx.fillStyle = `rgba(255,232,190,${.45 * dim})`; ctx.fillRect(sunS[0] + Math.sin(t + i) * 14 - ww / 2 + cam.x * .3 * .0, 612 + i * 26, ww, 5); }
    for (let i = 0; i < 7; i++) { const k = 46.2 + i * 2.3, u = (t - k) / .9; if (u < 0 || u > 1) continue; const fx = 300 + ((i * 531) % 1300) + cam.x * .5, fy = 650 + (i % 3) * 40; ctx.save(); ctx.translate(fx + u * 90, fy - Math.sin(Math.PI * u) * 120); ctx.rotate(-1 + u * 2); ctx.fillStyle = '#5a2e30'; ctx.beginPath(); ctx.ellipse(0, 0, 26, 9, 0, 0, 7); ctx.fill(); ctx.beginPath(); ctx.moveTo(-22, 0); ctx.lineTo(-40, -12); ctx.lineTo(-40, 12); ctx.fill(); ctx.restore(); }
    camAt(ctx, cam, .25);
    for (const b of birds) { const bx = b.x0 + (t - 43.5) * b.v, by = b.y + Math.sin(t * .8 + b.ph) * 14, f = Math.sin(t * 7 + b.ph) * .5; ctx.save(); ctx.translate(bx, by); ctx.scale(b.s, b.s); ctx.fillStyle = '#5a2e30';
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(-18, -14 - f * 18, -38, -4 - f * 26); ctx.quadraticCurveTo(-18, -4, 0, 6); ctx.quadraticCurveTo(18, -4, 38, -4 - f * 26); ctx.quadraticCurveTo(18, -14 - f * 18, 0, 0); ctx.fill(); ctx.restore(); }
    camAt(ctx, cam, .5); put(ctx, pier, -260, 560, { light: dim });
    const sp = .25 + .75 * .7;
    camAt(ctx, cam, .7);
    drawShip(ctx, ship, 1180 + cam.x * sp + 380 * ss(seg(t, 55, 63)), 880 + Math.sin(t * 1.1) * 7, Math.sin(t * .9) * .025, { sailLight: dim, t });
    camAt(ctx, cam, 1); put(ctx, waves, -800 + Math.sin(t * .7) * 30, 820 + Math.sin(t * 1.2) * 6, { light: 0, sd: [10, 14] });
    ctx.setTransform(1, 0, 0, 1, 0, 0);
  };
}

// ---------------------------------------------------------------- storm
function waveStrip(w, h, col, crest, period, seed, o) {
  return sheet(w, h, col, (x) => { const r = mulberry(seed); x.beginPath(); x.moveTo(0, h); x.lineTo(0, crest);
    for (let k = 0; k <= w; k += period) { const a = crest * (.55 + r() * .6); x.quadraticCurveTo(k + period * .35, crest - a, k + period * .62, crest - a * 1.05); x.quadraticCurveTo(k + period * .58, crest - a * .5, k + period, crest); }
    x.lineTo(w, h); x.fill(); }, o);
}
export function flashAt(t) {
  let f = 0; for (const k of LIGHTNING) { const u = t - k; if (u >= 0 && u < 1.2) f = Math.max(f, Math.exp(-u * 5) * (u < .09 ? u / .09 : 1) + (u > .14 && u < .3 ? .6 * Math.exp(-(u - .14) * 9) : 0)); } return clamp(f, 0, 1.3);
}
export function buildStorm() {
  const r = mulberry(77);
  const sky = sheet(3400, 1500, '#1a1a30', x => x.fillRect(0, 0, 3400, 1500), { trans: .9, light: [1700, 300, 1500], lightCol: '205,215,255', rim: 0, shade: 0, shadow: false });
  const clouds = sheet(3600, 640, '#4a4a72', (x, w) => { const q = mulberry(8); x.fillRect(0, 0, w, 300); for (let k = 0; k < w; k += 120) { x.beginPath(); x.arc(k, 300 + q() * 80, 80 + q() * 90, 0, 7); x.fill(); } }, { trans: .7, light: [1800, 300, 1400], lightCol: '205,215,255', rim: .35 });
  const wf = waveStrip(3800, 500, '#393a60', 70, 170, 1, { trans: .5, light: [1900, -300, 1600], lightCol: '205,215,255' });
  const wm = waveStrip(3800, 520, '#24253f', 120, 280, 2, { trans: .35, light: [1900, -300, 1600], lightCol: '205,215,255' });
  const wn = waveStrip(3900, 560, '#060509', 190, 460, 3, { trans: 0, rim: .8, rimCol: '#c8d0ff' });
  const ship = shipSheets('#0f0d18', '#232036', .4, [200, 60, 420]);
  const rain = cv(1200, 900), rx = rain.getContext('2d');
  rx.strokeStyle = 'rgba(170,180,225,.33)'; rx.lineCap = 'round';
  for (let i = 0; i < 420; i++) { const px = r() * 1200, py = r() * 900, l = 30 + r() * 60; rx.lineWidth = .8 + r() * 1.4; rx.beginPath(); rx.moveTo(px, py); rx.lineTo(px - l * .32, py + l); rx.stroke(); }
  const bolts = LIGHTNING.map((k, i) => { const q = mulberry(300 + i), pts = []; let x = 300 + q() * 1300, y = -20; pts.push([x, y]); while (y < 560) { y += 40 + q() * 50; x += (q() - .5) * 120; pts.push([x, y]); } return { k, pts }; });
  LIGHTNING.forEach((k, i) => ev(k + .2, 'thunder', { v: k > 86 && k < 100 ? .45 : .7 + (i % 2) * .2, pan: (bolts[i].pts[0][0] - 960) / 1400 }));
  [64.2, 68.4, 72.6, 76.4, 79.8].forEach(k => ev(k, 'crash', { v: .7 }));
  [65, 71, 75.5, 81.5].forEach(k => ev(k, 'creak', { v: .9 }));
  const JET = [67.5, 70.6, 74.8, 78.2]; JET.forEach(k => ev(k + 1.0, 'splash', { v: .4 }));
  return function draw(ctx, t, o = {}) {
    const f = flashAt(t), dy = o.dy || 0;
    const shake = { x: Math.sin(t * .43) * 40 + Math.sin(t * 2.3) * 6, y: Math.sin(t * .61) * 12 + Math.sin(t * 3.1) * 3 + dy, s: 1.05, r: Math.sin(t * .9) * .012 };
    const L = .18 + f;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#0a0a16'; ctx.fillRect(0, 0, W, H);
    camAt(ctx, shake, 0); put(ctx, sky, -700, -220, { light: Math.min(1, L), shadow: false });
    camAt(ctx, shake, .05);
    for (const b of bolts) { const u = t - b.k; if (u < 0 || u > .32) continue; const a = (u < .05 ? 1 : Math.exp(-(u - .05) * 9)) * (u > .12 && u < .17 ? .4 : 1);
      ctx.save(); ctx.lineJoin = 'miter'; ctx.strokeStyle = `rgba(235,240,255,${a})`; ctx.lineWidth = 5; ctx.shadowColor = 'rgba(190,205,255,1)'; ctx.shadowBlur = 30; ctx.beginPath(); b.pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.stroke(); ctx.restore(); }
    camAt(ctx, shake, .12); put(ctx, clouds, -800 + Math.sin(t * .2) * 80, -120, { light: Math.min(1, L), sd: [10, 16] });
    camAt(ctx, shake, .3); put(ctx, wf, -900 + Math.sin(t * .5) * 70, 500 + Math.sin(t * .9) * 14, { light: Math.min(1, L * .9), sd: [10, 14] });
    camAt(ctx, shake, .5); put(ctx, wm, -900 + Math.sin(t * .45 + 1) * 110, 560 + Math.sin(t * .8 + 1) * 26, { light: Math.min(1, L * .8), sd: [12, 16] });
    camAt(ctx, shake, .65);
    const sx = o.shipX ?? 1120, rot = Math.sin(t * 1.25) * .13 + Math.sin(t * 2.7) * .04, heave = Math.sin(t * 1.25 + .6) * 34;
    drawShip(ctx, ship, sx, 860 + heave, rot, { sailLight: Math.min(1, .2 + f), t });
    for (const k of JET) { const u = (t - k) / 1.1; if (u < 0 || u > 1) continue; const jx = sx - 120 - u * 260, jy = 800 + heave - Math.sin(Math.PI * u * .8) * 170 + u * 220; ctx.save(); ctx.translate(jx, jy); ctx.rotate(-u * 5); ctx.fillStyle = '#0f0d18'; ctx.beginPath(); ctx.ellipse(0, 0, 22, 34, 0, 0, 7); ctx.fill(); ctx.fillRect(-8, -46, 16, 16); ctx.restore(); }
    if (o.after) o.after(ctx, t);
    camAt(ctx, shake, 1); put(ctx, wn, -1000 + Math.sin(t * .55 + 2) * 160, 720 + Math.sin(t * .95 + 2) * 40, { light: 0, sd: [14, 18], sa: .6 });
    // rain (screen space), and the flash on the air itself
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const ry = (t * 1400) % 900, rxo = (t * 420) % 1200;
    ctx.globalAlpha = .8;
    for (let i = -1; i < 3; i++) for (let j = -1; j < 2; j++) ctx.drawImage(rain, i * 1200 - rxo, j * 900 + ry);
    ctx.globalAlpha = 1;
    if (f > .01) { ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = `rgba(170,180,230,${.16 * f})`; ctx.fillRect(0, 0, W, H); ctx.globalCompositeOperation = 'source-over'; }
  };
}

// ---------------------------------------------------------------- the lots, seen from above
export function buildLots() {
  const deck = sheet(2300, 1400, '#3b2516', (x, w, h) => { x.fillRect(0, 0, w, h); cutWith(x, c => { for (let k = 0; k < h; k += 118) c.fillRect(0, k, w, 6); }); }, { trans: .7, light: [620, 400, 1100], lightCol: '255,190,110', rim: .6 });
  const nails = mulberry(2);
  const back = sheet(190, 270, '#2b1a10', x => { x.beginPath(); x.roundRect(0, 0, 190, 270, 14); x.fill(); cutWith(x, c => { c.lineWidth = 3; c.beginPath(); c.roundRect(14, 14, 162, 242, 9); c.stroke(); }); }, { trans: 0, rim: .7 });
  const face = sheet(190, 270, '#cdb68a', x => { x.beginPath(); x.roundRect(0, 0, 190, 270, 14); x.fill(); }, { trans: .6, light: [95, 135, 220], lightCol: '255,200,120', rim: .6 });
  const faceDim = sheet(190, 270, '#6f5c40', x => { x.beginPath(); x.roundRect(0, 0, 190, 270, 14); x.fill(); }, { trans: 0, rim: .5 });
  const pos = [[680, 470], [960, 470], [1240, 470]];
  FLIPS.forEach((k, i) => { ev(k, 'flip', { v: .8, pan: (pos[i][0] - 960) / 1200 }); });
  ev(FLIPS[2] + .45, 'chime', { v: .5 });
  [0, 1, 2].forEach(i => ev(84.7 + i * .45, 'tap', { v: 1.2 })); ev(85.9, 'paper', { v: 1 }); ev(86.9, 'paper', { v: 1 });
  const rain = mulberry(5), drops = Array.from({ length: 30 }, () => ({ x: rain() * W, y: rain() * H, ph: rain() * 3 }));
  return function draw(ctx, t) {
    const d = drift(t), rock = Math.sin(t * 1.25) * .025;
    const cam = { x: d.x + Math.sin(t * 1.25) * 14, y: d.y, s: 1 + .07 * ss(seg(t, 84, 99)), r: rock };
    const lx = 520 + Math.sin(t * 1.6) * 90, ly = 210 + Math.cos(t * 1.6) * 20, f = flashAt(t);
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#120a06'; ctx.fillRect(0, 0, W, H);
    camAt(ctx, cam, .2); put(ctx, deck, -190, -160, { light: clamp(.55 + .25 * Math.sin(t * 1.6) + f * .4), shadow: false });
    camAt(ctx, cam, .6);
    pos.forEach(([px0, py0], i) => {
      const inn = eo(seg(t, 84.1 + i * .45, 84.7 + i * .45)), sh = ss(seg(t, 85.9, 86.8)) - ss(seg(t, 86.9, 87.8));
      const px = px0 + (i === 0 ? 560 : i === 2 ? -560 : 0) * sh, py = py0 - (1 - inn) * 900 + (i === 1 ? 0 : Math.sin(Math.PI * sh) * (i ? 80 : -80));
      const u = seg(t, FLIPS[i], FLIPS[i] + .55), c = Math.cos(Math.PI * eio(u)), lift = Math.sin(Math.PI * u) * 40;
      const S = c >= 0 ? back : i === 2 ? face : faceDim, sx = Math.max(.02, Math.abs(c));
      put(ctx, S, px, py - lift, { px: 95, py: 135, sx, sy: 1 + lift * .002, light: i === 2 && c < 0 ? .4 + .6 * seg(t, FLIPS[2] + .4, FLIPS[2] + 1.4) : .25, sd: [10 + lift * .6, 14 + lift * .8], sa: .6 });
      if (i === 2 && c < 0) { const g = seg(t, FLIPS[2] + .4, FLIPS[2] + 1.6); glow(ctx, px, py - lift, 330, .55 * g * flick(t), '255,186,90'); }
    });
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    glow(ctx, lx, ly, 700, .32, '255,170,90');
    for (const q of drops) { const u = ((t * .9 + q.ph) % 1); ctx.strokeStyle = `rgba(200,190,170,${.35 * (1 - u)})`; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(q.x, q.y, 4 + u * 26, 0, 7); ctx.stroke(); }
    if (f > .01) { ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = `rgba(170,180,230,${.12 * f})`; ctx.fillRect(0, 0, W, H); ctx.globalCompositeOperation = 'source-over'; }
  };
}

// ---------------------------------------------------------------- under water + whale
function buildUnder(pal) {
  const water = sheet(3000, 2400, pal.water, x => x.fillRect(0, 0, 3000, 2400), { trans: pal.wt ?? .35, light: [1500, 200, 1700], lightCol: pal.light, rim: 0, shade: 0, shadow: false });
  const rocksF = sheet(3200, 600, pal.far, (x, w, h) => ridge(x, w, h, 260, 200, 41, 60, .5), { trans: .4, light: [1600, -600, 1500], lightCol: pal.light });
  const kelp = sheet(3200, 900, pal.mid, (x, w, h) => {
    const q = mulberry(17); ridge(x, w, h, 640, 80, 18, 70, .5);
    for (let k = 40; k < w; k += 90 + q() * 120) { const hh = 140 + q() * 230; x.beginPath(); x.moveTo(k - 10, 700); for (let j = 0; j <= 10; j++) x.lineTo(k + Math.sin(j * .9 + k) * 26 - 10, 700 - hh * j / 10); for (let j = 10; j >= 0; j--) x.lineTo(k + Math.sin(j * .9 + k) * 26 + 10 + (j === 10 ? 0 : 6), 700 - hh * j / 10); x.fill(); }
  }, { trans: .25, light: [1600, -600, 1500], lightCol: pal.light });
  const rocksN = sheet(3300, 1100, pal.near, (x, w, h) => ridge(x, w, h, 230, 170, 51, 50, .45), { trans: 0, rim: .55, rimCol: pal.rim });
  const bub = mulberry(61), bubbles = Array.from({ length: 46 }, () => ({ x: bub() * 2400 - 240, r: 3 + bub() * 9, sp: 50 + bub() * 90, ph: bub() * 1200 }));
  return function draw(ctx, t, cam, o = {}) {
    const L = o.light ?? 1;
    camAt(ctx, cam, 0); put(ctx, water, -540, -700, { light: L, shadow: false });
    camAt(ctx, cam, .1);
    ctx.save(); ctx.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 5; i++) { const x0 = 80 + i * 410 + Math.sin(t * .3 + i * 1.7) * 60, w0 = 50 + (i % 3) * 30; const g = ctx.createLinearGradient(0, -700, 0, 1100); g.addColorStop(0, `rgba(${pal.shaft},${(o.shaft ?? .08) * L})`); g.addColorStop(1, `rgba(${pal.shaft},0)`); ctx.fillStyle = g; ctx.filter = 'blur(14px)'; ctx.beginPath(); ctx.moveTo(x0, -700); ctx.lineTo(x0 + w0, -700); ctx.lineTo(x0 + w0 + 260, 1100); ctx.lineTo(x0 + 200, 1100); ctx.fill(); ctx.filter = 'none'; }
    ctx.restore();
    camAt(ctx, cam, .3); put(ctx, rocksF, -640, 600, { light: L });
    if (o.mid) o.mid(ctx);
    camAt(ctx, cam, .55); put(ctx, kelp, -640, 380, { light: L, rot: Math.sin(t * .5) * .004, sd: [12, 16] });
    camAt(ctx, cam, .6);
    for (let sI = 0; sI < 2; sI++) { const dir = sI ? 1 : -1, base = ((t * (90 + sI * 40) + sI * 1700) % 3400); for (let i = 0; i < 12; i++) { const fx = (dir < 0 ? 2500 - base : -700 + base) + ((i * 97) % 260) * dir, fy = 300 + sI * 260 + ((i * 53) % 150) + Math.sin(t * 2 + i) * 10; ctx.fillStyle = pal.mid; ctx.globalAlpha = .9 * L; ctx.beginPath(); ctx.ellipse(fx, fy, 22, 8, 0, 0, 7); ctx.fill(); ctx.beginPath(); ctx.moveTo(fx - dir * 18, fy); ctx.lineTo(fx - dir * 36, fy - 10 + Math.sin(t * 14 + i) * 3); ctx.lineTo(fx - dir * 36, fy + 10 + Math.sin(t * 14 + i) * 3); ctx.fill(); ctx.globalAlpha = 1; } }
    if (o.jelly) for (let i = 0; i < 4; i++) { const jx = 300 + i * 430 + Math.sin(t * .6 + i) * 40, jy = 900 - ((t * (40 + i * 9) + i * 300) % 1500), pu = .85 + .15 * Math.sin(t * 3 + i * 2); ctx.save(); ctx.translate(jx, jy); ctx.globalAlpha = .55; ctx.fillStyle = 'rgb(255,236,190)'; ctx.beginPath(); ctx.ellipse(0, 0, 44 * pu, 32 / pu, 0, Math.PI, 0); ctx.fill(); ctx.lineWidth = 3; ctx.strokeStyle = 'rgb(255,236,190)'; for (let k = -2; k <= 2; k++) { ctx.beginPath(); ctx.moveTo(k * 14, 0); ctx.quadraticCurveTo(k * 14 + Math.sin(t * 3 + k + i) * 10, 40, k * 12, 80 * pu); ctx.stroke(); } ctx.restore(); glow(ctx, jx, jy, 90, .25, '255,226,160'); }
    for (const b of bubbles) { const y = 1300 - ((t * b.sp + b.ph) % 2100); ctx.strokeStyle = `rgba(220,245,240,${.45 * L})`; ctx.lineWidth = 1.6; ctx.beginPath(); ctx.arc(b.x + Math.sin(t * 2 + b.ph) * 8, y, b.r, 0, 7); ctx.stroke(); }
    if (o.front) o.front(ctx);
    camAt(ctx, cam, 1); put(ctx, rocksN, -700, 800, { light: 0, sd: [14, 18], sa: .6 });
  };
}
function whaleSheets(col, groove) {
  const body = sheet(1700, 700, col, (x) => {
    x.beginPath(); x.moveTo(1640, 330); x.quadraticCurveTo(1610, 120, 1250, 110); x.quadraticCurveTo(800, 90, 420, 240); x.quadraticCurveTo(250, 300, 150, 300);
    x.quadraticCurveTo(60, 200, 20, 150); x.quadraticCurveTo(70, 320, 110, 340); x.quadraticCurveTo(50, 460, 30, 560); x.quadraticCurveTo(120, 420, 170, 380);
    x.quadraticCurveTo(420, 420, 700, 470); x.quadraticCurveTo(1000, 520, 1260, 430); x.lineTo(1600, 380); x.closePath(); x.fill();
    // pectoral fin
    x.beginPath(); x.moveTo(980, 460); x.quadraticCurveTo(900, 600, 760, 650); x.quadraticCurveTo(880, 560, 900, 470); x.fill();
    x.strokeStyle = groove; x.lineWidth = 3; x.globalAlpha = .7;
    for (let k = 0; k < 4; k++) { x.beginPath(); x.moveTo(1240 - k * 60, 150 + k * 10); x.quadraticCurveTo(900 - k * 40, 170 + k * 20, 600 - k * 40, 280 + k * 14); x.stroke(); }
    x.globalAlpha = 1;
    cutWith(x, c => { c.beginPath(); c.arc(1330, 270, 11, 0, 7); c.fill(); });
  }, { trans: 0, rim: .45, rimCol: '#bfe8e0', shadowBlur: 20 });
  const jaw = sheet(520, 160, col, (x) => {
    x.beginPath(); x.moveTo(0, 20); x.lineTo(500, 10); x.quadraticCurveTo(520, 60, 470, 90); x.quadraticCurveTo(250, 160, 0, 120); x.closePath(); x.fill();
    x.strokeStyle = groove; x.lineWidth = 3; x.globalAlpha = .7; for (let k = 0; k < 5; k++) { x.beginPath(); x.moveTo(30, 50 + k * 14); x.lineTo(460, 40 + k * 8); x.stroke(); }
  }, { trans: 0, rim: .45, rimCol: '#bfe8e0' });
  return { body, jaw };
}
function drawWhale(ctx, Wh, x, y, s, rot, jawA, o = {}) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(s, s);
  put(ctx, Wh.jaw, 1120 - 1640 + 0, 380 - 330, { px: 0, py: 20, rot: jawA, sd: [14, 20] });
  put(ctx, Wh.body, -1640, -330, { sd: [16, 22] });
  // the eye: a faint lit hole
  glow(ctx, 1330 - 1640, 270 - 330, 26, (o.eye ?? .4), '200,240,230');
  ctx.restore();
}
export function buildDive(storm) {
  const under = buildUnder({ water: '#2a6a78', far: '#1d4c5a', mid: '#12323e', near: '#061218', light: '200,240,230', shaft: '210,245,240', rim: '#9fd8d0' });
  const Wh = whaleSheets('#06161c', '#1d3e48');
  const dropS = sheet(60, 90, '#b8c2e6', x => { x.beginPath(); x.moveTo(30, 0); x.quadraticCurveTo(60, 60, 30, 88); x.quadraticCurveTo(0, 60, 30, 0); x.fill(); }, { trans: .5, light: [30, 30, 80], lightCol: '230,235,255', rim: .6, shadow: false });
  const q = mulberry(88), drops = Array.from({ length: 34 }, () => ({ a: -Math.PI / 2 + (q() - .5) * 2.5, v: 380 + q() * 900, s: .22 + q() * .4, d: q() * .12 }));
  ev(SPLASH, 'splash', { v: 1 }); ev(103.4, 'submerge', { v: 1 }); ev(106.2, 'whale', { v: .9 }); ev(JAW_OPEN[0], 'jawopen', { v: .6 });
  ev(110.8, 'whale', { v: 1, low: 1 }); ev(JAW_CLOSE[1] - .08, 'jaw', { v: 1 });
  const shipX = 1180;
  return function draw(ctx, t) {
    const kk = ss(seg(t, 103.2, 107.6)), dd = kk * 1200, surf = kk <= 0 ? H + 200 : lerp(H + 40, -120, kk);
    // under water, everything below the surface line
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#04141a'; ctx.fillRect(0, 0, W, H);
    const d = drift(t), cam = { x: d.x, y: d.y + (1200 - dd), s: 1 };
    // whale: glides in from the dark, opens, comes at the lens
    const wx = lerp(-900, 900, eo(seg(t, 104.5, 110.2))), wy = 560;
    const jaw = .34 * ss(seg(t, JAW_OPEN[0], JAW_OPEN[1])) * (1 - ss(seg(t, JAW_CLOSE[0] + .9, JAW_CLOSE[1])));
    const zoom = 1 + 3.2 * ei2(seg(t, 110.4, 114.4));
    under(ctx, t, cam, { light: 1 - .5 * seg(t, 110, 114.4), mid: c => {
      camAt(c, cam, .45);
      // scale around the mouth so the whale comes straight at the lens
      const mx = wx + (1600 - 1640) * .62, my = wy + (360 - 330) * .62;
      c.save(); c.translate(lerp(mx, 960, seg(t, 110.4, 113.6)), lerp(my, 560, seg(t, 110.4, 113.6))); c.scale(zoom, zoom); c.translate(-mx, -my);
      drawWhale(c, Wh, wx, wy, .62, 0, jaw, { eye: .45 }); c.restore();
    } });
    // above water: the storm, clipped to above the surface
    if (surf > -40) {
      ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.beginPath(); ctx.rect(0, 0, W, Math.max(0, surf + 30)); ctx.clip();
      storm(ctx, t, { dy: dd * .9, shipX, after: (c, tt) => {
        const u = tt - SPLASH; if (u < 0 || u > 1.6) return;
        const ox = 900, oy = 800;
        for (const p of drops) { const uu = Math.max(0, u - p.d), x = ox + Math.cos(p.a) * p.v * uu, y = oy + Math.sin(p.a) * p.v * uu + 900 * uu * uu; put(c, dropS, x, y, { px: 30, py: 45, sx: p.s, sy: p.s * 1.3, rot: Math.atan2(Math.sin(p.a) * p.v + 1800 * uu, Math.cos(p.a) * p.v) - Math.PI / 2, light: 1, alpha: .85 * (1 - seg(u, 1.0, 1.6)) }); }
        c.save(); c.strokeStyle = `rgba(220,226,255,${.8 * (1 - u / 1.6)})`; c.lineWidth = 6; c.beginPath(); c.ellipse(ox, oy + 30, 40 + u * 260, 10 + u * 40, 0, 0, 7); c.stroke(); c.restore();
      } });
      ctx.restore();
      // the surface seen edge-on: a paper edge with a cold rim
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.fillStyle = '#0b2a34'; ctx.beginPath(); ctx.moveTo(0, surf + 30); for (let k = 0; k <= W; k += 40) ctx.lineTo(k, surf + 18 + Math.sin(k * .012 + t * 2) * 12); ctx.lineTo(W, surf + 60); ctx.lineTo(0, surf + 60); ctx.fill();
      ctx.fillStyle = 'rgba(190,230,240,.5)'; ctx.beginPath(); for (let k = 0; k <= W; k += 40) ctx.lineTo(k, surf + 18 + Math.sin(k * .012 + t * 2) * 12); ctx.lineTo(W, surf + 24); ctx.lineTo(0, surf + 24); ctx.fill();
    }
    // the jaws close like a curtain: two near-plane halves meeting exactly on the centre line
    const cl = ss(seg(t, JAW_CLOSE[0], JAW_CLOSE[1]));
    if (cl > 0) {
      ctx.setTransform(1, 0, 0, 1, 0, 0); const hh = H / 2 * cl;
      ctx.fillStyle = '#020607'; ctx.fillRect(0, 0, W, hh); ctx.fillRect(0, H - hh, W, hh + 1);
      if (cl < 1) { ctx.fillStyle = 'rgba(160,215,210,.35)'; ctx.fillRect(0, hh - 3, W, 3); ctx.fillRect(0, H - hh, W, 3); }
    }
  };
}
const ei2 = t => t * t * (1.6 - .6 * t);

// ---------------------------------------------------------------- the three darknesses, and the light of the words
export function buildDark() {
  const arch = (col, seed, rim) => sheet(2400, 1400, col, (x, w, h) => { x.fillRect(0, 0, w, h); cutWith(x, c => { c.beginPath(); c.ellipse(w / 2, h * .62, w * .36 - seed * 70, h * .5 - seed * 50, 0, 0, 7); c.fill(); }); }, { trans: 0, rim: .5, rimCol: rim, shadowBlur: 26 });
  const L = [arch('#0d1430', 0, '#4a5c9c'), arch('#062026', 1, '#3f8c8c'), arch('#1c0608', 2, '#8c3a2e')];
  const IN = [123.8, 125.4, 127.0];
  IN.forEach((k, i) => ev(k, 'swell', { v: .6 + i * .15 }));
  return function draw(ctx, t) {
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#020101'; ctx.fillRect(0, 0, W, H);
    const fadeOut = 1 - ss(seg(t, 129.5, 131.5));
    // a faint pulse of the belly, before the silence
    const pulse = (.5 + .5 * Math.sin(t * 2.2)) * fadeOut * (t < 131.5 ? 1 : 0);
    glow(ctx, 960, 640, 1100, .05 + .05 * pulse, '120,30,24');
    // three darknesses close in, one after another, then everything goes out
    L.forEach((S, i) => {
      const u = eo(seg(t, IN[i], IN[i] + 1.6)), a = u * fadeOut; if (a <= 0) return;
      const from = [[-900, 0], [900, 0], [0, 700]][i];
      put(ctx, S, -240 + from[0] * (1 - u), -160 + from[1] * (1 - u), { alpha: a, sd: [14, 20], sa: .7 });
    });
    // the light that stays after the words, then grows into morning water
    const after = seg(t, 145, 151) * (1 - .4 * seg(t, 152, 156));
    const grow = ss(seg(t, 163.5, 170.5));
    if (after > 0) glow(ctx, 960, 480, 760, .16 * after * flick(t), '255,190,100');
    // lights rising in the dark after the call: more and more of them
    const mk = seg(t, 141, 166);
    if (mk > 0) for (let i = 0; i < 46; i++) { if (i / 46 > mk * 1.15) break; const life = 5 + (i % 5), a = ((t * 1.0 + i * 1.37) % life) / life, mx = 160 + ((i * 397) % 1600) + Math.sin(t * .8 + i) * 30, my = 1040 - a * 1000; glow(ctx, mx, my, 14 + (i % 4) * 7, .6 * Math.sin(Math.PI * a), '255,206,130'); }
    if (grow > 0) {
      glow(ctx, 960, 470, 300 + 1600 * grow, .65 * grow, '255,200,120');
      ctx.globalAlpha = grow * .9; ctx.fillStyle = 'rgb(120,170,150)'; ctx.globalCompositeOperation = 'soft-light'; ctx.fillRect(0, 0, W, H); ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
    }
  };
}

export function buildRise() {
  const under = buildUnder({ wt: .45, water: '#3f8f96', far: '#2b6f78', mid: '#1a4e58', near: '#0a242a', light: '255,226,160', shaft: '255,226,160', rim: '#ffe2a0' });
  const Wh = whaleSheets('#0a2026', '#2c5a60');
  ev(170.5, 'whale', { v: .7 }); ev(176, 'rise', { v: .8 }); ev(184.2, 'breach', { v: .9 });
  return function draw(ctx, t) {
    const u = seg(t, 169, 187), d = drift(t);
    const cam = { x: d.x + u * 160, y: d.y + lerp(420, -260, eio(u)), s: 1.02 };
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#0c3238'; ctx.fillRect(0, 0, W, H);
    under(ctx, t, cam, { light: 1, shaft: .16, jelly: true, front: c => {
      camAt(c, cam, .45);
      const k = eio(seg(t, 169.5, 186.5)), wx = lerp(300, 1950, k), wy = lerp(640, -160, k);
      drawWhale(c, Wh, wx, wy, .55, -.3 + Math.sin(t * .8) * .02, .02, { eye: .3 });
    } });
    // the surface from below: a bright band arriving at the top
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const sy = lerp(-700, 160, eio(seg(t, 176, 187)));
    if (sy > -200) { const g = ctx.createLinearGradient(0, sy - 300, 0, sy + 60); g.addColorStop(0, 'rgba(255,240,200,.95)'); g.addColorStop(1, 'rgba(255,240,200,0)'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, sy + 60);
      glow(ctx, 1300, sy - 80, 700, .5, '255,236,190'); }
  };
}

// ---------------------------------------------------------------- the bare shore, and the gourd vine
export function buildShore() {
  const sun = [1520, 470];
  const sky = sheet(3000, 1500, '#eebd86', x => x.fillRect(0, 0, 3000, 1500), { trans: .22, light: [sun[0] + 540, sun[1] + 220, 1300], lightCol: '255,226,165', rim: 0, shade: 0, shadow: false });
  const seaF = sheet(3000, 300, '#d8a682', x => x.fillRect(0, 20, 3000, 300), { trans: .2, light: [2060, 0, 800], rim: .7 });
  const seaN = sheet(3000, 300, '#b88066', x => { x.beginPath(); x.moveTo(0, 40); for (let k = 0; k <= 3000; k += 80) x.lineTo(k, 36 + Math.sin(k * .01) * 8); x.lineTo(3000, 300); x.lineTo(0, 300); x.fill(); }, { trans: .3, light: [2060, -100, 900], rim: .6 });
  const sandF = sheet(3000, 420, '#9a6644', x => { x.beginPath(); x.moveTo(0, 60); for (let k = 0; k <= 3000; k += 60) x.lineTo(k, 50 + Math.sin(k * .004 + 1) * 34); x.lineTo(3000, 420); x.lineTo(0, 420); x.fill(); }, { trans: .25, light: [2060, -300, 1100], rim: .6 });
  const dunes = sheet(3000, 420, '#6e4329', (x, w, h) => ridge(x, w, h, 120, 70, 66, 90, .7), { trans: .15, light: [2060, -300, 1100] });
  const front = sheet(3200, 420, '#2a160c', (x, w, h) => { ridge(x, w, h, 210, 90, 71, 40, .4); const q = mulberry(4); for (let i = 0; i < 9; i++) { x.beginPath(); x.ellipse(q() * w, 200 + q() * 40, 60 + q() * 90, 40 + q() * 40, 0, 0, 7); x.fill(); } }, { trans: 0, rim: .6, rimCol: '#ffd9a0' });
  const fluke = sheet(260, 160, '#7e5446', x => { x.beginPath(); x.moveTo(130, 160); x.quadraticCurveTo(120, 90, 20, 40); x.quadraticCurveTo(90, 50, 130, 70); x.quadraticCurveTo(170, 50, 240, 40); x.quadraticCurveTo(140, 90, 130, 160); x.fill(); }, { trans: .2, rim: .5 });
  // the vine: an arching stem, leaves that open one by one, a shade on the sand beneath
  const stem = [[640, 820], [600, 700], [640, 590], [760, 520], [900, 500], [1040, 520], [1150, 580], [1200, 660], [1190, 760]];
  const leafS = (s, col) => sheet(220 * s, 200 * s, col, (x, w, h) => {
    x.save(); x.scale(s, s); x.beginPath(); x.moveTo(110, 190); x.bezierCurveTo(10, 150, -10, 60, 40, 30); x.bezierCurveTo(70, 10, 100, 30, 110, 50); x.bezierCurveTo(120, 30, 150, 10, 180, 30); x.bezierCurveTo(230, 60, 210, 150, 110, 190); x.fill(); x.restore();
    cutWith(x, c => { c.save(); c.scale(s, s); c.lineWidth = 3.2; c.beginPath(); c.moveTo(110, 180); c.lineTo(110, 60); c.moveTo(110, 140); c.lineTo(60, 80); c.moveTo(110, 140); c.lineTo(160, 80); c.moveTo(110, 110); c.lineTo(70, 50); c.moveTo(110, 110); c.lineTo(150, 50); c.stroke(); c.restore(); });
  }, { trans: .3, light: [110 * s, 40 * s, 200 * s], lightCol: '210,255,150', rim: .6, rimCol: '#e8ffb0' });
  const q = mulberry(808), leaves = [];
  const along = (u) => { const n = stem.length - 1, f = u * n, i = Math.min(n - 1, Math.floor(f)), k = f - i; return [lerp(stem[i][0], stem[i + 1][0], k), lerp(stem[i][1], stem[i + 1][1], k)]; };
  for (let i = 0; i < 15; i++) { const u = .1 + i / 15 * .88, p = along(u); leaves.push({ u, x: p[0] + (q() - .5) * 60, y: p[1] - 40 + (q() - .5) * 40, s: .8 + q() * .5, rot: (q() - .5) * 1.1, S: leafS(1, i % 3 ? '#3f6e2c' : '#335d24') }); }
  const GROW = [198.4, 206.2];
  leaves.forEach(l => { l.t = lerp(GROW[0], GROW[1], l.u) + .25; });
  leaves.forEach((l, i) => { if (i % 2 === 0) ev(l.t, 'leaf', { v: .55, pan: (l.x - 960) / 1200 }); });
  const flowers = [[880, 470], [1100, 540], [700, 610]].map((p, i) => ({ x: p[0], y: p[1], t: 207 + i * .9 }));
  flowers.forEach(f => ev(f.t, 'chime', { v: .25, pan: (f.x - 960) / 1200 }));
  ev(188.2, 'fluke', { v: .7 });
  const birds = [{ x0: 2100, y: 300, v: -90, ph: 0 }, { x0: 2260, y: 340, v: -84, ph: 2 }];
  ev(205.5, 'bird', { pan: .5 }); ev(210.5, 'bird', { pan: -.2 });
  return function draw(ctx, t) {
    const d = drift(t), z = ss(seg(t, 195, 219.5)), sunY = sun[1] + 70 - 130 * seg(t, 186, 219);
    const cam = { x: d.x - 90 * z, y: d.y - 30 * z, s: 1 + .1 * z };
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#e8c08a'; ctx.fillRect(0, 0, W, H);
    camAt(ctx, cam, 0); put(ctx, sky, -540, -220, { light: .95, shadow: false });
    glow(ctx, sun[0], sunY, 600, .32, '255,214,150');
    ctx.fillStyle = '#fffbf2'; ctx.beginPath(); ctx.arc(sun[0], sunY, 58, 0, 7); ctx.fill(); glow(ctx, sun[0], sunY, 120, .25, '255,236,200');
    camAt(ctx, cam, .08);
    for (const b of birds) { if (t < 189) continue; const bx = b.x0 + (t - 189) * b.v, by = b.y + Math.sin(t + b.ph) * 10, f = Math.sin(t * 6.5 + b.ph) * .5; ctx.save(); ctx.translate(bx, by); ctx.fillStyle = '#9a6a4c';
      ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(-14, -10 - f * 14, -30, -3 - f * 20); ctx.quadraticCurveTo(-14, -3, 0, 5); ctx.quadraticCurveTo(14, -3, 30, -3 - f * 20); ctx.quadraticCurveTo(14, -10 - f * 14, 0, 0); ctx.fill(); ctx.restore(); }
    camAt(ctx, cam, .15); put(ctx, seaF, -540, 540, { light: .9 });
    for (let i = 0; i < 6; i++) { const ww = 200 - i * 22 + Math.sin(t * 1.3 + i) * 26; ctx.fillStyle = 'rgba(255,246,222,.55)'; ctx.fillRect(sun[0] - ww / 2 + Math.sin(t + i) * 10, 578 + i * 16, ww, 4); }
    // the whale goes back to the deep
    const fu = seg(t, 186.5, 193.5);
    if (fu > 0 && fu < 1) { const rise = Math.sin(Math.PI * Math.min(1, fu * 1.4)); put(ctx, fluke, 400, 610 - rise * 120 + fu * 40, { px: 130, py: 160, rot: -.2 + fu * .4, light: .5, sd: [6, 8] }); }
    camAt(ctx, cam, .3); put(ctx, seaN, -540, 600, { light: .85 });
    for (let i = 0; i < 4; i++) { const yy = 660 + i * 18, xo = Math.sin(t * .6 + i * 1.7) * 60; ctx.fillStyle = 'rgba(255,240,214,.55)'; ctx.fillRect(-200 + xo + i * 90, yy, 2400, 3); }
    camAt(ctx, cam, .45); put(ctx, sandF, -540, 640, { light: .8 });
    camAt(ctx, cam, .62); put(ctx, dunes, -540, 680, { light: .7 });
    camAt(ctx, cam, .7);
    // shade on the sand, deepening as the leaves open
    const nOpen = leaves.reduce((a, l) => a + seg(t, l.t, l.t + .6), 0) / leaves.length;
    if (nOpen > 0) { ctx.save(); ctx.globalAlpha = .55 * nOpen; ctx.fillStyle = '#3a200f'; ctx.filter = 'blur(18px)'; ctx.beginPath(); ctx.ellipse(920, 830, 330, 46, 0, 0, 7); ctx.fill(); ctx.restore(); }
    // stem grows along its path
    const g = seg(t, GROW[0], GROW[1]);
    if (g > 0) {
      ctx.save(); ctx.strokeStyle = '#33531f'; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.lineWidth = 14;
      ctx.shadowColor = 'rgba(40,20,8,.45)'; ctx.shadowBlur = 12; ctx.shadowOffsetX = 8; ctx.shadowOffsetY = 12;
      const n = stem.length - 1, f = g * n; ctx.beginPath(); ctx.moveTo(stem[0][0], stem[0][1]);
      for (let i = 1; i <= n; i++) { if (i <= f) ctx.lineTo(stem[i][0], stem[i][1]); else { const k = f - (i - 1); ctx.lineTo(lerp(stem[i - 1][0], stem[i][0], k), lerp(stem[i - 1][1], stem[i][1], k)); break; } }
      ctx.stroke(); ctx.restore();
    }
    for (const l of leaves) { const u = seg(t, l.t, l.t + .7); if (u <= 0) continue; const s = l.s * back(u, 1.6); put(ctx, l.S, l.x, l.y, { px: 110, py: 190, sx: s, sy: s, rot: l.rot + Math.sin(t * .9 + l.u * 9) * .03, light: .9, sd: [10, 14], sa: .45 }); }
    for (const fl of flowers) { const u = seg(t, fl.t, fl.t + .6); if (u <= 0) continue; ctx.save(); ctx.translate(fl.x, fl.y); ctx.scale(back(u), back(u)); ctx.fillStyle = '#e9b949'; for (let k = 0; k < 5; k++) { ctx.rotate(Math.PI * 2 / 5); ctx.beginPath(); ctx.ellipse(0, -16, 9, 16, 0, 0, 7); ctx.fill(); } ctx.fillStyle = '#b07a20'; ctx.beginPath(); ctx.arc(0, 0, 6, 0, 7); ctx.fill(); ctx.restore(); glow(ctx, fl.x, fl.y, 60, .3 * u, '255,220,120'); }
    for (const [gx, gy, k] of [[830, 590, 209.6], [1085, 640, 211]]) { const u = ss(seg(t, k, k + 2.2)); if (u <= 0) continue; ctx.save(); ctx.translate(gx, gy); ctx.strokeStyle = '#33531f'; ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(0, -40); ctx.lineTo(0, 0); ctx.stroke(); ctx.fillStyle = '#a9b85a'; ctx.beginPath(); ctx.ellipse(0, 34 * u, 24 * u + 2, 40 * u + 2, 0, 0, 7); ctx.fill(); ctx.fillStyle = 'rgba(255,255,220,.25)'; ctx.beginPath(); ctx.ellipse(-8 * u, 26 * u, 6 * u, 18 * u, 0, 0, 7); ctx.fill(); ctx.restore(); }
    for (let i = 0; i < 2; i++) { const u = t - 206.5 - i * 1.2; if (u < 0) continue; const bx = 900 + Math.sin(u * 1.1 + i * 2) * 260, by = 520 + Math.sin(u * 1.7 + i) * 90 - Math.min(60, u * 10), f = Math.abs(Math.sin(t * 13 + i)); ctx.save(); ctx.translate(bx, by); ctx.fillStyle = i ? '#f2e2b0' : '#e9b949'; for (const sd of [-1, 1]) { ctx.beginPath(); ctx.ellipse(sd * 9 * f, -3, 11 * f + 1, 13, sd * .4, 0, 7); ctx.fill(); } ctx.restore(); }
    { const u = seg(t, 199.5, 211); if (u > 0 && u < 1) { const cx = lerp(1750, 1280, u) + Math.sin(t * 3) * 6; ctx.save(); ctx.translate(cx, 885); ctx.fillStyle = '#c8442e'; ctx.strokeStyle = '#c8442e'; ctx.lineWidth = 4; ctx.beginPath(); ctx.ellipse(0, 0, 24, 15, 0, 0, 7); ctx.fill(); for (let k = 0; k < 3; k++) for (const sd of [-1, 1]) { ctx.beginPath(); ctx.moveTo(sd * 16, 4); ctx.lineTo(sd * (30 + k * 5), 14 + Math.sin(t * 16 + k * 2 + sd) * 6); ctx.stroke(); } ctx.beginPath(); ctx.arc(-30, -14, 8, 0, 7); ctx.arc(30, -14, 8, 0, 7); ctx.fill(); ctx.restore(); } }
    camAt(ctx, cam, 1); put(ctx, front, -640, 760, { light: 0, sd: [12, 16], sa: .55 });
    ctx.setTransform(1, 0, 0, 1, 0, 0);
  };
}

// ---------------------------------------------------------------- opening: one hole of light in black paper
export function buildOpen() {
  ev(.6, 'spark', { v: .6 }); ev(1.4, 'paper', { v: .5 }); ev(6.4, 'paper', { v: .5 });
  return function draw(ctx, t) {
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#030202'; ctx.fillRect(0, 0, W, H);
    const r = t < .6 ? 0 : t < 1.4 ? 3 * seg(t, .6, 1.4) : 3 + 59 * eio(seg(t, 1.6, 6.2));
    if (r > 0) { glow(ctx, 1120, 300, 30 + r * 7, .55 * Math.min(1, r / 6), '255,226,170'); moon(ctx, 1120, 300, r, Math.min(1, r / 2)); }
  };
}

// ---------------------------------------------------------------- the box on the table (ending)
export function drawBox(ctx, img, t, k, lampOn) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = '#070504'; ctx.fillRect(0, 0, W, H);
  const bw = W * k, bh = H * k, bx = (W - bw) / 2, by = lerp(0, 470 - bh / 2, (1 - k) / .38);
  // table and spill light
  const ty = by + bh + 30;
  ctx.fillStyle = '#1c120b'; ctx.fillRect(0, ty, W, H - ty);
  ctx.fillStyle = 'rgba(255,200,130,.06)'; ctx.fillRect(0, ty, W, 2);
  glow(ctx, W / 2, ty + 40, bw * .7, .35 * lampOn * (1 - k) / .38, '255,180,100');
  glow(ctx, W / 2, by + bh / 2, bw * .9, .12 * lampOn * (1 - k) / .38, '255,180,100');
  // frame
  const f = 30;
  ctx.fillStyle = '#4a2f1c'; ctx.fillRect(bx - f, by - f, bw + f * 2, bh + f * 2);
  ctx.fillStyle = 'rgba(255,214,160,.18)'; ctx.fillRect(bx - f, by - f, bw + f * 2, 3);
  ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.fillRect(bx - f, by + bh + f - 4, bw + f * 2, 4);
  ctx.drawImage(img, bx, by, bw, bh);
  if (lampOn < 1) { ctx.fillStyle = `rgba(2,1,1,${.94 * (1 - lampOn)})`; ctx.fillRect(bx, by, bw, bh); }
  // black lining shadow inside the frame
  const g = ctx.createLinearGradient(bx, by, bx, by + 60); g.addColorStop(0, 'rgba(0,0,0,.6)'); g.addColorStop(1, 'rgba(0,0,0,0)'); ctx.fillStyle = g; ctx.fillRect(bx, by, bw, 60);
  return { bx, by, bw, bh, ty };
}
export { LAMP_OFF };
