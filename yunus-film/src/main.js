import { clamp, lerp, seg, ss, eio, eo } from '/core/lib.js';
import { W, H, cv, sheet, put, vignette, glow } from './paper.js';
import { DUR, SCENES, XF, CARDS, BEDS, LAMP_OFF } from './data.js';
import * as S from './scenes.js';

const canvas = document.getElementById('c'); canvas.width = W; canvas.height = H;
const ctx = canvas.getContext('2d');
const bufA = cv(W, H), bufB = cv(W, H), bufC = cv(W, H);
const AR = px => `${px}px "AmiriQ"`, FA = (px, w = 500) => `${w} ${px}px "Vaz"`;

let D = {}, band1, band2, band0;
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
  // sound events that belong to the text and the lamp
  CARDS.forEach(c => S.EV.push({ t: c.t0, type: 'strip', v: c.mode === 'dua' ? 0 : .35 }));
  S.EV.push({ t: LAMP_OFF, type: 'lampoff', v: 1 });
  BEDS.forEach(b => S.EV.push({ t: b.a, type: 'bed', id: b.id, a: b.a, b: b.b }));
  S.EV.sort((a, b) => a.t - b.t);
  window.EV = S.EV;
}

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
      const r = S.drawBox(c, bufC, t, k, (1 - off) * fl);
      D.boxTy = r.ty;
      return;
    }
  }
}

// ---------------------------------------------------------------- text cards
function shapeCard(c, card) {
  const L = { ...card };
  const m = card.mode || 'band';
  L.arPx = m === 'dua' ? 84 : m === 'center' ? 64 : m === 'room' ? 58 : 58;
  L.faPx = m === 'dua' ? 38 : m === 'band' && !card.ar ? 37 : 35;
  if (card.ar) { c.font = AR(L.arPx); while (c.measureText(card.ar).width > 1580 && L.arPx > 38) { L.arPx -= 2; c.font = AR(L.arPx); } L.arW = c.measureText(card.ar).width; }
  c.font = FA(L.faPx);
  L.fa1 = [card.fa];
  if (c.measureText(card.fa).width > 1560) { const w = card.fa.split(' '), mid = w.length / 2; let best = 1, bd = 1e9; let acc = ''; for (let i = 1; i < w.length; i++) { const a = c.measureText(w.slice(0, i).join(' ')).width, b = c.measureText(w.slice(i).join(' ')).width; if (Math.abs(a - b) < bd) { bd = Math.abs(a - b); best = i; } } L.fa1 = [w.slice(0, best).join(' '), w.slice(best).join(' ')]; }
  L.faW = Math.max(...L.fa1.map(s => c.measureText(s).width));
  L.revDur = card.reveal || clamp((card.ar || '').length * .05, 1.2, 2.6);
  return L;
}
let SHAPED;
function layoutCard(L, t) {
  const m = L.mode || 'band', A = [];
  let y0;
  if (m === 'band') { const by = L.ar ? (L.fa1.length > 1 ? 925 : 945) : 975; if (L.ar) { A.push(['ar', 960, by - (L.fa1.length > 1 ? 62 : 40)]); L.fa1.forEach((s, i) => A.push(['fa', 960, by + 44 + i * 50, s])); } else A.push(['fa', 960, by, L.fa1[0]]); A.band = by; }
  else if (m === 'room') { const ty = 835; A.push(['ar', 960, ty + 70]); L.fa1.forEach((s, i) => A.push(['fa', 960, ty + 140 + i * 48, s])); }
  else { const y = L.y || 520, dy = m === 'dua' ? 140 : 96; A.push(['ar', 960, y]); L.fa1.forEach((s, i) => A.push(['fa', 960, y + dy + i * 52, s])); A.ref = y + dy + L.fa1.length * 52 + 18; }
  return A;
}
function glowText(c, s, x, y, a, blur = 26) {
  c.globalAlpha = a; c.shadowColor = 'rgba(255,160,60,.95)'; c.shadowBlur = blur; c.fillStyle = '#ffcf7e'; c.fillText(s, x, y);
  c.shadowBlur = blur * .3; c.fillStyle = '#fff0cf'; c.fillText(s, x, y); c.shadowBlur = 0; c.globalAlpha = 1;
}
function drawCard(c, L, t) {
  if (t < L.t0 || t > L.t1) return;
  const m = L.mode || 'band', out = 1 - seg(t, L.t1 - .8, L.t1), A = layoutCard(L, t);
  c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.direction = 'rtl'; c.textAlign = 'center'; c.textBaseline = 'middle';
  if (m === 'band') {
    const S = !L.ar ? band0 : L.fa1.length > 1 ? band2 : band1, g = eo(seg(t, L.t0, L.t0 + .55));
    const right = 960 + 860;
    put(c, S, right, A.band - S.h / 2 + (L.ar ? 0 : 0), { px: 1720, py: 0, sx: Math.max(.001, g), alpha: .9 * out, sd: [10, 14], sa: .55 });
  }
  const t1 = L.t0 + .45, rev = eio(seg(t, t1, t1 + L.revDur));
  for (const it of A) {
    if (it[0] === 'ar' && L.ar) {
      c.font = AR(L.arPx);
      const x1 = it[1] + L.arW / 2 + 30, x0 = x1 - (L.arW + 60) * rev;
      c.save(); c.beginPath(); c.rect(x0, it[2] - 120, x1 - x0, 240); c.clip();
      glowText(c, L.ar, it[1], it[2], out, m === 'dua' ? 34 : 24);
      c.restore();
      if (m === 'dua' && rev > 0 && rev < 1) glow(c, x0, it[2], 180, .35, '255,190,100');
    } else if (it[0] === 'fa') {
      const fa0 = L.faAt != null ? L.t0 + L.faAt : !L.ar ? L.t0 + .3 : t1 + L.revDur * .55;
      const a = seg(t, fa0, fa0 + .7) * out; if (a <= 0) continue;
      c.font = FA(L.faPx); c.globalAlpha = a; c.shadowColor = 'rgba(0,0,0,.85)'; c.shadowBlur = 10; c.shadowOffsetY = 2;
      c.fillStyle = '#f3e9da'; c.fillText(it[3], it[1], it[2]); c.shadowBlur = 0; c.shadowOffsetY = 0; c.globalAlpha = 1;
    }
  }
  if (L.ref) {
    const a = seg(t, t1 + L.revDur * .6, t1 + L.revDur * .6 + .7) * out;
    c.font = FA(22, 400); c.globalAlpha = .78 * a; c.fillStyle = '#e8b870';
    if (m === 'band') { c.textAlign = 'left'; c.fillText(L.ref, 960 - 860 + 44, A.band - 40); }
    else if (m === 'room') { c.fillText(L.ref, 960, 835 + 140 + L.fa1.length * 48 + 6); }
    else c.fillText(L.ref, 960, A.ref);
    c.globalAlpha = 1;
  }
  c.restore();
}
function drawTitle(c, t) {
  if (t < 6.4 || t > 13.2) return;
  const out = 1 - seg(t, 12.2, 13.2), rev = eio(seg(t, 6.6, 8.6));
  c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.direction = 'rtl'; c.textAlign = 'center'; c.textBaseline = 'middle';
  c.font = FA(150, 800); const w = c.measureText('یونس').width;
  const x1 = 960 + w / 2 + 30, x0 = x1 - (w + 60) * rev;
  c.save(); c.beginPath(); c.rect(x0, 480, x1 - x0, 260); c.clip(); glowText(c, 'یونس', 960, 600, out, 40); c.restore();
  const a = seg(t, 8.8, 9.6) * out; c.font = FA(36, 400); c.globalAlpha = a; c.fillStyle = '#e9d6b8'; c.fillText('داستان ذوالنون در قرآن کریم', 960, 730); c.globalAlpha = 1;
  c.restore();
}

