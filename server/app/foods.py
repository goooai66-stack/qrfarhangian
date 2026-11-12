"""پایگاه غذای ایرانی (همان assets/data/foods.json اپ).

اصل بخش ۸-۱: کالری فقط از این داده حساب می‌شود، نه از خروجی مدل.
مقدار null یعنی داده از منبع نیامده؛ null می‌ماند، صفر نمی‌شود.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from .normalize import match_score, normalize

NUTRIENTS = ("kcal", "protein", "carbs", "fat")

# واحدهای ایرانی مجاز در خروجی مدل (بخش ۴-۲).
UNITS: dict[str, str] = {
    "kafgir": "کفگیر",
    "ladle": "ملاقه",
    "plate": "بشقاب",
    "bowl": "کاسه",
    "glass": "لیوان",
    "tablespoon": "قاشق غذاخوری",
    "palm": "کف دست",
    "piece": "عدد",
    "slice": "برش",
    "gram": "گرم",
}

# حداقل امتیاز تطبیق فازی برای پذیرفتن یک غذا.
FUZZY_MIN_SCORE = 70


@dataclass(frozen=True)
class Food:
    id: str
    name_fa: str
    aliases: tuple[str, ...]
    per_100g: dict[str, float | None]
    units: dict[str, float | None]  # unit -> grams (None = اندازه‌گیری نشده)
    default_unit: str
    normalized_names: tuple[str, ...]

    def nutrients(self, unit: str, quantity: float) -> tuple[float | None, dict[str, float | None]]:
        unit_grams = self.units.get(unit)
        grams = None if unit_grams is None else quantity * unit_grams
        values = {
            k: (None if grams is None or self.per_100g.get(k) is None else self.per_100g[k] * grams / 100)
            for k in NUTRIENTS
        }
        return grams, values


class FoodDB:
    def __init__(self, foods: list[Food]):
        self.foods = foods
        self.by_id = {f.id: f for f in foods}

    @classmethod
    def load(cls, path: Path) -> "FoodDB":
        raw = json.loads(Path(path).read_text(encoding="utf-8"))
        foods: list[Food] = []
        seen: set[str] = set()
        for r in raw:
            if r["id"] in seen:
                raise ValueError(f"food_id تکراری: {r['id']}")
            seen.add(r["id"])
            per = r.get("per_100g") or {}
            units = {u["unit"]: (None if u.get("grams") is None else float(u["grams"])) for u in r["units"]}
            names = {r["name_fa"], *r.get("aliases", []), *([r["name_en"]] if r.get("name_en") else [])}
            foods.append(
                Food(
                    id=r["id"],
                    name_fa=r["name_fa"],
                    aliases=tuple(r.get("aliases", [])),
                    per_100g={k: (None if per.get(k) is None else float(per[k])) for k in NUTRIENTS},
                    units=units,
                    default_unit=r.get("default_unit") or next(iter(units)),
                    normalized_names=tuple(normalize(n) for n in names),
                )
            )
        return cls(foods)

    def search(self, query: str) -> list[tuple[Food, int]]:
        q = normalize(query)
        scored = []
        for f in self.foods:
            best = max((match_score(q, n) for n in f.normalized_names), default=0)
            if best > 0:
                scored.append((f, best))
        scored.sort(key=lambda x: (-x[1], x[0].name_fa))
        return scored

    def best_match(self, name: str) -> Food | None:
        found = self.search(name)
        if found and found[0][1] >= FUZZY_MIN_SCORE:
            return found[0][0]
        return None

    def prompt_food_list(self) -> str:
        """فهرست food_idهای مجاز برای پرامپت (ترتیب ثابت تا کش پرامپت بماند)."""
        lines = []
        for f in sorted(self.foods, key=lambda f: f.id):
            extra = f" ({'، '.join(f.aliases)})" if f.aliases else ""
            lines.append(f"{f.id}: {f.name_fa}{extra}")
        return "\n".join(lines)
