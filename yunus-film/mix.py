"""Sound for the film: nature beds + paper/light foley, driven by events.json (exported from the page). No music, no voice."""
import json, sys, os
import numpy as np
import soundfile as sf
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.environ.get('LIB', os.path.expanduser('~/lemo-opuscar')), 'core', 'audio'))
from sfx import SR, t_, env_exp, bp, lp, hp, noise, norm, brown, creak, whoosh, thump, roar, ding, pop, add, limit

E = json.load(open(os.path.join(HERE, 'events.json')))
DUR = E['dur']; EV = E['ev']
N = int(DUR * SR) + SR
buf = np.zeros((N, 2), np.float32)
rng = np.random.default_rng(3)

def fade(x, a=1.5, b=1.5):
    n = len(x); fa, fb = min(n // 2, int(a * SR)), min(n // 2, int(b * SR))
    x[:fa] *= np.linspace(0, 1, fa) ** 1.5; x[n - fb:] *= np.linspace(1, 0, fb) ** 1.5; return x
def lfo(d, f, depth, ph=0.0): return 1 - depth + depth * (.5 + .5 * np.sin(2 * np.pi * f * t_(d) + ph))
def slow_noise(d, rate=.5, seed=0):
    r = np.random.default_rng(seed); k = max(4, int(d * rate) + 3); pts = r.random(k)
    return np.interp(t_(d), np.linspace(0, d, k), pts)
def stereo(l, r): return np.stack([l, r], 1)
def put(x, at, g=1.0, pan=0.0):
    if x.ndim == 2:
        s = int(at * SR); e = min(N, s + len(x)); buf[s:e] += x[:e - s] * g
    else: add(buf, x, at, g, pan)

# ---------------------------------------------------------------- beds
def wind(d, cut=500, gust=.15, seed=1):
    return lp(brown(d), cut) * (.4 + .6 * slow_noise(d, gust, seed))
def crickets(d, seed=0):
    r = np.random.default_rng(seed); out = np.zeros(int(d * SR)); tt = t_(.12)
    chirp = np.sin(2 * np.pi * 4700 * tt) * (np.sin(2 * np.pi * 30 * tt) > 0) * np.sin(np.pi * tt / .12)
    pos = 0.0
    while pos < d - .2:
        s = int(pos * SR); out[s:s + len(chirp)] += chirp * (.5 + .5 * r.random()); pos += .45 + r.random() * .5
    return out
def surf(d, period=6.0, seed=2, cut=1400):
    r = np.random.default_rng(seed); tt = t_(d); env = np.zeros_like(tt); p = r.random() * 2
    while p < d:
        L = period * (.7 + .5 * r.random()); m = (tt >= p) & (tt < p + L); u = (tt[m] - p) / L
        env[m] += np.sin(np.pi * u ** .6) ** 2; p += L * (.75 + .3 * r.random())
    return lp(noise(d), cut) * (.15 + env) + hp(noise(d), 3000) * env * .25
def bubbles(d, rate=3.0, seed=5, bright=1.0):
    r = np.random.default_rng(seed); out = np.zeros(int(d * SR)); n = int(d * rate)
    for _ in range(n):
        at = r.random() * (d - .1); dd = .04 + r.random() * .05; tt = t_(dd); f = (500 + r.random() * 900) * bright
        b = np.sin(2 * np.pi * np.cumsum(f * (1 + 2.5 * tt / dd)) / SR) * env_exp(dd, dd / 3)
        s = int(at * SR); out[s:s + len(b)] += b * (.3 + .7 * r.random())
    return out

def bed(id, d):
    d = int(d * SR) / SR
    if id == 'room': return stereo(*(lp(brown(d), 300) * .012 for _ in range(2)))
    if id == 'night':
        w = wind(d, 450, .12, 1) * .07; c1, c2 = crickets(d, 1) * .018, crickets(d, 2) * .014
        river = bp(noise(d), 250, 1300) * .03 * lfo(d, .13, .4)
        return stereo(w + c1 + river, w * .9 + c2 + bp(noise(d), 250, 1300) * .03)
    if id == 'harbour':
        s1, s2 = surf(d, 5.0, 3, 1300) * .09, surf(d, 5.5, 4, 1300) * .09; w = wind(d, 700, .2, 3) * .05
        return stereo(s1 + w, s2 + w)
    if id == 'storm':
        g = .35 + .65 * slow_noise(d, .35, 9)
        wl = bp(brown(d) + noise(d) * .05, 200, 1600) * g * .2; wr = bp(brown(d) + noise(d) * .05, 200, 1600) * g * .2
        rain = hp(noise(d), 1800) * .055 + bp(noise(d), 500, 2000) * .03
        sea = lp(brown(d), 180) * .22 * (.5 + .5 * slow_noise(d, .25, 11))
        ramp = np.minimum(1, t_(d) / 4)
        return stereo((wl + rain + sea) * ramp, (wr + hp(noise(d), 1800) * .055 + sea) * ramp)
    if id in ('under', 'rise'):
        lo = lp(brown(d), 260 if id == 'under' else 600) * (.3 if id == 'under' else .2)
        b = bubbles(d, 3 if id == 'under' else 9, 7 if id == 'under' else 8, 1 if id == 'under' else 1.4) * .05
        b = lp(b, 1800 if id == 'under' else 4000)
        return stereo(lo + b, lo + np.roll(b, 2400))
    if id in ('belly', 'belly2'):
        tt = t_(d); br = .5 + .5 * np.sin(2 * np.pi * .23 * tt) ** 2
        x = (np.sin(2 * np.pi * 41 * tt) * .5 + np.sin(2 * np.pi * 62 * tt + 1) * .25) * br * .12 + lp(brown(d), 120) * .18
        if id == 'belly2': x *= .6 + .4 * np.minimum(1, tt / 8)
        return stereo(x, x)
    if id == 'shore':
        s1, s2 = surf(d, 7.0, 5, 1100) * .08, surf(d, 7.5, 6, 1100) * .08; w = wind(d, 900, .15, 7) * .035
        return stereo(s1 + w, s2 + w)
    if id == 'evening':
        w = wind(d, 500, .12, 12) * .06; c1, c2 = crickets(d, 4) * .016, crickets(d, 5) * .013
        return stereo(w + c1, w + c2)
    raise ValueError(id)

for e in EV:
    if e['type'] != 'bed': continue
    d = e['b'] - e['a']; x = bed(e['id'], d)
    fa = .5 if e['id'] in ('under',) else 1.5; fb = .08 if e['id'] in ('under', 'evening') else 1.2
    if e['id'] == 'belly': fb = 1.8
    x = np.stack([fade(x[:, 0].copy(), fa, fb), fade(x[:, 1].copy(), fa, fb)], 1)
    put(x, e['a'])

# ---------------------------------------------------------------- foley
def tap(v):  # paper card tapping into place
    d = .09; return norm(bp(noise(d), 700, 3500) * env_exp(d, .01) + np.sin(2 * np.pi * 420 * t_(d)) * env_exp(d, .02) * .4) * v
def rustle(d=.35, v=1.0):
    n = bp(noise(d), 1500, 7000) * (np.random.default_rng(int(d * 1e4)).random(int(d * SR)) > .6)
    return norm(lp(n, 8000) * np.sin(np.pi * t_(d) / d) ** 2) * v
def gull(v):
    out = []
    for k in range(3):
        d = .28 + .05 * k; tt = t_(d); f = 1900 - 700 * (tt / d) ** .7
        ph = np.cumsum(f) / SR * 2 * np.pi; x = (np.sin(ph) + .5 * np.sin(2 * ph) + .25 * np.sin(3 * ph)) * np.sin(np.pi * tt / d) ** .7
        out.append(np.concatenate([x, np.zeros(int(.12 * SR))]))
    return norm(bp(np.concatenate(out), 900, 6000)) * v
def songbird(v):
    r = np.random.default_rng(int(v * 100)); parts = []
    for _ in range(5):
        d = .06 + r.random() * .06; tt = t_(d); f = 3200 + 1800 * r.random() + 1400 * np.sin(np.pi * tt / d)
        parts.append(np.sin(np.cumsum(f) / SR * 2 * np.pi) * np.sin(np.pi * tt / d)); parts.append(np.zeros(int((.04 + r.random() * .08) * SR)))
    return norm(np.concatenate(parts)) * v
def thunder(v):
    d = 4.5; crack = hp(noise(.25), 1500) * env_exp(.25, .05)
    body = lp(brown(d), 160) * (np.minimum(1, t_(d) / .15) * env_exp(d, 1.3)) + lp(noise(d), 700) * env_exp(d, .5) * .4
    body[:len(crack)] += crack * .7
    return norm(body) * v
def wave_crash(v):
    d = 1.8; x = bp(noise(d), 150, 3000) * np.minimum(1, t_(d) / .2) * env_exp(d, .5) + lp(brown(d), 150) * env_exp(d, .6) * .6
    return norm(x) * v
def splash(v):
    d = 1.2
    n = bp(noise(d), 300, 6000) * env_exp(d, .18); th = np.zeros(int(d * SR)); tb = thump(1, 60); th[:len(tb)] = tb
    return norm(n + th * .6) * v
def submerge(v):
    d = 2.2; n = noise(d); out = np.zeros_like(n); tt = t_(d)
    for i in range(0, len(n), 960):
        f = 3000 * np.exp(-4 * i / len(n)) + 150; hi = min(len(n), i + 960); out[i:hi] = lp(n[max(0, i - 3000):hi], f)[-(hi - i):]
    return norm(out * np.sin(np.pi * tt / d) ** .5 + bubbles(d, 14, 13) * .5) * v
def whale(v, low=False):
    d = 3.6; tt = t_(d); f0, f1 = (95, 58) if low else (150, 92)
    f = f0 + (f1 - f0) * (tt / d) ** .8 + 3 * np.sin(2 * np.pi * 5 * tt)
    ph = np.cumsum(f) / SR * 2 * np.pi
    x = (np.sin(ph) + .55 * np.sin(2 * ph) + .3 * np.sin(3 * ph) + .15 * np.sin(5 * ph)) * np.sin(np.pi * tt / d) ** 1.2
    return norm(lp(x, 900)) * v
def jaw(v):
    d = 1.6; tt = t_(d); x = np.sin(2 * np.pi * 42 * tt * (1 - .2 * tt)) * env_exp(d, .35) + lp(noise(d), 260) * env_exp(d, .08)
    return norm(x) * v
def swell(v):
    d = 2.4; tt = t_(d); x = lp(brown(d), 220) * np.sin(np.pi * tt / d) ** 2
    return norm(x) * v
def rise_s(v):
    d = 7.0; tt = t_(d); n = noise(d); out = np.zeros_like(n)
    for i in range(0, len(n), 960):
        f = 300 + 2600 * (i / len(n)) ** 1.5; hi = min(len(n), i + 960); out[i:hi] = lp(n[max(0, i - 3000):hi], f)[-(hi - i):]
    return norm(out * (tt / d) ** 1.5 + bubbles(d, 20, 21, 1.6) * .3) * v
def breach(v):
    d = 2.5; return norm(bp(noise(d), 400, 8000) * np.minimum(1, t_(d) / .05) * env_exp(d, .6) + surf(d, 2.0, 9, 2000) * .3) * v
def shimmer(v):  # light catching: a soft high glint, not a melody
    d = 1.8; tt = t_(d); x = sum(np.sin(2 * np.pi * f * tt + p) * env_exp(d, .5) for f, p in [(2349, 0), (3520, 1), (4699, 2)])
    return norm(hp(x * (1 - np.exp(-tt / .02)), 1500)) * v
def lampoff(v):
    d = .12; x = hp(noise(d), 2000) * env_exp(d, .006) + np.sin(2 * np.pi * 1800 * t_(d)) * env_exp(d, .01)
    return norm(x) * v

G = {'tap': .06, 'chime': .025, 'gull': .05, 'creak': .07, 'thunder': .36, 'crash': .22, 'flip': .09, 'splash': .3, 'submerge': .3,
     'whale': .2, 'jawopen': .1, 'jaw': .36, 'swell': .25, 'rise': .2, 'breach': .28, 'fluke': .12, 'leaf': .07, 'bird': .035,
     'strip': .1, 'plop': .06, 'cut': .05, 'spark': .05, 'paper': .05, 'lampoff': .35}
for e in EV:
    ty, t, v, pan = e['type'], e['t'], e.get('v', 1), e.get('pan', 0)
    if ty == 'bed': continue
    if ty == 'strip' and v <= 0: continue
    g = G.get(ty, 0) * v; pan = float(np.clip(pan, -.8, .8))
    if ty == 'tap': put(tap(1), t, g, pan)
    elif ty == 'chime': put(shimmer(1), t, g, pan)
    elif ty == 'gull': put(gull(1), t, g, pan)
    elif ty == 'creak': put(creak(1), t, g, pan); put(creak(1), t + .3, g * .7, pan)
    elif ty == 'thunder': put(thunder(1), t, g, pan)
    elif ty == 'crash': put(wave_crash(1), t, g, pan)
    elif ty == 'flip': put(rustle(.25), t, g, pan); put(tap(1), t + .5, g * .9, pan)
    elif ty == 'splash': put(splash(1), t, g, pan)
    elif ty == 'submerge': put(submerge(1), t, g, pan)
    elif ty == 'whale': put(whale(1, e.get('low', 0)), t, g, -.2)
    elif ty == 'jawopen': put(lp(whale(1, True), 300), t, g, 0)
    elif ty == 'jaw': put(jaw(1), t, g, 0)
    elif ty == 'swell': put(swell(1), t, g, pan)
    elif ty == 'rise': put(rise_s(1), t, g, 0)
    elif ty == 'breach': put(breach(1), t, g, .3)
    elif ty == 'fluke': put(lp(breach(1), 1500), t, g, -.5)
    elif ty == 'leaf': put(rustle(.3), t, g, pan)
    elif ty == 'bird': put(songbird(1), t, g, pan)
    elif ty == 'strip': put(rustle(.45), t, g, 0)
    elif ty == 'spark': put(shimmer(1), t, g, 0)
    elif ty == 'paper': put(rustle(.4), t, g, 0)
    elif ty == 'lampoff': put(lampoff(1), t, g, 0)
    elif ty == 'plop': put(lp(pop(1), 1800), t, g, pan); put(bp(noise(.25), 800, 5000) * env_exp(.25, .06), t + .05, g * .5, pan)
    elif ty == 'cut': put(rustle(.16), t, g, pan); put(tap(1), t + .1, g * .5, pan)

buf = buf[:int(DUR * SR)]
for c in range(2): buf[:, c] = limit(buf[:, c], .9)
os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
sf.write(os.path.join(HERE, 'out', 'mix.wav'), buf, SR, subtype='PCM_24')
print('mix.wav', buf.shape[0] / SR, 's  peak', float(np.abs(buf).max()))
