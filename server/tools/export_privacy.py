"""صفحه‌ی حریم خصوصی برای لینک فروشگاه را از همان متن داخل اپ می‌سازد.

    python server/tools/export_privacy.py   # ← docs/privacy.html

متن فقط در lib/l10n/app_fa.arb ویرایش شود؛ بعد این را دوباره اجرا کن.
"""
import html
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
arb = json.loads((ROOT / "lib/l10n/app_fa.arb").read_text(encoding="utf-8"))


def paragraphs(text: str) -> str:
    out = []
    for block in text.split("\n\n"):
        lines = [html.escape(l) for l in block.strip().split("\n")]
        head, *rest = lines
        if head[:1] in "۱۲۳۴۵۶۷۸۹" and rest:
            out.append(f"<h2>{head}</h2>")
            lines = rest
        out.append("<p>" + "<br>".join(lines) + "</p>")
    return "\n".join(out)


page = f"""<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(arb["privacyTitle"])} | {html.escape(arb["appTitle"])}</title>
<link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;700&display=swap" rel="stylesheet">
<style>
  body {{ font-family: Vazirmatn, Tahoma, sans-serif; line-height: 1.9; max-width: 720px;
         margin: 0 auto; padding: 24px 16px; color: #1b1f1c; background: #fff; }}
  h1 {{ color: #1E7A40; }} h2 {{ font-size: 1.1rem; margin-top: 1.6em; }}
  @media (prefers-color-scheme: dark) {{ body {{ color: #e3e7e3; background: #111412; }} h1 {{ color: #6fd08f; }} }}
</style>
</head>
<body>
<h1>{html.escape(arb["privacyTitle"])} — {html.escape(arb["appTitle"])}</h1>
{paragraphs(arb["privacyBody"])}
<h1>{html.escape(arb["disclaimerTitle"])}</h1>
{paragraphs(arb["disclaimerBody"])}
</body>
</html>
"""
(ROOT / "docs/privacy.html").write_text(page, encoding="utf-8")
print("docs/privacy.html")
