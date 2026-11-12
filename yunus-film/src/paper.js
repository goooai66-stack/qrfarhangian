// Paper-cut lightbox toolkit in Canvas2D: lit paper sheets, cast shadows, glow sprites.
import { mulberry, clamp } from '/core/lib.js';

export const W = 1920, H = 1080;
export function cv(w, h) { const c = document.createElement('canvas'); c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h)); return c; }

// ---- shared textures -------------------------------------------------------
let _grain, _mottle;
export function grainTex() {
  if (_grain) return _grain;
  const n = 512, c = cv(n, n), x = c.getContext('2d'), id = x.createImageData(n, n), r = mulberry(11);
  for (let i = 0; i < id.data.length; i += 4) { const g = 128 + (r() - .5) * 70; id.data[i] = id.data[i + 1] = id.data[i + 2] = g; id.data[i + 3] = 255; }
  x.putImageData(id, 0, 0);
  // paper fibres
  x.lineCap = 'round';
  for (let i = 0; i < 900; i++) {
    const px = r() * n, py = r() * n, a = r() * Math.PI, l = 6 + r() * 22;
    x.strokeStyle = r() < .5 ? 'rgba(255,255,255,.22)' : 'rgba(0,0,0,.18)'; x.lineWidth = .6 + r() * .9;
    x.beginPath(); x.moveTo(px, py); x.quadraticCurveTo(px + Math.cos(a) * l * .5 + (r() - .5) * 4, py + Math.sin(a) * l * .5 + (r() - .5) * 4, px + Math.cos(a) * l, py + Math.sin(a) * l); x.stroke();
  }
  return (_grain = c);
}
export function mottleTex() {
  if (_mottle) return _mottle;
  const s = cv(24, 14), sx = s.getContext('2d'), id = sx.createImageData(24, 14), r = mulberry(23);
  for (let i = 0; i < id.data.length; i += 4) { const g = 150 + r() * 105; id.data[i] = id.data[i + 1] = id.data[i + 2] = g; id.data[i + 3] = 255; }
  sx.putImageData(id, 0, 0);
  const c = cv(W, H), x = c.getContext('2d'); x.imageSmoothingQuality = 'high'; x.filter = 'blur(30px)'; x.drawImage(s, -80, -80, W + 160, H + 160);
  return (_mottle = c);
}

// glow sprite: soft radial blob, cached by colour
const _glow = {};
export function glowSprite(col = '255,190,110') {
  if (_glow[col]) return _glow[col];
  const n = 256, c = cv(n, n), x = c.getContext('2d'), g = x.createRadialGradient(n / 2, n / 2, 0, n / 2, n / 2, n / 2);
  g.addColorStop(0, `rgba(${col},1)`); g.addColorStop(.25, `rgba(${col},.45)`); g.addColorStop(.6, `rgba(${col},.1)`); g.addColorStop(1, `rgba(${col},0)`);
  x.fillStyle = g; x.fillRect(0, 0, n, n); return (_glow[col] = c);
}
export function glow(ctx, x, y, r, a = 1, col) {
  if (a <= 0.002) return;
  ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = clamp(a, 0, 1);
  ctx.drawImage(glowSprite(col), x - r, y - r, r * 2, r * 2); ctx.restore();
}

