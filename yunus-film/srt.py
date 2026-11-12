"""Persian subtitles (.srt) from the verse cards, for YouTube."""
import os, re, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, 'src', 'data.js'), encoding='utf-8').read()
cards = re.findall(r"\{ id: '([^']+)', t0: ([\d.]+), t1: ([\d.]+),(?: ar: '([^']*)',)? fa: '([^']*)'(?:, ref: fa\('([^']*)'\))?", src)
def ts(t):
    ms = int(round(t * 1000)); h, ms = divmod(ms, 3600000); m, ms = divmod(ms, 60000); s, ms = divmod(ms, 1000); return f'{h:02}:{m:02}:{s:02},{ms:03}'
out = []
for i, (cid, t0, t1, ar, fa, ref) in enumerate(cards, 1):
    text = (ar + '\n' if ar else '') + fa + (f'  ({ref})' if ref else '')
    out.append(f'{i}\n{ts(float(t0) + .45)} --> {ts(float(t1) - .3)}\n{text}\n')
open(os.path.join(HERE, 'yunus.srt'), 'w', encoding='utf-8').write('\n'.join(out))
print('yunus.srt', len(out), 'cues')
