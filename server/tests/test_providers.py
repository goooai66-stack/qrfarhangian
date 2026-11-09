"""آداپترهای واقعی با transport جعلی (بدون شبکه و بدون کلید واقعی)."""

import asyncio
import json

import anthropic
import httpx
import httpx2
import pytest

from app.prompt import OUTPUT_SCHEMA
from app.providers.anthropic_provider import AnthropicProvider
from app.providers.base import ProviderBusy, ProviderError, ProviderRefused
from app.providers.openai_compatible import OpenAICompatibleProvider

IMG = b"\xff\xd8\xff\xe0fake"
RESULT = '{"items": [], "is_food": false, "notes_fa": null}'


def run(coro):
    return asyncio.run(coro)


def anthropic_with(handler) -> AnthropicProvider:
    p = AnthropicProvider("claude-opus-5-5", "low", timeout=5)
    p._client = anthropic.AsyncAnthropic(
        api_key="test-key",
        max_retries=0,
        http_client=httpx2.AsyncClient(transport=httpx2.MockTransport(handler)),
    )
    return p


def message(stop_reason="end_turn", text=RESULT):
    return {
        "id": "msg_1",
        "type": "message",
        "role": "assistant",
        "model": "claude-opus-5-5",
        "content": [{"type": "text", "text": text}] if text is not None else [],
        "stop_reason": stop_reason,
        "stop_sequence": None,
        "usage": {"input_tokens": 1234, "output_tokens": 56},
    }


def test_anthropic_request_shape_and_usage():
    seen = {}

    def handler(req: httpx2.Request):
        seen["body"] = json.loads(req.content)
        seen["beta"] = req.headers.get("anthropic-beta")
        return httpx2.Response(200, json=message())

    r = run(anthropic_with(handler).recognize(IMG, "image/jpeg", "SYS", "USER", OUTPUT_SCHEMA))
    b = seen["body"]
    assert b["model"] == "claude-opus-5-5"
    assert b["system"][0]["text"] == "SYS"
    assert b["system"][0]["cache_control"] == {"type": "ephemeral"}
    img = b["messages"][0]["content"][0]
    assert img["type"] == "image" and img["source"]["media_type"] == "image/jpeg"
    assert b["output_config"]["format"]["type"] == "json_schema"
    assert b["output_config"]["effort"] == "low"
    assert b["fallbacks"] == "default"
    assert "server-side-fallback-2026-07-01" in seen["beta"]
    assert r.text == RESULT and r.input_tokens == 1234 and r.output_tokens == 56


@pytest.mark.parametrize(
    "status,exc",
    [(429, ProviderBusy), (529, ProviderBusy), (500, ProviderBusy), (400, ProviderError)],
)
def test_anthropic_error_mapping(status, exc):
    def handler(req):
        return httpx2.Response(status, json={"type": "error", "error": {"type": "x", "message": "m"}})

    with pytest.raises(exc):
        run(anthropic_with(handler).recognize(IMG, "image/jpeg", "S", "U", OUTPUT_SCHEMA))


def test_anthropic_refusal():
    p = anthropic_with(lambda req: httpx2.Response(200, json=message("refusal", text=None)))
    with pytest.raises(ProviderRefused):
        run(p.recognize(IMG, "image/jpeg", "S", "U", OUTPUT_SCHEMA))


def openai_with(handler) -> OpenAICompatibleProvider:
    p = OpenAICompatibleProvider("https://gw.example/v1/", "k", "vision-model", timeout=5)
    p._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return p


def test_openai_compatible_request_and_parse():
    seen = {}

    def handler(req: httpx.Request):
        seen["url"] = str(req.url)
        seen["auth"] = req.headers.get("authorization")
        seen["body"] = json.loads(req.content)
        return httpx.Response(
            200,
            json={
                "choices": [{"message": {"content": RESULT}}],
                "usage": {"prompt_tokens": 900, "completion_tokens": 40},
            },
        )

    r = run(openai_with(handler).recognize(IMG, "image/jpeg", "SYS", "USER", OUTPUT_SCHEMA))
    assert seen["url"] == "https://gw.example/v1/chat/completions"
    assert seen["auth"] == "Bearer k"
    b = seen["body"]
    assert b["response_format"]["json_schema"]["strict"] is True
    assert b["messages"][1]["content"][1]["image_url"]["url"].startswith("data:image/jpeg;base64,")
    assert r.text == RESULT and r.input_tokens == 900


@pytest.mark.parametrize("status,exc", [(429, ProviderBusy), (503, ProviderBusy), (401, ProviderError)])
def test_openai_compatible_errors(status, exc):
    with pytest.raises(exc):
        run(openai_with(lambda req: httpx.Response(status, text="x")).recognize(IMG, "image/jpeg", "S", "U", {}))


def test_openai_compatible_requires_config():
    with pytest.raises(ValueError):
        OpenAICompatibleProvider("", "", "", 5)


def test_openai_compatible_falls_back_to_json_object_once():
    bodies = []

    def handler(req: httpx.Request):
        body = json.loads(req.content)
        bodies.append(body)
        if body["response_format"]["type"] == "json_schema":
            return httpx.Response(400, json={"error": {"message": "response_format not supported"}})
        return httpx.Response(200, json={"choices": [{"message": {"content": RESULT}}]})

    p = openai_with(handler)
    r = run(p.recognize(IMG, "image/jpeg", "SYS", "USER", OUTPUT_SCHEMA))
    assert r.text == RESULT
    assert [b["response_format"]["type"] for b in bodies] == ["json_schema", "json_object"]
    assert "اسکیمای JSON خروجی" in bodies[1]["messages"][0]["content"]
    # دفعه‌ی بعد مستقیم json_object.
    run(p.recognize(IMG, "image/jpeg", "SYS", "USER", OUTPUT_SCHEMA))
    assert bodies[2]["response_format"]["type"] == "json_object"


def test_openai_compatible_extra_headers():
    seen = {}

    def handler(req: httpx.Request):
        seen.update(req.headers)
        return httpx.Response(200, json={"choices": [{"message": {"content": RESULT}}]})

    p = OpenAICompatibleProvider(
        "https://openrouter.ai/api/v1", "k", "m", 5,
        extra_headers={"HTTP-Referer": "https://calorielens.ir", "X-Title": "CalorieLens", "X-Empty": ""},
    )
    p._client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    run(p.recognize(IMG, "image/jpeg", "S", "U", OUTPUT_SCHEMA))
    assert seen["http-referer"] == "https://calorielens.ir"
    assert seen["x-title"] == "CalorieLens"
    assert "x-empty" not in seen


def test_anthropic_parse_text_has_no_image():
    seen = {}

    def handler(req: httpx2.Request):
        seen["body"] = json.loads(req.content)
        return httpx2.Response(200, json=message())

    run(anthropic_with(handler).parse_text("SYS", "یه دوغ", OUTPUT_SCHEMA))
    content = seen["body"]["messages"][0]["content"]
    assert content == [{"type": "text", "text": "یه دوغ"}]


def test_openai_parse_text_has_no_image():
    seen = {}

    def handler(req: httpx.Request):
        seen["body"] = json.loads(req.content)
        return httpx.Response(200, json={"choices": [{"message": {"content": RESULT}}]})

    run(openai_with(handler).parse_text("SYS", "یه دوغ", OUTPUT_SCHEMA))
    assert seen["body"]["messages"][1]["content"] == [{"type": "text", "text": "یه دوغ"}]
