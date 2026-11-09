"""مقایسه‌ی مدل‌های بینایی روی عکس‌های واقعی غذای ایرانی (بخش ۸-۵ سند).

هر عکس مثل اپ آماده می‌شود (حداکثر ضلع ۱۰۲۴، JPEG ۷۵، زیر ۲۰۰ کیلوبایت)،
به هر مدل داده می‌شود و همان مسیر سرور (اعتبارسنجی ← تطبیق با food_id) طی می‌شود.
سهمیه و دیتابیس سرور درگیر نمی‌شوند.

نمونه (OpenRouter):
    export VISION_PROVIDER=openai_compatible
    export OPENAI_COMPAT_BASE_URL=https://openrouter.ai/api/v1
    export OPENAI_COMPAT_API_KEY=...
    python -m tools.eval_photos --photos ./photos \\
        --models "model-a,model-b" \\
        --prices "model-a=0.10:0.40,model-b=1.00:4.00" --out ./eval

خروجی: eval/results.md (برای بررسی چشمی، ستون «درست؟» را پر کنید) و eval/results.csv
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import io
import statistics
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

from app.config import Settings
from app.foods import FoodDB
from app.model_output import InvalidModelOutput, parse_model_output
from app.prompt import OUTPUT_SCHEMA, USER_TEXT, build_system_prompt
from app.providers import build_provider
from app.providers.base import ProviderError
from app.scan_service import resolve

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}


def prepare_image(path: Path, max_side: int = 1024, quality: int = 75, max_bytes: int = 200 * 1024) -> bytes:
    """همان فشرده‌سازی اپ (lib/core/utils/image_compress.dart)."""
    from PIL import Image, ImageOps

    im = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    im.thumbnail((max_side, max_side))
    q = quality
    while True:
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=q)
        data = buf.getvalue()
        if len(data) <= max_bytes or q <= 45:
            return data
        q -= 10


@dataclass
class Row:
    photo: str
    model: str
    status: str  # ok | invalid_output | error
    latency_ms: int
    input_tokens: int | None = None
    output_tokens: int | None = None
    cost_usd: float | None = None
    is_food: bool | None = None
    items: list[dict] = field(default_factory=list)
    error: str = ""

    def items_text(self) -> str:
        if self.status != "ok":
            return f"⚠️ {self.status}: {self.error}"
        if not self.is_food:
            return "(غذا نیست)"
        parts = []
        for i in self.items:
            mark = {"exact": "", "fuzzy": "~", "none": "?"}[i["match"]]
            parts.append(f"{mark}{i['name_fa']} {i['quantity']:g} {i['unit']} ({i['confidence']:.2f})")
        return "، ".join(parts)


def parse_prices(spec: str) -> dict[str, tuple[float, float]]:
    out = {}
    for part in filter(None, (p.strip() for p in spec.split(","))):
        model, _, nums = part.rpartition("=")
        pin, _, pout = nums.partition(":")
        out[model] = (float(pin), float(pout))
    return out


def build_providers(settings: Settings, models: list[str]):
    if not models:
        return [build_provider(settings)]
    providers = []
    for m in models:
        if settings.vision_provider == "anthropic":
            settings.anthropic_model = m
        elif settings.vision_provider == "openai_compatible":
            settings.openai_compat_model = m
        providers.append(build_provider(settings))
    return providers


async def evaluate(photos: list[Path], providers, db: FoodDB, prices: dict[str, tuple[float, float]]) -> list[Row]:
    system_prompt = build_system_prompt(db)
    rows: list[Row] = []
    for photo in photos:
        image = prepare_image(photo)
        for p in providers:
            started = time.monotonic()
            row = Row(photo=photo.name, model=p.model, status="ok", latency_ms=0)
            try:
                resp = await p.recognize(image, "image/jpeg", system_prompt, USER_TEXT, OUTPUT_SCHEMA)
                row.input_tokens, row.output_tokens = resp.input_tokens, resp.output_tokens
                result = resolve(parse_model_output(resp.text), db)
                row.is_food, row.items = result["is_food"], result["items"]
            except InvalidModelOutput as e:
                row.status, row.error = "invalid_output", str(e)[:120]
            except ProviderError as e:
                row.status, row.error = "error", f"{type(e).__name__}: {str(e)[:120]}"
            row.latency_ms = int((time.monotonic() - started) * 1000)
            if p.model in prices and row.input_tokens is not None and row.output_tokens is not None:
                pin, pout = prices[p.model]
                row.cost_usd = (row.input_tokens * pin + row.output_tokens * pout) / 1_000_000
            rows.append(row)
            print(f"{photo.name} | {p.model} | {row.latency_ms}ms | {row.items_text()}", file=sys.stderr)
    return rows


def summarize(rows: list[Row]) -> list[dict]:
    out = []
    for model in dict.fromkeys(r.model for r in rows):
        rs = [r for r in rows if r.model == model]
        lat = sorted(r.latency_ms for r in rs)
        costs = [r.cost_usd for r in rs if r.cost_usd is not None]
        p90 = lat[min(len(lat) - 1, int(round(0.9 * (len(lat) - 1))))] if lat else 0
        out.append(
            {
                "model": model,
                "photos": len(rs),
                "ok": sum(r.status == "ok" for r in rs),
                "invalid_output": sum(r.status == "invalid_output" for r in rs),
                "errors": sum(r.status == "error" for r in rs),
                "unmatched_items": sum(1 for r in rs for i in r.items if i["match"] == "none"),
                "avg_latency_ms": int(statistics.mean(lat)) if lat else 0,
                "p90_latency_ms": p90,
                "under_8s_pct": round(100 * sum(x <= 8000 for x in lat) / len(lat)) if lat else 0,
                "avg_cost_usd": round(statistics.mean(costs), 6) if costs else None,
            }
        )
    return out


def write_reports(rows: list[Row], out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    with (out / "results.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["photo", "model", "status", "latency_ms", "input_tokens", "output_tokens", "cost_usd", "is_food", "items", "correct"])
        for r in rows:
            w.writerow([r.photo, r.model, r.status, r.latency_ms, r.input_tokens, r.output_tokens, r.cost_usd, r.is_food, r.items_text(), ""])

    lines = ["# مقایسه‌ی مدل‌های بینایی", "", "## خلاصه", ""]
    summary = summarize(rows)
    lines += [
        "| مدل | عکس | موفق | JSON نامعتبر | خطا | آیتم تطبیق‌نخورده | میانگین زمان | p90 | زیر ۸ ثانیه | هزینه‌ی هر اسکن (دلار) |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for s in summary:
        cost = "—" if s["avg_cost_usd"] is None else f"{s['avg_cost_usd']:.5f}"
        lines.append(
            f"| `{s['model']}` | {s['photos']} | {s['ok']} | {s['invalid_output']} | {s['errors']} | "
            f"{s['unmatched_items']} | {s['avg_latency_ms']}ms | {s['p90_latency_ms']}ms | {s['under_8s_pct']}٪ | {cost} |"
        )
    lines += [
        "",
        "## جزئیات (ستون «درست؟» را با ✓ / ✗ / ½ پر کنید)",
        "",
        "`~` = تطبیق فازی، `?` = در پایگاه غذا پیدا نشد، عدد داخل پرانتز = اطمینان مدل",
        "",
        "| عکس | مدل | تشخیص | زمان | درست؟ |",
        "|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append(f"| {r.photo} | `{r.model}` | {r.items_text()} | {r.latency_ms}ms | |")
    (out / "results.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--photos", required=True, type=Path, help="پوشه‌ی عکس‌ها")
    ap.add_argument("--models", default="", help="شناسه‌ی مدل‌ها با کاما (خالی = مدل تنظیمات)")
    ap.add_argument("--prices", default="", help='قیمت هر میلیون توکن: "model=in:out,..."')
    ap.add_argument("--out", type=Path, default=Path("eval"))
    ap.add_argument("--limit", type=int, default=0, help="حداکثر تعداد عکس")
    a = ap.parse_args(argv)

    photos = sorted(p for p in a.photos.iterdir() if p.suffix.lower() in IMAGE_EXT)
    if a.limit:
        photos = photos[: a.limit]
    if not photos:
        print("عکسی پیدا نشد.", file=sys.stderr)
        return 1
    settings = Settings.from_env()
    db = FoodDB.load(settings.foods_path)
    models = [m.strip() for m in a.models.split(",") if m.strip()]
    rows = asyncio.run(evaluate(photos, build_providers(settings, models), db, parse_prices(a.prices)))
    write_reports(rows, a.out)
    print(f"گزارش: {a.out / 'results.md'}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
