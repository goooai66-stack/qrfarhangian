"""جریان اسکن: مدل ← اعتبارسنجی ← تطبیق با پایگاه غذا ← محاسبه‌ی کالری از داده‌ی خودمان."""

from __future__ import annotations

from .foods import FoodDB
from .model_output import RawResult


def resolve(raw: RawResult, db: FoodDB) -> dict:
    """خروجی معتبر مدل را به پاسخ API تبدیل می‌کند.

    - food_id معتبر ← exact
    - food_id نامعتبر/null ← جستجوی فازی روی name_fa ← fuzzy
    - پیدا نشد ← food_id=null (اپ می‌گوید «پیدا نکردیم، انتخاب کن»)
    - واحدی که برای آن غذا تعریف نشده ← واحد پیش‌فرض غذا (unit_adjusted)
    - کالری فقط از foods.json؛ داده‌ی ناقص null می‌ماند.
    """
    items = []
    for it in raw.items:
        food = db.by_id.get(it.food_id) if it.food_id else None
        match = "exact"
        if food is None:
            food = db.best_match(it.name_fa)
            match = "fuzzy" if food else "none"
        unit, adjusted = it.unit, False
        grams = None
        nutrients = {"kcal": None, "protein": None, "carbs": None, "fat": None}
        if food is not None:
            if unit not in food.units:
                unit, adjusted = food.default_unit, True
            grams, nutrients = food.nutrients(unit, it.quantity)
        items.append(
            {
                "food_id": food.id if food else None,
                "name_fa": food.name_fa if food else it.name_fa,
                "detected_name_fa": it.name_fa,
                "quantity": it.quantity,
                "unit": unit,
                "unit_adjusted": adjusted,
                "confidence": round(it.confidence, 3),
                "match": match,
                "grams": grams,
                **nutrients,
            }
        )
    return {"is_food": raw.is_food, "notes_fa": raw.notes_fa, "items": items}
