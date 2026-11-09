"""اعتبارسنجی سخت‌گیرانه‌ی خروجی مدل. هر چیز خارج از اسکیما رد می‌شود."""

from __future__ import annotations

import json
import math
from dataclasses import dataclass

from .foods import UNITS
from .prompt import MAX_ITEMS


class InvalidModelOutput(ValueError):
    pass


@dataclass
class RawItem:
    food_id: str | None
    name_fa: str
    quantity: float
    unit: str
    confidence: float


@dataclass
class RawResult:
    items: list[RawItem]
    is_food: bool
    notes_fa: str | None


def _strip_fence(text: str) -> str:
    t = text.strip()
    if t.startswith("```"):
        t = t.split("\n", 1)[1] if "\n" in t else ""
        if t.rstrip().endswith("```"):
            t = t.rstrip()[:-3]
    return t.strip()


def parse_model_output(text: str) -> RawResult:
    try:
        data = json.loads(_strip_fence(text))
    except (json.JSONDecodeError, TypeError) as e:
        raise InvalidModelOutput(f"JSON نامعتبر: {e}") from e
    if not isinstance(data, dict):
        raise InvalidModelOutput("ریشه باید object باشد")
    if set(data) - {"items", "is_food", "notes_fa"}:
        raise InvalidModelOutput(f"کلید اضافه: {set(data) - {'items', 'is_food', 'notes_fa'}}")
    is_food = data.get("is_food")
    if not isinstance(is_food, bool):
        raise InvalidModelOutput("is_food باید boolean باشد")
    notes = data.get("notes_fa")
    if notes is not None and not isinstance(notes, str):
        raise InvalidModelOutput("notes_fa باید متن یا null باشد")
    raw_items = data.get("items")
    if not isinstance(raw_items, list):
        raise InvalidModelOutput("items باید آرایه باشد")
    if len(raw_items) > MAX_ITEMS:
        raise InvalidModelOutput("تعداد آیتم‌ها بیش از حد")

    items: list[RawItem] = []
    for i, it in enumerate(raw_items):
        if not isinstance(it, dict):
            raise InvalidModelOutput(f"items[{i}] باید object باشد")
        fid = it.get("food_id")
        name = it.get("name_fa")
        qty = it.get("quantity")
        unit = it.get("unit")
        conf = it.get("confidence")
        if fid is not None and not isinstance(fid, str):
            raise InvalidModelOutput(f"items[{i}].food_id")
        if not isinstance(name, str) or not name.strip() or len(name) > 80:
            raise InvalidModelOutput(f"items[{i}].name_fa")
        if isinstance(qty, bool) or not isinstance(qty, (int, float)) or not math.isfinite(qty) or not 0 < qty <= 50:
            raise InvalidModelOutput(f"items[{i}].quantity")
        if unit not in UNITS:
            raise InvalidModelOutput(f"items[{i}].unit نامعتبر: {unit}")
        if isinstance(conf, bool) or not isinstance(conf, (int, float)) or not math.isfinite(conf):
            raise InvalidModelOutput(f"items[{i}].confidence")
        items.append(
            RawItem(
                food_id=fid or None,
                name_fa=name.strip(),
                quantity=float(qty),
                unit=unit,
                confidence=min(1.0, max(0.0, float(conf))),
            )
        )
    if not is_food:
        items = []
    return RawResult(items=items, is_food=is_food, notes_fa=(notes or None))
