"""رابط ارائه‌دهنده‌ی مدل بینایی (الگوی Adapter، بخش ۲-۹).

هیچ‌جای دیگر کد به یک شرکت خاص وابسته نیست؛ فقط پیاده‌سازی‌های این پوشه.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass
class ProviderResponse:
    text: str  # JSON خام مدل
    input_tokens: int | None = None
    output_tokens: int | None = None


class ProviderError(Exception):
    """خطای عمومی ارائه‌دهنده (۵۰۲)."""


class ProviderBusy(ProviderError):
    """ارائه‌دهنده شلوغ است یا محدودیت نرخ دارد (۵۰۳)."""


class ProviderTimeout(ProviderError):
    """پاسخ به‌موقع نیامد (۵۰۴)."""


class ProviderRefused(ProviderError):
    """مدل درخواست را رد کرد (مثلاً طبقه‌بند ایمنی)."""


class VisionProvider(Protocol):
    name: str
    model: str

    async def recognize(
        self,
        image: bytes,
        media_type: str,
        system_prompt: str,
        user_text: str,
        schema: dict,
    ) -> ProviderResponse: ...
