import { clamp, lerp, seg, ss, eio, eo, hash } from '/core/lib.js';
import { W, H, cv, sheet, put, vignette, glow, SHOT } from './paper.js';
import { DUR, SCENES, XF, CARDS, BEDS, LAMP_OFF, toOld, toNew } from './data.js';
import * as S from './scenes.js';

const canvas = document.getElementById('c'); canvas.width = W; canvas.height = H;
const ctx = canvas.getContext('2d');
const bufA = cv(W, H), bufB = cv(W, H), bufC = cv(W, H);
const AR = px => `${px}px "AmiriQ"`, FA = (px, w = 500) => `${w} ${px}px "Vaz"`;

// Shot cuts, in screen time: [t, zoom, x, y, push?]. A new framing about every 3 s; each shot keeps pushing in slowly.
const SHOTS = [[0, 1, 0, 0, 0], [5.2, 1, 0, 0], [8.5, 1.35, -250, -60], [11.6, 1.12, 120, -110], [15, 1.4, 260, 40], [18.7, 1.15, -150, 0], [21.8, 1.45, 60, -50], [25, 1, 0, 0], [28.2, 1.2, 200, 60],
  [31.3, 1, 0, 0], [34, 1.4, 160, 90], [37, 1.2, -250, -80], [40, 1.1, 60, 0],
  [43.3, 1, 0, 0], [46, 1.35, 150, 110], [49, 1.2, -200, -110], [52, 1.45, 170, 150], [55, 1.1, 0, 0],
  [57.5, 1, 0, 0], [61, 1.25, 0, -50], [64.5, 1.45, 270, -60],
  [68, 1, 0, 0, 0],
  [117.1, 1, 0, 0], [120.4, 1.3, 150, -100], [123.9, 1.12, 250, -150],
  [127.9, 1, 0, 0], [131.4, 1.3, -420, 60], [134.4, 1.25, -60, 90], [137.4, 1.5, -40, -10], [140.4, 1.15, 300, -40], [143.4, 1.3, -40, 0],
  [146.9, 1, 0, 0], [149.9, 1.3, -200, -150], [152.9, 1.15, 200, 0], [155.5, 1, 0, 0], [158.4, 1.35, 150, -160], [161.9, 1.1, 0, 0], [165.7, 1.4, -200, 60], [168.4, 1.4, 250, 80], [171.5, 1, 0, 0], [175.1, 1, 0, 0, 0]];
function setShot(n) {
  let k = 0; while (k + 1 < SHOTS.length && SHOTS[k + 1][0] <= n) k++;
  const [t0, s, x, y, push = 1] = SHOTS[k];
  SHOT.s = s * (1 + (push ? .012 * Math.min(6, n - t0) : 0)); SHOT.x = x; SHOT.y = y;
}

let D = {}, band1, band2, band0, SHAPED;
function build() {
  D.open = S.buildOpen();
  D.cityDraw = S.buildCity();
  D.harbour = S.buildHarbour();
  D.storm = S.buildStorm();
  D.lots = S.buildLots();
  D.dive = S.buildDive(D.storm);
  D.dark = S.buildDark();
  D.rise = S.buildRise();
  D.shore = S.buildShore();
  const strip = h => sheet(1720, h, '#0b0705', (x, w, hh) => { x.beginPath(); x.roundRect(0, 0, w, hh, 10); x.fill(); }, { trans: 0, rim: .45, rimCol: '#ffcf8a', shadowBlur: 18 });
  band0 = strip(150); band1 = strip(232); band2 = strip(286);
  SHAPED = CARDS.map(c => shapeCard(ctx, c));
  // scene events are in story time: move them to screen time, then add the text and lamp events
  S.EV.forEach(e => { e.t = +toNew(e.t).toFixed(3); });
  SHAPED.forEach(L => {
    S.EV.push({ t: L.t0, type: 'strip', v: L.mode === 'dua' ? 0 : .35 });
    if (L.mode === 'dua') L.words.forEach((w, i) => S.EV.push({ t: +(L.t0 + .45 + i * L.step).toFixed(3), type: 'cut', v: 1, pan: .5 - i / L.words.length }));
  });
  S.EV.push({ t: L_end('dua'), type: 'chime', v: .6 });
  S.EV.push({ t: toNew(LAMP_OFF), type: 'lampoff', v: 1 });
  BEDS.forEach(b => S.EV.push({ t: toNew(b.a), type: 'bed', id: b.id, a: toNew(b.a), b: toNew(b.b) }));
  S.EV.sort((a, b) => a.t - b.t);
  window.EV = S.EV;
}
const L_end = id => { const L = SHAPED.find(c => c.id === id); return +(L.t0 + .45 + L.words.length * L.step).toFixed(3); };

