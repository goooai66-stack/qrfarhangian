"""انتخاب ارائه‌دهنده از روی تنظیمات (VISION_PROVIDER)."""

from __future__ import annotations

from ..config import Settings
from .base import ProviderError, ProviderResponse, VisionProvider


class NotConfiguredProvider:
    """هنوز از پنل مدیریت تنظیم نشده: اسکن و ثبت صوتی خطای روشن می‌دهند، نه پاسخ ساختگی."""

    name = "none"
    model = ""

    async def recognize(self, image, media_type, system_prompt, user_text, schema) -> ProviderResponse:
        raise ProviderError("vision provider is not configured")

    async def parse_text(self, system_prompt, text, schema) -> ProviderResponse:
        raise ProviderError("vision provider is not configured")


def build_provider(s: Settings) -> VisionProvider:
    match s.vision_provider:
        case "none":
            return NotConfiguredProvider()
        case "fake":
            from .fake import FakeProvider

            return FakeProvider()
        case "anthropic":
            from .anthropic_provider import AnthropicProvider

            return AnthropicProvider(
                s.anthropic_model, s.anthropic_effort, s.provider_timeout_seconds, s.anthropic_api_key
            )
        case "openai_compatible":
            from .openai_compatible import OpenAICompatibleProvider

            return OpenAICompatibleProvider(
                s.openai_compat_base_url,
                s.openai_compat_api_key,
                s.openai_compat_model,
                s.provider_timeout_seconds,
                extra_headers={
                    "HTTP-Referer": s.openai_compat_referer,
                    "X-Title": s.openai_compat_title,
                },
            )
    raise ValueError(f"VISION_PROVIDER ناشناخته: {s.vision_provider}")
