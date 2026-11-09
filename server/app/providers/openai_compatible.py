"""آداپتر عمومی برای هر سرویس سازگار با OpenAI Chat Completions
(OpenAI، Gemini از مسیر سازگار، OpenRouter، درگاه‌های داخلی، مدل محلی).

این فایل به Claude ربطی ندارد؛ برای Claude از anthropic_provider استفاده شود.
"""

from __future__ import annotations

import base64
import json

import httpx

from .base import ProviderBusy, ProviderError, ProviderResponse, ProviderTimeout


class OpenAICompatibleProvider:
    name = "openai_compatible"

    def __init__(
        self,
        base_url: str,
        api_key: str,
        model: str,
        timeout: float,
        extra_headers: dict[str, str] | None = None,
    ):
        if not base_url or not model:
            raise ValueError("OPENAI_COMPAT_BASE_URL و OPENAI_COMPAT_MODEL لازم‌اند")
        self.model = model
        self._url = base_url.rstrip("/") + "/chat/completions"
        self._headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
        # مثلاً OpenRouter: HTTP-Referer و X-Title برای ثبت مصرف به نام اپ.
        self._headers.update({k: v for k, v in (extra_headers or {}).items() if v})
        self._client = httpx.AsyncClient(timeout=timeout)
        # بعضی مدل‌ها json_schema را نمی‌پذیرند؛ بعد از اولین رد، json_object.
        self._schema_supported = True

    def _body(self, data_url: str | None, system_prompt: str, user_text: str, schema: dict, strict: bool) -> dict:
        if strict:
            system = system_prompt
            response_format = {
                "type": "json_schema",
                "json_schema": {"name": "food_scan", "schema": schema, "strict": True},
            }
        else:
            # اسکیما در پرامپت؛ سرور به‌هرحال خروجی را سخت‌گیرانه بررسی می‌کند.
            system = f"{system_prompt}\n\nاسکیمای JSON خروجی:\n{json.dumps(schema, ensure_ascii=False)}"
            response_format = {"type": "json_object"}
        return {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": user_text},
                        *([{"type": "image_url", "image_url": {"url": data_url}}] if data_url else []),
                    ],
                },
            ],
            "response_format": response_format,
            "max_tokens": 2000,
        }

    async def _post(self, body: dict) -> httpx.Response:
        try:
            return await self._client.post(self._url, json=body, headers=self._headers)
        except httpx.TimeoutException as e:
            raise ProviderTimeout(str(e)) from e
        except httpx.HTTPError as e:
            raise ProviderBusy(str(e)) from e

    async def recognize(self, image, media_type, system_prompt, user_text, schema) -> ProviderResponse:
        data_url = f"data:{media_type};base64,{base64.standard_b64encode(image).decode('ascii')}"
        return await self._complete(data_url, system_prompt, user_text, schema)

    async def parse_text(self, system_prompt, text, schema) -> ProviderResponse:
        return await self._complete(None, system_prompt, text, schema)

    async def _complete(self, data_url, system_prompt, user_text, schema) -> ProviderResponse:
        r = await self._post(self._body(data_url, system_prompt, user_text, schema, self._schema_supported))
        if r.status_code == 400 and self._schema_supported:
            # احتمالاً json_schema پشتیبانی نمی‌شود ← یک‌بار با json_object.
            self._schema_supported = False
            r = await self._post(self._body(data_url, system_prompt, user_text, schema, False))
        if r.status_code == 429 or r.status_code >= 500:
            raise ProviderBusy(f"{r.status_code}")
        if r.status_code >= 400:
            raise ProviderError(f"{r.status_code}: {r.text[:300]}")
        try:
            j = r.json()
            text = j["choices"][0]["message"]["content"]
            usage = j.get("usage") or {}
        except (ValueError, KeyError, IndexError, TypeError) as e:
            raise ProviderError(f"پاسخ نامعتبر: {e}") from e
        if not isinstance(text, str):
            raise ProviderError("پاسخ بدون متن")
        return ProviderResponse(
            text=text,
            input_tokens=usage.get("prompt_tokens"),
            output_tokens=usage.get("completion_tokens"),
        )
