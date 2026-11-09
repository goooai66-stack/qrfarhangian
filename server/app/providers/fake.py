"""ارائه‌دهنده‌ی جعلی برای توسعه و تست (بدون اینترنت و هزینه)."""

from __future__ import annotations

import json

from .base import ProviderResponse

DEFAULT_RESULT = {
    "items": [
        {"food_id": "chelo", "name_fa": "چلو", "quantity": 1.5, "unit": "kafgir", "confidence": 0.86},
        {"food_id": "kabab_koobideh", "name_fa": "کباب کوبیده", "quantity": 2, "unit": "piece", "confidence": 0.91},
        {"food_id": None, "name_fa": "گوجه کبابی", "quantity": 1, "unit": "piece", "confidence": 0.7},
    ],
    "is_food": True,
    "notes_fa": None,
}


class FakeProvider:
    name = "fake"
    model = "fake"

    def __init__(
        self,
        result: dict | str | None = None,
        error: Exception | None = None,
        text_parser=None,
        text_result: dict | str | None = None,
    ):
        self.result = DEFAULT_RESULT if result is None else result
        self.error = error
        self.calls = 0
        # تجزیه‌ی جمله: پاسخ ثابت یا تجزیه‌گر قاعده‌محور (app/text_parser.py).
        self.text_parser = text_parser
        self.text_result = text_result
        self.text_calls = 0

    async def recognize(self, image, media_type, system_prompt, user_text, schema) -> ProviderResponse:
        self.calls += 1
        if self.error is not None:
            raise self.error
        text = self.result if isinstance(self.result, str) else json.dumps(self.result, ensure_ascii=False)
        return ProviderResponse(text=text, input_tokens=1000, output_tokens=100)

    async def parse_text(self, system_prompt, text, schema) -> ProviderResponse:
        self.text_calls += 1
        if self.error is not None:
            raise self.error
        if self.text_result is not None:
            r = self.text_result
            out = r if isinstance(r, str) else json.dumps(r, ensure_ascii=False)
        elif self.text_parser is not None:
            out = self.text_parser.parse(text)
        else:
            out = json.dumps({"items": [], "is_food": False, "notes_fa": None, "meal": None})
        return ProviderResponse(text=out, input_tokens=500, output_tokens=80)