function sceneDraw(id, c, t) {
  switch (id) {
    case 'open': return D.open(c, t);
    case 'city': return D.cityDraw(c, t, { mode: 'city', cam: { x: 520 * eio(seg(t, 37.5, 45)), y: 0, s: 1 + .06 * ss(seg(t, 13, 37)) } });
    case 'harbour': return D.harbour(c, t);
    case 'storm': return D.storm(c, t);
    case 'lots': return D.lots(c, t);
    case 'dive': return D.dive(c, t);
    case 'dark': return D.dark(c, t);
    case 'rise': return D.rise(c, t);
    case 'shore': return D.shore(c, t);
    case 'return': {
      const o = { mode: 'return', cloud: ss(seg(t, 232, 240.5)), cam: { x: 0, y: 0, s: 1.08 - .08 * ss(seg(t, 219, 256)) }, lightK: .72 + .28 * seg(t, 232, 241), moonA: seg(t, 233.5, 241), starA: seg(t, 234, 242) };
      if (t < 254) return D.cityDraw(c, t, o);
      const bc = bufC.getContext('2d'); D.cityDraw(bc, t, o); vignette(bc, .6);
      const k = lerp(1, .62, eio(seg(t, 254, 261.5)));
      const off = seg(t, LAMP_OFF, LAMP_OFF + .18), fl = t > LAMP_OFF - .5 && t < LAMP_OFF ? (Math.sin(t * 60) > .3 ? .85 : 1) : 1;
      S.drawBox(c, bufC, t, k, (1 - off) * fl);
      return;
    }
  }
}