// ---- a lit paper sheet -----------------------------------------------------
// draw(x) paints the shape in layer-local pixels with the sheet colour already set as fillStyle/strokeStyle.
// Cut-outs: x.globalCompositeOperation = 'destination-out' after painting opaque.
export function sheet(w, h, color, draw, o = {}) {
  const pad = o.pad ?? 0;
  const base = cv(w, h), b = base.getContext('2d');
  b.fillStyle = color; b.strokeStyle = color; b.lineJoin = 'round'; b.lineCap = 'round';
  draw(b, w, h);
  b.globalCompositeOperation = 'source-over';
  // fibre grain (overlay, masked)
  const t = cv(w, h), tx = t.getContext('2d');
  tx.fillStyle = tx.createPattern(grainTex(), 'repeat'); tx.fillRect(0, 0, w, h);
  tx.globalCompositeOperation = 'destination-in'; tx.drawImage(base, 0, 0);
  b.save(); b.globalCompositeOperation = 'overlay'; b.globalAlpha = o.grain ?? .35; b.drawImage(t, 0, 0); b.restore();
  // edge light: warm rim on top edges, dark band on bottom edges
  const edge = (col, dy, alpha, blur) => {
    const e = cv(w, h), ex = e.getContext('2d');
    ex.drawImage(base, 0, 0); ex.globalCompositeOperation = 'source-in'; ex.fillStyle = col; ex.fillRect(0, 0, w, h);
    ex.globalCompositeOperation = 'destination-out'; ex.drawImage(base, 0, dy);
    b.save(); b.globalCompositeOperation = 'source-atop'; b.globalAlpha = alpha; b.filter = `blur(${blur}px)`; b.drawImage(e, 0, 0); b.restore();
  };
  if ((o.rim ?? .5) > 0) edge(o.rimCol || '#ffd9a0', o.rimW ?? 3, o.rim ?? .5, 1);
  if ((o.shade ?? .45) > 0) edge('#000', -(o.shadeW ?? 5), o.shade ?? .45, 2);
  // backlit version: light through the paper, strongest at the light point, cloudy pulp
  let lit = null;
  if ((o.trans ?? 0) > 0) {
    const L = o.light || [w / 2, h * .3, Math.max(w, h) * .7];
    const g = cv(w, h), gx = g.getContext('2d');
    const rg = gx.createRadialGradient(L[0], L[1], 0, L[0], L[1], L[2]);
    const lc = o.lightCol || '255,196,120';
    rg.addColorStop(0, `rgba(${lc},1)`); rg.addColorStop(.45, `rgba(${lc},.55)`); rg.addColorStop(1, `rgba(${lc},.08)`);
    gx.fillStyle = rg; gx.fillRect(0, 0, w, h);
    gx.globalCompositeOperation = 'multiply'; gx.drawImage(mottleTex(), 0, 0, w, h);
    gx.globalCompositeOperation = 'destination-in'; gx.drawImage(base, 0, 0);
    lit = cv(w, h); const lx = lit.getContext('2d'); lx.drawImage(base, 0, 0);
    lx.globalCompositeOperation = 'lighter'; lx.globalAlpha = o.trans; lx.drawImage(g, 0, 0);
  }
  // cast shadow (soft, dark)
  let shadow = null;
  if (o.shadow !== false) {
    const sb = o.shadowBlur ?? 14, P = sb * 3;
    shadow = cv(w + P * 2, h + P * 2); const sx = shadow.getContext('2d');
    const m = cv(w, h), mx = m.getContext('2d'); mx.drawImage(base, 0, 0); mx.globalCompositeOperation = 'source-in'; mx.fillStyle = '#000'; mx.fillRect(0, 0, w, h);
    sx.filter = `blur(${sb}px)`; sx.drawImage(m, P, P); shadow.P = P;
  }
  return { base, lit, shadow, w, h, pad };
}

// draw a sheet. (x,y) = where the pivot lands; pivot (px,py) in local px (default top-left).
export function put(ctx, S, x, y, o = {}) {
  const a = o.alpha ?? 1; if (a <= 0.002) return;
  const px = o.px ?? 0, py = o.py ?? 0, sx = o.sx ?? 1, sy = o.sy ?? 1, rot = o.rot ?? 0;
  ctx.save(); ctx.translate(x, y); if (rot) ctx.rotate(rot); if (sx !== 1 || sy !== 1) ctx.scale(sx, sy);
  if (S.shadow && o.shadow !== false) {
    const d = o.sd ?? [10, 14];
    ctx.globalAlpha = a * (o.sa ?? .5);
    ctx.drawImage(S.shadow, -px - S.shadow.P + d[0], -py - S.shadow.P + d[1]);
  }
  ctx.globalAlpha = a;
  const L = o.light ?? 0;
  if (S.lit && L >= .999) ctx.drawImage(S.lit, -px, -py);
  else {
    ctx.drawImage(S.base, -px, -py);
    if (S.lit && L > 0.002) { ctx.globalAlpha = a * L; ctx.drawImage(S.lit, -px, -py); }
  }
  ctx.restore();
}

// camera: a parallax transform for a layer at depth p (0 = sky, 1 = front)
export function camAt(ctx, cam, p) {
  const s = 1 + (cam.s - 1) * (0.35 + 0.65 * p);
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.translate(W / 2, H / 2); if (cam.r) ctx.rotate(cam.r * (.5 + .5 * p)); ctx.scale(s, s);
  ctx.translate(-W / 2 - cam.x * (.25 + .75 * p), -H / 2 - cam.y * (.25 + .75 * p));
}

// vignette overlay
let _vig;
export function vignette(ctx, a = 1) {
  if (!_vig) {
    _vig = cv(W, H); const x = _vig.getContext('2d');
    const g = x.createRadialGradient(W / 2, H / 2, H * .35, W / 2, H / 2, H * 1.05);
    g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,.62)'); x.fillStyle = g; x.fillRect(0, 0, W, H);
  }
  ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = a; ctx.drawImage(_vig, 0, 0); ctx.restore();
}

// shape helpers
export function poly(x, pts) { x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) x.lineTo(pts[i][0], pts[i][1]); x.closePath(); x.fill(); }
export function ridge(x, w, h, base, amp, seed, step = 30, rough = .5) {
  const r = mulberry(seed); x.beginPath(); x.moveTo(0, h); x.lineTo(0, base);
  let v = 0; for (let i = 0; i <= w + step; i += step) { v = v * rough + (r() - .5) * 2 * (1 - rough); const y = base - amp * (.5 + .5 * Math.sin(i / w * 6.28 * 1.3 + seed) * .6 + v * .5); x.lineTo(i, y); }
  x.lineTo(w, h); x.closePath(); x.fill();
}
export function cutWith(x, fn) { x.save(); x.globalCompositeOperation = 'destination-out'; x.fillStyle = '#000'; x.strokeStyle = '#000'; fn(x); x.restore(); }
