"""صفحه‌ی پنل مدیریت (یک فایل، بدون وابستگی بیرونی)."""

ADMIN_HTML = r"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>مدیریت کالری‌لنز</title>
<style>
  :root { --bg:#f4f7f5; --card:#fff; --ink:#17201b; --mute:#5c6b63; --line:#dbe4de;
          --green:#1E7A40; --green2:#145A2E; --err:#b3261e; --ok:#1E7A40; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#101412; --card:#1a201d; --ink:#e6ece8; --mute:#9aa9a1; --line:#2c3631;
            --green:#3fae6a; --green2:#2f8f55; --err:#ffb4ab; --ok:#7fd9a0; }
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.8 Vazirmatn, Tahoma, sans-serif; }
  main { max-width: 760px; margin: 0 auto; padding: 16px; }
  h1 { font-size: 1.4rem; margin: 12px 0; }
  h2 { font-size: 1.05rem; margin: 0 0 8px; color: var(--green); }
  .card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:16px; margin:12px 0; }
  label { display:block; margin-top:12px; font-weight:700; font-size:.95rem; }
  .hint { color:var(--mute); font-size:.85rem; font-weight:400; }
  input, select { width:100%; padding:10px 12px; margin-top:4px; border:1px solid var(--line); border-radius:10px;
                  background:var(--bg); color:var(--ink); font:inherit; }
  input[dir=ltr] { text-align:left; }
  button { font:inherit; font-weight:700; padding:10px 18px; border-radius:10px; border:0; cursor:pointer;
           background:var(--green); color:#fff; margin-top:14px; }
  button.ghost { background:transparent; color:var(--green); border:1px solid var(--line); }
  button:disabled { opacity:.5; cursor:wait; }
  .row { display:flex; gap:8px; flex-wrap:wrap; align-items:center; }
  .msg { margin-top:12px; padding:10px 12px; border-radius:10px; white-space:pre-line; }
  .msg.err { color:var(--err); border:1px solid var(--err); }
  .msg.ok { color:var(--ok); border:1px solid var(--ok); }
  .scroll { overflow-x:auto; }
  table { border-collapse:collapse; width:100%; font-size:.9rem; }
  th, td { padding:6px 8px; border-bottom:1px solid var(--line); text-align:start; white-space:nowrap; }
  .stat { display:inline-block; margin-inline-end:20px; }
  .stat b { font-size:1.3rem; display:block; }
  [hidden] { display:none !important; }
</style>
</head>
<body>
<main>
  <h1>مدیریت کالری‌لنز</h1>

  <section id="setup" class="card" hidden>
    <h2>ساخت رمز مدیر</h2>
    <p class="hint">این کار فقط یک بار انجام می‌شود. «کد راه‌اندازی» همان مقدار ADMIN_TOKEN است که هنگام نصب سرور ساخته شده.</p>
    <p id="setup-off" class="msg err" hidden>روی سرور ADMIN_TOKEN تنظیم نشده؛ بدون آن نمی‌شود رمز ساخت.</p>
    <label>کد راه‌اندازی <input id="setup-code" dir="ltr" autocomplete="off"></label>
    <label>رمز جدید (حداقل ۱۰ نویسه) <input id="setup-pass" type="password" dir="ltr" autocomplete="new-password"></label>
    <label>تکرار رمز <input id="setup-pass2" type="password" dir="ltr" autocomplete="new-password"></label>
    <button id="setup-btn">ساخت رمز و ورود</button>
    <div id="setup-msg"></div>
  </section>

  <section id="login" class="card" hidden>
    <h2>ورود مدیر</h2>
    <label>رمز <input id="login-pass" type="password" dir="ltr" autocomplete="current-password"></label>
    <button id="login-btn">ورود</button>
    <div id="login-msg"></div>
  </section>

  <div id="panel" hidden>
    <section class="card">
      <h2>وضعیت</h2>
      <div id="status"></div>
      <div class="row">
        <button id="test-btn" class="ghost">آزمایش اتصال به مدل</button>
        <button id="logout-btn" class="ghost">خروج</button>
      </div>
      <div id="test-msg"></div>
    </section>

    <form id="form"></form>
    <section class="card">
      <button id="save-btn">ذخیره و اجرا برای همه</button>
      <span class="hint">تغییرها بلافاصله برای همه‌ی کاربران اعمال می‌شود؛ ری‌استارت لازم نیست.</span>
      <div id="save-msg"></div>
    </section>

    <section class="card">
      <h2>۱۴ روز اخیر</h2>
      <div class="scroll"><table id="days"></table></div>
    </section>

    <section class="card">
      <h2>تغییر رمز</h2>
      <label>رمز فعلی <input id="pw-cur" type="password" dir="ltr" autocomplete="current-password"></label>
      <label>رمز جدید <input id="pw-new" type="password" dir="ltr" autocomplete="new-password"></label>
      <button id="pw-btn" class="ghost">تغییر رمز</button>
      <div id="pw-msg"></div>
    </section>
  </div>
</main>
<script>
const $ = (id) => document.getElementById(id);
const fa = (n) => Number(n).toLocaleString('fa-IR', {maximumFractionDigits: 4});
const ERR = {
  bad_password: 'رمز اشتباه است.', bad_setup_code: 'کد راه‌اندازی اشتباه است.',
  rate_limited: 'تلاش زیاد. چند دقیقه‌ی دیگر دوباره امتحان کن.',
  already_setup: 'رمز قبلاً ساخته شده؛ وارد شو.', unauthorized: 'نشست تمام شده؛ دوباره وارد شو.',
};
async function api(method, path, body) {
  const res = await fetch('/admin/api/' + path, {
    method, credentials: 'same-origin',
    headers: {'Content-Type': 'application/json', 'X-Requested-With': 'cl-admin'},
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = {};
  try { data = await res.json(); } catch (_) {}
  return {ok: res.ok, status: res.status, data};
}
function say(id, text, ok) {
  const el = $(id); el.textContent = text; el.className = text ? 'msg ' + (ok ? 'ok' : 'err') : '';
}
function errText(r) {
  if (r.data.errors) return r.data.errors.join('\n');
  const e = r.data.error || {};
  return ERR[e.code] || e.message || 'خطا (' + r.status + ')';
}
async function busy(btn, fn) { btn.disabled = true; try { await fn(); } finally { btn.disabled = false; } }

let fields = [];
function renderForm() {
  const form = $('form'); form.textContent = '';
  const groups = {};
  for (const f of fields) (groups[f.group] ||= []).push(f);
  for (const [name, list] of Object.entries(groups)) {
    const card = document.createElement('section'); card.className = 'card';
    const h = document.createElement('h2'); h.textContent = name; card.append(h);
    for (const f of list) {
      const label = document.createElement('label'); label.textContent = f.label + ' ';
      let input;
      if (f.kind === 'choice') {
        input = document.createElement('select');
        for (const c of f.choices) { const o = document.createElement('option'); o.value = o.textContent = c; input.append(o); }
        input.value = f.value;
      } else {
        input = document.createElement('input'); input.dir = 'ltr';
        if (f.kind === 'secret') { input.type = 'password'; input.autocomplete = 'off';
          input.placeholder = f.is_set ? 'تنظیم شده: ' + f.masked : 'تنظیم نشده'; }
        else if (f.kind === 'int' || f.kind === 'float') { input.type = 'number'; input.step = f.kind === 'int' ? '1' : 'any'; input.value = f.value; }
        else input.value = f.value;
      }
      input.dataset.name = f.name; input.dataset.kind = f.kind; input.dataset.orig = f.kind === 'secret' ? '' : String(f.value);
      label.append(input);
      if (f.hint) { const s = document.createElement('span'); s.className = 'hint'; s.textContent = f.hint; label.append(s); }
      card.append(label);
    }
    form.append(card);
  }
}
function renderStatus(d) {
  const s = $('status'); s.textContent = '';
  const add = (k, v) => { const e = document.createElement('span'); e.className = 'stat';
    const b = document.createElement('b'); b.textContent = v; e.append(b, k); s.append(e); };
  add('مدل فعال', d.provider.name === 'none' ? 'تنظیم نشده' : (d.provider.model || d.provider.name));
  add('دستگاه ثبت‌شده', fa(d.totals.devices));
  add('غذا در پایگاه', fa(d.foods));
  add('حالت سرور', d.env === 'production' ? 'انتشار' : 'توسعه');
  const t = $('days'); t.textContent = '';
  const head = ['روز', 'اسکن', 'موفق', 'از کش', 'ناموفق', 'کاربر فعال', 'هزینه ($)', 'میانگین (ms)'];
  const tr = document.createElement('tr');
  for (const h of head) { const th = document.createElement('th'); th.textContent = h; tr.append(th); }
  t.append(tr);
  for (const r of d.days) {
    const row = document.createElement('tr');
    for (const v of [r.day, fa(r.scans), fa(r.food_scans || 0), fa(r.cached || 0), fa(r.failed || 0),
                     fa(r.active_devices), fa(r.cost_usd), r.avg_latency_ms == null ? '—' : fa(r.avg_latency_ms)]) {
      const td = document.createElement('td'); td.textContent = v; row.append(td);
    }
    t.append(row);
  }
  if (!d.days.length) { const row = document.createElement('tr'); const td = document.createElement('td');
    td.colSpan = head.length; td.textContent = 'هنوز اسکنی ثبت نشده.'; row.append(td); t.append(row); }
}
async function loadPanel() {
  const r = await api('GET', 'settings');
  if (!r.ok) return start();
  fields = r.data.fields; renderForm(); renderStatus(r.data);
  $('setup').hidden = $('login').hidden = true; $('panel').hidden = false;
}
async function start() {
  const r = await api('GET', 'state');
  $('panel').hidden = true;
  if (r.data.logged_in) return loadPanel();
  $('setup').hidden = !r.data.needs_setup; $('login').hidden = r.data.needs_setup;
  $('setup-off').hidden = r.data.setup_available !== false;
}
$('setup-btn').onclick = (e) => busy(e.target, async () => {
  if ($('setup-pass').value !== $('setup-pass2').value) return say('setup-msg', 'دو رمز یکی نیستند.');
  const r = await api('POST', 'setup', {setup_code: $('setup-code').value.trim(), password: $('setup-pass').value});
  r.ok ? loadPanel() : say('setup-msg', errText(r));
});
$('login-btn').onclick = (e) => busy(e.target, async () => {
  const r = await api('POST', 'login', {password: $('login-pass').value});
  $('login-pass').value = '';
  r.ok ? (say('login-msg', ''), loadPanel()) : say('login-msg', errText(r));
});
$('login-pass').onkeydown = (e) => { if (e.key === 'Enter') $('login-btn').click(); };
$('logout-btn').onclick = async () => { await api('POST', 'logout'); start(); };
$('save-btn').onclick = (e) => busy(e.target, async () => {
  const values = {};
  for (const el of $('form').querySelectorAll('[data-name]')) {
    const k = el.dataset.kind, v = el.value;
    if (k === 'secret') { if (v !== '') values[el.dataset.name] = v; continue; }
    if (v === el.dataset.orig) continue;
    values[el.dataset.name] = (k === 'int' || k === 'float') ? Number(v) : v;
  }
  if (!Object.keys(values).length) return say('save-msg', 'چیزی تغییر نکرده.', true);
  const r = await api('PUT', 'settings', {values});
  if (!r.ok) return say('save-msg', 'ذخیره نشد:\n' + errText(r));
  const names = r.data.changed.map((n) => (fields.find((f) => f.name === n) || {}).label || n);
  await loadPanel();
  say('save-msg', 'ذخیره شد و برای همه اجرا شد:\n• ' + names.join('\n• '), true);
});
$('test-btn').onclick = (e) => busy(e.target, async () => {
  say('test-msg', 'در حال آزمایش…', true);
  const r = await api('POST', 'test');
  if (!r.ok) return say('test-msg', errText(r));
  r.data.ok ? say('test-msg', 'مدل پاسخ درست داد (' + fa(r.data.ms) + ' میلی‌ثانیه).', true)
            : say('test-msg', 'مدل پاسخ نداد:\n' + r.data.error);
});
$('pw-btn').onclick = (e) => busy(e.target, async () => {
  const r = await api('POST', 'password', {current: $('pw-cur').value, new: $('pw-new').value});
  $('pw-cur').value = $('pw-new').value = '';
  r.ok ? say('pw-msg', 'رمز عوض شد.', true) : say('pw-msg', errText(r));
});
start();
</script>
</body>
</html>
"""