// ---------------------------------------------------------------- text cards (screen time)
function shapeCard(c, card) {
  const L = { ...card }, m = card.mode || 'band';
  L.arPx = m === 'dua' ? 84 : m === 'center' ? 64 : 58;
  L.faPx = m === 'dua' ? 38 : m === 'band' && !card.ar ? 37 : 35;
  L.words = [];
  if (card.ar) {
    c.font = AR(L.arPx); while (c.measureText(card.ar).width > 1580 && L.arPx > 38) { L.arPx -= 2; c.font = AR(L.arPx); }
    L.arW = c.measureText(card.ar).width; L.words = card.ar.split(' ');
    L.wx = L.words.map((w, i) => i ? c.measureText(L.words.slice(0, i).join(' ') + ' ').width : 0); L.ww = L.words.map(w => c.measureText(w).width);
  }
  c.font = FA(L.faPx);
  L.fa1 = [card.fa];
  if (c.measureText(card.fa).width > 1560) { const w = card.fa.split(' '); let best = 1, bd = 1e9; for (let i = 1; i < w.length; i++) { const a = c.measureText(w.slice(0, i).join(' ')).width, b = c.measureText(w.slice(i).join(' ')).width; if (Math.abs(a - b) < bd) { bd = Math.abs(a - b); best = i; } } L.fa1 = [w.slice(0, best).join(' '), w.slice(best).join(' ')]; }
  L.faW = Math.max(...L.fa1.map(s => c.measureText(s).width));
  L.step = card.step || clamp(2.4 / (L.words.length || 1), .16, .36);
  L.revDur = L.words.length * L.step + .3;
  L.fa0 = card.faAt != null ? card.t0 + card.faAt : !card.ar ? card.t0 + .3 : card.t0 + .45 + L.revDur * .55;
  return L;
}
function layoutCard(L) {
  const m = L.mode || 'band', A = [];
  if (m === 'band') { const by = L.ar ? (L.fa1.length > 1 ? 925 : 945) : 975; if (L.ar) { A.push(['ar', 960, by - (L.fa1.length > 1 ? 62 : 40)]); L.fa1.forEach((s, i) => A.push(['fa', 960, by + 44 + i * 50, s])); } else A.push(['fa', 960, by, L.fa1[0]]); A.band = by; }
  else if (m === 'room') { A.push(['ar', 960, 905]); L.fa1.forEach((s, i) => A.push(['fa', 960, 975 + i * 48, s])); }
  else { const y = L.y || 520, dy = m === 'dua' ? 140 : 96; A.push(['ar', 960, y]); L.fa1.forEach((s, i) => A.push(['fa', 960, y + dy + i * 52, s])); A.ref = y + dy + L.fa1.length * 52 + 18; }
  return A;
}
function glowText(c, s, x, y, a, blur = 26) {
  c.globalAlpha = a; c.shadowColor = 'rgba(255,160,60,.95)'; c.shadowBlur = blur; c.fillStyle = '#ffcf7e'; c.fillText(s, x, y);
  c.shadowBlur = blur * .3; c.fillStyle = '#fff0cf'; c.fillText(s, x, y); c.shadowBlur = 0; c.globalAlpha = 1;
}
function drawCard(c, L, t) {
  if (t < L.t0 || t > L.t1) return;
  const m = L.mode || 'band', out = 1 - seg(t, L.t1 - .8, L.t1), A = layoutCard(L);
  c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.direction = 'rtl'; c.textAlign = 'center'; c.textBaseline = 'middle';
  if (m === 'band') {
    const B = !L.ar ? band0 : L.fa1.length > 1 ? band2 : band1, g = eo(seg(t, L.t0, L.t0 + .4));
    put(c, B, 960 + 860, A.band - B.h / 2, { px: 1720, py: 0, sx: Math.max(.001, g), alpha: .9 * out, sd: [10, 14], sa: .55 });
  }
  const t1 = L.t0 + .45;
  for (const it of A) {
    if (it[0] === 'ar' && L.ar) {
      c.font = AR(L.arPx);
      const xr = it[1] + L.arW / 2;
      // the verse arrives word by word, right to left; each word pops in with its own light
      L.words.forEach((w, i) => {
        const tw = t1 + i * L.step, u = seg(t, tw, tw + .28); if (u <= 0) return;
        const cx = xr - L.wx[i] - L.ww[i] / 2, sc = 1 + .22 * (1 - eo(u));
        if (m === 'dua') {
          if (u < 1) glow(c, cx, it[2], 240, .45 * (1 - u), '255,190,100');
          for (let j = 0; j < 4; j++) { const life = 3.2, a = ((t - tw) + j * .8) % life, k = a / life; if (t - tw < j * .25) continue; const mx = cx + (hash(i * 7 + j) - .5) * L.ww[i] + Math.sin(a * 1.7 + j) * 14, my = it[2] - 30 - k * 190; glow(c, mx, my, 16 + 10 * hash(i + j * 3), .75 * Math.sin(Math.PI * k) * out, '255,214,140'); }
        }
        c.save(); c.translate(cx, it[2]); c.scale(sc, sc); glowText(c, w, 0, 0, out * u, m === 'dua' ? 34 : 24); c.restore();
      });
    } else if (it[0] === 'fa') {
      const a = seg(t, L.fa0, L.fa0 + .5) * out; if (a <= 0) continue;
      c.font = FA(L.faPx); c.globalAlpha = a; c.shadowColor = 'rgba(0,0,0,.85)'; c.shadowBlur = 10; c.shadowOffsetY = 2;
      c.fillStyle = '#f3e9da'; c.fillText(it[3], it[1], it[2] + 10 * (1 - eo(seg(t, L.fa0, L.fa0 + .5)))); c.shadowBlur = 0; c.shadowOffsetY = 0; c.globalAlpha = 1;
    }
  }
  if (L.ref) {
    const a = seg(t, t1 + L.revDur * .6, t1 + L.revDur * .6 + .5) * out;
    c.font = FA(22, 400); c.globalAlpha = .78 * a; c.fillStyle = '#e8b870';
    if (m === 'band') { c.textAlign = 'left'; c.fillText(L.ref, 960 - 860 + 44, A.band - 40); }
    else if (m === 'room') c.fillText(L.ref, 960, 975 + L.fa1.length * 48 + 6);
    else c.fillText(L.ref, 960, A.ref);
    c.globalAlpha = 1;
  }
  c.restore();
}
function drawTitle(c, t) {
  if (t < 1.2 || t > 5.6) return;
  const out = 1 - seg(t, 5.0, 5.6), rev = eo(seg(t, 1.3, 2.0));
  c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.direction = 'rtl'; c.textAlign = 'center'; c.textBaseline = 'middle';
  c.font = FA(150, 800); const w = c.measureText('یونس').width;
  const x1 = 960 + w / 2 + 30, x0 = x1 - (w + 60) * rev;
  c.save(); c.beginPath(); c.rect(x0, 480, x1 - x0, 260); c.clip(); glowText(c, 'یونس', 960, 600, out, 40); c.restore();
  const a = seg(t, 1.9, 2.4) * out; c.font = FA(36, 400); c.globalAlpha = a; c.shadowColor = 'rgba(0,0,0,.9)'; c.shadowBlur = 12; c.fillStyle = '#e9d6b8'; c.fillText('داستان ذوالنون در قرآن کریم', 960, 730); c.globalAlpha = 1;
  c.restore();
}

