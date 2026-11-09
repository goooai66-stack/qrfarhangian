"""انتخاب ارائه‌دهنده از روی تنظیمات (VISION_PROVIDER)."""

from __future__ import annotations

from ..config import Settings
from .base import VisionProvider


def build_provider(s: Settings) -> VisionProvider:
    match s.vision_provider:
        case "fake":
            from .fake import FakeProvider

            return FakeProvider()
        case "anthropic":
            from .anthropic_provider import AnthropicProvider

            return AnthropicProvider(s.anthropic_model, s.anthropic_effort, s.provider_timeout_seconds)
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
