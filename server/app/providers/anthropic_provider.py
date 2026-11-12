"""آداپتر Claude با SDK رسمی Anthropic.

کلید از متغیر محیطی ANTHROPIC_API_KEY (فقط روی سرور) خوانده می‌شود.
"""

from __future__ import annotations

import base64

import anthropic

from .base import ProviderBusy, ProviderError, ProviderRefused, ProviderResponse, ProviderTimeout


class AnthropicProvider:
    name = "anthropic"

    def __init__(self, model: str, effort: str, timeout: float, api_key: str = ""):
        self.model = model
        self.effort = effort
        # retry داخلی SDK خاموش: مهلت پاسخ به کاربر کوتاه است.
        self._client = anthropic.AsyncAnthropic(api_key=api_key or None, timeout=timeout, max_retries=0)

    async def recognize(self, image, media_type, system_prompt, user_text, schema) -> ProviderResponse:
        content = [
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": base64.standard_b64encode(image).decode("ascii"),
                },
            },
            {"type": "text", "text": user_text},
        ]
        return await self._call(system_prompt, content, schema)

    async def parse_text(self, system_prompt, text, schema) -> ProviderResponse:
        return await self._call(system_prompt, [{"type": "text", "text": text}], schema)

    async def _call(self, system_prompt: str, content: list, schema: dict) -> ProviderResponse:
        try:
            response = await self._client.messages.create(
                model=self.model,
                max_tokens=4000,
                # فهرست غذاها ثابت است ← کش پرامپت هزینه را کم می‌کند.
                system=[{"type": "text", "text": system_prompt, "cache_control": {"type": "ephemeral"}}],
                messages=[{"role": "user", "content": content}],
                output_config={"effort": self.effort, "format": {"type": "json_schema", "schema": schema}},
                # رد ایمنی ← اجرای دوباره روی مدل جایگزین پیشنهادی Anthropic.
                extra_headers={"anthropic-beta": "server-side-fallback-2026-07-01"},
                extra_body={"fallbacks": "default"},
            )
        except anthropic.APITimeoutError as e:
            raise ProviderTimeout(str(e)) from e
        except anthropic.RateLimitError as e:
            raise ProviderBusy(str(e)) from e
        except anthropic.APIStatusError as e:
            if e.status_code >= 500:
                raise ProviderBusy(f"{e.status_code}") from e
            raise ProviderError(f"{e.status_code}: {e.message}") from e
        except anthropic.APIConnectionError as e:
            raise ProviderBusy(str(e)) from e

        if response.stop_reason == "refusal":
            raise ProviderRefused("refusal")
        text = next((b.text for b in response.content if b.type == "text"), None)
        if text is None:
            raise ProviderError(f"پاسخ بدون متن (stop_reason={response.stop_reason})")
        return ProviderResponse(
            text=text,
            input_tokens=response.usage.input_tokens,
            output_tokens=response.usage.output_tokens,
        )