// ---------------------------------------------------------------- the frame
const active = tau => SCENES.filter(s => tau >= s.a && tau < s.b);
window.DUR = DUR;
window.render = (n) => {
  const t = toOld(n), act = active(t);
  setShot(n);
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  if (act.length === 1) sceneDraw(act[0].id, ctx, t);
  else if (act.length >= 2) {
    const [a, b] = act.slice(-2), xf = XF[`${a.id}>${b.id}`] || [b.a, a.b], k = ss(seg(t, xf[0], xf[1]));
    sceneDraw(a.id, bufA.getContext('2d'), t); sceneDraw(b.id, bufB.getContext('2d'), t);
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(bufA, 0, 0); ctx.globalAlpha = k; ctx.drawImage(bufB, 0, 0); ctx.globalAlpha = 1;
  }
  if (t < 254) vignette(ctx, 1);
  drawTitle(ctx, n);
  for (const L of SHAPED) drawCard(ctx, L, n);
  const fin = seg(t, 271.2, 273.6); if (fin > 0) { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = `rgba(0,0,0,${fin})`; ctx.fillRect(0, 0, W, H); }
};
window.TEXTS = (t) => {
  const out = [];
  if (t >= 2.0 && t <= 5.0) out.push({ id: 'title', text: 'یونس', x0: 700, y0: 500, x1: 1220, y1: 760 });
  for (const L of SHAPED) {
    if (t < L.t0 + .45 || t > L.t1 - .8) continue;
    const A = layoutCard(L);
    for (const it of A) {
      if (it[0] === 'ar' && L.ar) out.push({ id: L.id + '-ar', text: L.ar, x0: 960 - L.arW / 2, y0: it[2] - 50, x1: 960 + L.arW / 2, y1: it[2] + 50 });
      if (it[0] === 'fa' && t >= L.fa0) out.push({ id: L.id + '-fa-' + A.indexOf(it), text: it[3], x0: 960 - L.faW / 2, y0: it[2] - 24, x1: 960 + L.faW / 2, y1: it[2] + 24 });
    }
  }
  return out;
};

(async () => {
  await Promise.all([document.fonts.load('60px "AmiriQ"', 'يونس'), document.fonts.load('500 36px "Vaz"', 'یونس'), document.fonts.load('800 150px "Vaz"', 'یونس'), document.fonts.load('400 22px "Vaz"', 'یونس')]);
  build();
  window.render(0);
  window.READY = true;
})();
