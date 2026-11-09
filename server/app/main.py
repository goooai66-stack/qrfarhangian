"""سرور واسط کالری‌لنز (بخش ۸ و ۱۰-۴).

اجرا: uvicorn app.main:app --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import hashlib
import logging
import re
import time
import uuid

from fastapi import Depends, FastAPI, File, Header, Request, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from .config import Settings
from .db import Database
from .foods import FoodDB
from .model_output import InvalidModelOutput, parse_model_output
from .prompt import OUTPUT_SCHEMA, USER_TEXT, build_system_prompt
from .providers import build_provider
from .providers.base import ProviderBusy, ProviderError, ProviderRefused, ProviderTimeout, VisionProvider
from .ratelimit import RateLimiter
from .scan_service import resolve

log = logging.getLogger("calorielens")

_DEVICE_ID = re.compile(r"^[A-Za-z0-9_-]{16,64}$")


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, headers: dict | None = None):
        self.status, self.code, self.message, self.headers = status, code, message, headers


def _image_type(data: bytes) -> str | None:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


class DeviceIn(BaseModel):
    device_id: str


def create_app(settings: Settings | None = None, provider: VisionProvider | None = None) -> FastAPI:
    s = settings or Settings.from_env()
    foods = FoodDB.load(s.foods_path)
    db = Database(s.db_path, s.quota_timezone)
    vision = provider or build_provider(s)
    system_prompt = build_system_prompt(foods)
    scan_limiter = RateLimiter(s.scans_per_minute, 60)
    register_limiter = RateLimiter(s.device_registrations_per_hour_per_ip, 3600)
    if vision.name == "fake":
        log.warning("VISION_PROVIDER=fake — پاسخ‌ها ساختگی‌اند؛ فقط برای توسعه.")

    app = FastAPI(title="CalorieLens API", version="1.0")
    app.state.db = db
    app.state.provider = vision

    @app.exception_handler(ApiError)
    async def _api_error(_: Request, e: ApiError):
        return JSONResponse(
            {"error": {"code": e.code, "message": e.message}}, status_code=e.status, headers=e.headers
        )

    def limit_for(device) -> int:
        return s.premium_scans_per_day if db.is_premium(device) else s.free_scans_per_day

    def quota_body(device) -> dict:
        limit = limit_for(device)
        used = db.used_today(device["id"])
        return {"used": used, "limit": limit, "remaining": max(0, limit - used), "day": db.today()}

    async def current_device(authorization: str | None = Header(default=None)):
        if not authorization or not authorization.startswith("Bearer "):
            raise ApiError(401, "unauthorized", "missing bearer token")
        device = db.device_for_token(authorization.removeprefix("Bearer ").strip())
        if device is None:
            raise ApiError(401, "unauthorized", "invalid token")
        return device

    @app.get("/health")
    async def health():
        return {"ok": True, "provider": vision.name, "foods": len(foods.foods)}

    @app.post("/auth/device")
    async def auth_device(body: DeviceIn, request: Request):
        if not _DEVICE_ID.match(body.device_id):
            raise ApiError(400, "invalid_device_id", "device_id must be 16-64 [A-Za-z0-9_-]")
        ip = request.client.host if request.client else "unknown"
        wait = register_limiter.check(ip)
        if wait is not None:
            raise ApiError(429, "rate_limited", "too many registrations", {"Retry-After": str(int(wait) + 1)})
        return {"token": db.register_device(body.device_id)}

    @app.get("/quota")
    async def quota(device=Depends(current_device)):
        return quota_body(device)

    @app.post("/scan")
    async def scan(image: UploadFile = File(...), device=Depends(current_device)):
        data = await image.read(s.max_image_bytes + 1)
        if len(data) > s.max_image_bytes:
            raise ApiError(413, "image_too_large", f"max {s.max_image_bytes} bytes")
        media_type = _image_type(data)
        if media_type is None:
            raise ApiError(415, "unsupported_image", "jpeg, png or webp only")

        wait = scan_limiter.check(device["id"])
        if wait is not None:
            raise ApiError(429, "rate_limited", "too many scans", {"Retry-After": str(int(wait) + 1)})
        if not db.try_reserve_scan(device["id"], limit_for(device)):
            raise ApiError(429, "quota_exceeded", "daily scan quota exhausted", {"X-Quota-Remaining": "0"})

        scan_id = str(uuid.uuid4())
        started = time.monotonic()
        log_base = {"id": scan_id, "device_id": device["id"], "provider": vision.name, "model": vision.model}
        image_hash = hashlib.sha256(data).hexdigest()

        def fail(status: int, code: str, message: str, log_status: str):
            db.refund_scan(device["id"])
            db.log_scan(**log_base, status=log_status, latency_ms=int((time.monotonic() - started) * 1000))
            raise ApiError(status, code, message)

        result = db.cache_get(image_hash, s.cache_ttl_days)
        cached = result is not None
        tokens_in = tokens_out = None
        if result is None:
            try:
                resp = await vision.recognize(data, media_type, system_prompt, USER_TEXT, OUTPUT_SCHEMA)
            except ProviderTimeout:
                fail(504, "provider_timeout", "recognition timed out", "timeout")
            except ProviderBusy:
                fail(503, "provider_busy", "recognition service busy", "busy")
            except ProviderRefused:
                fail(502, "provider_refused", "recognition refused", "refused")
            except ProviderError as e:
                log.error("provider error: %s", e)
                fail(502, "provider_error", "recognition failed", "error")
            tokens_in, tokens_out = resp.input_tokens, resp.output_tokens
            try:
                raw = parse_model_output(resp.text)
            except InvalidModelOutput as e:
                log.error("invalid model output: %s", e)
                fail(502, "invalid_model_output", "recognition returned invalid data", "invalid_output")
            result = resolve(raw, foods)
            db.cache_put(image_hash, result)

        cost = None
        if tokens_in is not None and tokens_out is not None and (s.price_input_per_mtok or s.price_output_per_mtok):
            cost = (tokens_in * s.price_input_per_mtok + tokens_out * s.price_output_per_mtok) / 1_000_000
        if not result["is_food"]:
            db.refund_scan(device["id"])  # بخش ۸-۲: غذا نبود ← سهمیه کم نمی‌شود
        db.log_scan(
            **log_base,
            status="ok",
            is_food=int(result["is_food"]),
            item_count=len(result["items"]),
            cached=int(cached),
            input_tokens=tokens_in,
            output_tokens=tokens_out,
            cost_usd=cost,
            latency_ms=int((time.monotonic() - started) * 1000),
        )
        return {"scan_id": scan_id, **result, "quota": quota_body(device)}

    @app.get("/admin/stats")
    async def admin_stats(days: int = 30, x_admin_token: str | None = Header(default=None)):
        if not s.admin_token or x_admin_token != s.admin_token:
            raise ApiError(404, "not_found", "not found")
        return {"days": db.stats(min(max(days, 1), 365))}

    return app


def __getattr__(name: str):
    # `uvicorn app.main:app` ← ساخت تنبل تا import در تست‌ها چیزی نسازد.
    if name == "app":
        globals()["app"] = create_app()
        return globals()["app"]
    raise AttributeError(name)
