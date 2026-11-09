"""پرامپت سیستمی مدل (بخش ۸-۳) و اسکیمای سخت‌گیرانه‌ی خروجی (بخش ۸-۲)."""

from __future__ import annotations

from .foods import UNITS, FoodDB

SYSTEM_TEMPLATE = """تو یک متخصص تشخیص غذاهای ایرانی هستی. عکس یک وعده‌ی غذایی را می‌بینی.
۱. همه‌ی غذاهای قابل مشاهده را جدا کن (برنج، خورش، نان، سالاد، نوشیدنی...).
۲. برای هر کدام نزدیک‌ترین food_id را فقط از این فهرست انتخاب کن. اگر هیچ‌کدام مناسب نبود، food_id را null بگذار و name_fa را بنویس.
فهرست (food_id: نام):
{food_list}
۳. مقدار را با واحدهای ایرانی تخمین بزن. واحدهای مجاز (کد: نام): {unit_list}. از اندازه‌ی بشقاب، قاشق و دست برای مقیاس استفاده کن.
۴. به هر مورد اطمینان ۰ تا ۱ بده.
۵. فقط JSON طبق اسکیمای داده‌شده برگردان. کالری حساب نکن.
اگر عکس غذا نیست، is_food=false و items خالی.
اگر بخشی از بشقاب خارج از کادر است یا عکس تار است، در notes_fa کوتاه بگو."""

USER_TEXT = "غذاهای این عکس را تشخیص بده."

MAX_ITEMS = 15


def build_system_prompt(db: FoodDB) -> str:
    units = "، ".join(f"{code}: {name}" for code, name in UNITS.items())
    return SYSTEM_TEMPLATE.format(food_list=db.prompt_food_list(), unit_list=units)


# اسکیمای JSON برای structured output ارائه‌دهنده‌ها (بخش ۸-۲).
OUTPUT_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "food_id": {"anyOf": [{"type": "string"}, {"type": "null"}]},
                    "name_fa": {"type": "string"},
                    "quantity": {"type": "number"},
                    "unit": {"type": "string", "enum": list(UNITS)},
                    "confidence": {"type": "number"},
                },
                "required": ["food_id", "name_fa", "quantity", "unit", "confidence"],
                "additionalProperties": False,
            },
        },
        "is_food": {"type": "boolean"},
        "notes_fa": {"anyOf": [{"type": "string"}, {"type": "null"}]},
    },
    "required": ["items", "is_food", "notes_fa"],
    "additionalProperties": False,
}