// ---------------------------------------------------------------- the frame
function active(t) { return SCENES.filter(s => t >= s.a && t < s.b); }
window.DUR = DUR;
window.render = (t) => {
  const act = active(t);
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  if (act.length === 1) { sceneDraw(act[0].id, ctx, t); }
  else if (act.length >= 2) {
    const [a, b] = act.slice(-2), key = `${a.id}>${b.id}`, xf = XF[key] || [b.a, a.b];
    const k = ss(seg(t, xf[0], xf[1]));
    const ca = bufA.getContext('2d'), cb = bufB.getContext('2d');
    sceneDraw(a.id, ca, t); sceneDraw(b.id, cb, t);
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(bufA, 0, 0); ctx.globalAlpha = k; ctx.drawImage(bufB, 0, 0); ctx.globalAlpha = 1;
  }
  if (t < 254) vignette(ctx, 1);
  drawTitle(ctx, t);
  for (const L of SHAPED) drawCard(ctx, L, t);
  const fin = seg(t, 271.2, 273.6); if (fin > 0) { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = `rgba(0,0,0,${fin})`; ctx.fillRect(0, 0, W, H); }
};
window.TEXTS = (t) => {
  const out = [];
  if (t >= 6.6 && t <= 12.2) out.push({ id: 'title', text: 'یونس — داستان ذوالنون در قرآن کریم', x0: 700, y0: 500, x1: 1220, y1: 760 });
  for (const L of SHAPED) {
    if (t < L.t0 + .45 || t > L.t1 - .8) continue;
    const A = layoutCard(L, t);
    for (const it of A) {
      if (it[0] === 'ar' && L.ar) out.push({ id: L.id + '-ar', text: L.ar, x0: 960 - L.arW / 2, y0: it[2] - 50, x1: 960 + L.arW / 2, y1: it[2] + 50 });
      if (it[0] === 'fa') { const fa0 = L.faAt != null ? L.t0 + L.faAt : !L.ar ? L.t0 + .3 : L.t0 + .45 + L.revDur * .55; if (t >= fa0) out.push({ id: L.id + '-fa-' + A.indexOf(it), text: it[3], x0: 960 - L.faW / 2, y0: it[2] - 24, x1: 960 + L.faW / 2, y1: it[2] + 24 }); }
    }
  }
  return out;
};

(async () => {
  await Promise.all([document.fonts.load('60px "AmiriQ"', 'يونس'), document.fonts.load('500 36px "Vaz"', 'یونس'), document.fonts.load('800 150px "Vaz"', 'یونس'), document.fonts.load('400 22px "Vaz"', 'یونس')]);
  build();
  SHAPED = CARDS.map(c => shapeCard(ctx, c));
  window.render(0);
  window.READY = true;
})();
