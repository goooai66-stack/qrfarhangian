"""تجزیه‌گر ساده‌ی قاعده‌محور جمله‌ی غذا — فقط برای توسعه و تست (FakeProvider).

در تولید، مدل زبانی همین کار را می‌کند. این تجزیه‌گر کمک می‌کند جریان ثبت
صوتی/متنی بدون کلید API هم قابل آزمایش باشد.
"""

from __future__ import annotations

import json
import re

from .foods import FoodDB
from .normalize import normalize

_MEALS = [
    ("میان وعده", "snack"),
    ("عصرانه", "snack"),
    ("صبحانه", "breakfast"),
    ("سحر", "breakfast"),
    ("ناهار", "lunch"),
    ("شام", "dinner"),
    ("افطار", "dinner"),
]

_NUMBERS = {
    "نصف": 0.5,
    "نیم": 0.5,
    "یه": 1,
    "یک": 1,
    "یدونه": 1,
    "دو": 2,
    "دوتا": 2,
    "سه": 3,
    "سه تا": 3,
    "چهار": 4,
    "پنج": 5,
}

_UNITS = [
    ("کف دست", "palm"),
    ("بشقاب", "plate"),
    ("کفگیر", "kafgir"),
    ("ملاقه", "ladle"),
    ("کاسه", "bowl"),
    ("لیوان", "glass"),
    ("قاشق", "tablespoon"),
    ("برش", "slice"),
    ("تیکه", "slice"),
    ("گرم", "gram"),
    ("عدد", "piece"),
    ("دونه", "piece"),
]

_SPLIT = re.compile(r"\s+(?:و|با)\s+|[،,]")


class KeywordTextParser:
    def __init__(self, db: FoodDB):
        self.db = db
        # نام‌ها از بلند به کوتاه تا «برنج سفید» قبل از «برنج» تطبیق بخورد.
        self._names = sorted(
            ((n, f) for f in db.foods for n in f.normalized_names if len(n) >= 2),
            key=lambda x: -len(x[0]),
        )

    def parse(self, text: str) -> str:
        t = normalize(text)
        meal = next((m for word, m in _MEALS if word in t), None)
        items = []
        for seg in _SPLIT.split(t):
            seg = f" {seg.strip()} "
            food = next((f for n, f in self._names if f" {n} " in seg or f" {n}" in seg), None)
            if food is None:
                continue
            qty = 1.0
            m = re.search(r"(\d+(?:\.\d+)?)", seg)
            if m:
                qty = float(m.group(1))
            else:
                for word, v in sorted(_NUMBERS.items(), key=lambda x: -len(x[0])):
                    if f" {word} " in seg:
                        qty = float(v)
                        break
            unit = next((u for word, u in _UNITS if word in seg), food.default_unit)
            items.append(
                {"food_id": food.id, "name_fa": food.name_fa, "quantity": qty, "unit": unit, "confidence": 0.6}
            )
        return json.dumps(
            {"items": items, "is_food": bool(items), "notes_fa": None, "meal": meal}, ensure_ascii=False
        )
