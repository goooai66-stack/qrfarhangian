"""سرور واسط کالری‌لنز (بخش ۸ و ۱۰-۴).

اجرا: uvicorn app.main:app --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
import time
import uuid

from fastapi import Depends, FastAPI, File, Header, Request, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from .billing.verifiers import (
    FakePurchaseVerifier,
    InvalidPurchase,
    NotConfiguredPurchaseVerifier,
    TrustingRewardVerifier,
    VerifierUnavailable,
    parse_product_days,
)
from .config import Settings
from .db import Database
from .foods import FoodDB
from .model_output import InvalidModelOutput, parse_model_output
from .prompt import MAX_TEXT_CHARS, OUTPUT_SCHEMA, USER_TEXT, VOICE_SCHEMA, build_system_prompt, build_voice_prompt
from .providers import build_provider
from .providers.base import ProviderBusy, ProviderError, ProviderRefused, ProviderTimeout, VisionProvider
from .ratelimit import RateLimiter
from .scan_service import resolve
from .text_parser import KeywordTextParser

log = logging.getLogger("calorielens")

_DEVICE_ID = re.compile(r"^[A-Za-z0-9_-]{16,64}$")
_DAY = re.compile(r"^\d{4}-\d{2}-\d{2}$")


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


class RewardIn(BaseModel):
    reward_token: str


# رویدادهای مجاز آنالیتیکس (بخش ۱۱)؛ هیچ داده‌ی شخصی یا غذایی.
ANALYTICS_EVENTS = {
    "onboarding_completed",
    "scan",
    "voice_log",
    "log_food",
    "paywall_view",
    "purchase",
    "retention_d1",
    "retention_d7",
    "retention_d30",
}


class EventIn(BaseModel):
    name: str
    day: str
    count: int = 1


class EventsIn(BaseModel):
    events: list[EventIn]


class VoiceIn(BaseModel):
    text: str


class InviteIn(BaseModel):
    code: str


class FeedbackIn(BaseModel):
    scan_id: str | None = None
    original: list[dict]
    corrected: list[dict]
    note: str | None = None


class PurchaseIn(BaseModel):
    store: str
    product_id: str
    purchase_token: str


def create_app(
    settings: Settings | None = None,
    provider: VisionProvider | None = None,
    purchase_verifier=None,
) -> FastAPI:
    s = settings or Settings.from_env()
    foods = FoodDB.load(s.foods_path)
    db = Database(s.db_path, s.quota_timezone)
    vision = provider or build_provider(s)
    system_prompt = build_system_prompt(foods)
    voice_prompt = build_voice_prompt(foods)
    product_days = parse_product_days(s.product_days)
    purchases = (
        FakePurchaseVerifier(product_days) if s.purchase_verifier == "fake" else NotConfiguredPurchaseVerifier()
    )
    if purchase_verifier is not None:
        purchases = purchase_verifier
    rewards = TrustingRewardVerifier()
    scan_limiter = RateLimiter(s.scans_per_minute, 60)
    register_limiter = RateLimiter(s.device_registrations_per_hour_per_ip, 3600)
    if vision.name == "fake":
        # توسعه: جمله‌ها با تجزیه‌گر قاعده‌محور (بدون کلید API).
        if getattr(vision, "text_parser", None) is None and getattr(vision, "text_result", None) is None:
            vision.text_parser = KeywordTextParser(foods)
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
        if db.is_premium(device):
            return s.premium_scans_per_day
        return s.free_scans_per_day + db.usage_today(device["id"])[1]

    def quota_body(device) -> dict:
        limit = limit_for(device)
        used, rewards = db.usage_today(device["id"])
        premium = db.is_premium(device)
        return {
            "used": used,
            "limit": limit,
            "remaining": max(0, limit - used),
            "day": db.today(),
            "premium": premium,
            "premium_until": device["premium_until"] if premium else None,
            "rewards_left": 0 if premium else max(0, s.rewards_per_day - rewards),
            "voice_remaining": max(0, voice_limit_for(device) - db.voice_today(device["id"])),
        }

    def voice_limit_for(device) -> int:
        return s.premium_voice_per_day if db.is_premium(device) else s.free_voice_per_day

    def fresh(device):
        """ردیف دستگاه بعد از تغییر (مثلاً خرید)."""
        return db.device_by_id(device["id"])

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

    @app.post("/voice")
    async def voice(body: VoiceIn, device=Depends(current_device)):
        """ثبت صوتی/متنی (بخش ۸-۴): جمله ← همان JSON آیتم‌ها + وعده.
        صدا روی گوشی به متن تبدیل می‌شود؛ صدا به سرور نمی‌آید."""
        text = body.text.strip()
        if not text:
            raise ApiError(400, "empty_text", "text is empty")
        if len(text) > MAX_TEXT_CHARS:
            raise ApiError(413, "text_too_long", f"max {MAX_TEXT_CHARS} chars")
        wait = scan_limiter.check(device["id"])
        if wait is not None:
            raise ApiError(429, "rate_limited", "too many requests", {"Retry-After": str(int(wait) + 1)})
        if not db.try_reserve_voice(device["id"], voice_limit_for(device)):
            raise ApiError(429, "voice_quota_exceeded", "daily voice quota exhausted")
        started = time.monotonic()
        log_base = {"id": str(uuid.uuid4()), "device_id": device["id"], "provider": vision.name, "model": vision.model}

        def fail(status, code, message, log_status):
            db.refund_voice(device["id"])
            db.log_scan(**log_base, status=f"voice_{log_status}", latency_ms=int((time.monotonic() - started) * 1000))
            raise ApiError(status, code, message)

        try:
            resp = await vision.parse_text(voice_prompt, text, VOICE_SCHEMA)
        except ProviderTimeout:
            fail(504, "provider_timeout", "parsing timed out", "timeout")
        except ProviderBusy:
            fail(503, "provider_busy", "service busy", "busy")
        except ProviderError:
            fail(502, "provider_error", "parsing failed", "error")
        try:
            raw = parse_model_output(resp.text, allow_meal=True)
        except InvalidModelOutput:
            fail(502, "invalid_model_output", "parsing returned invalid data", "invalid_output")
        result = resolve(raw, foods)
        if not result["is_food"]:
            db.refund_voice(device["id"])
        cost = None
        if resp.input_tokens is not None and resp.output_tokens is not None and (
            s.price_input_per_mtok or s.price_output_per_mtok
        ):
            cost = (resp.input_tokens * s.price_input_per_mtok + resp.output_tokens * s.price_output_per_mtok) / 1e6
        db.log_scan(
            **log_base,
            status="voice_ok",
            is_food=int(result["is_food"]),
            item_count=len(result["items"]),
            input_tokens=resp.input_tokens,
            output_tokens=resp.output_tokens,
            cost_usd=cost,
            latency_ms=int((time.monotonic() - started) * 1000),
        )
        return {"scan_id": log_base["id"], **result, "meal": raw.meal, "quota": quota_body(device)}

    @app.get("/invite")
    async def invite(device=Depends(current_device)):
        n, by = db.invite_stats(device["id"])
        return {"code": db.invite_code(device["id"]), "invited": n, "redeemed_code": by, "days": s.invite_days}

    @app.post("/invite/redeem")
    async def invite_redeem(body: InviteIn, device=Depends(current_device)):
        """کد دعوت دوست ← ۷ روز ویژه برای هر دو (ثبت سمت سرور)."""
        r = db.redeem_invite(device["id"], body.code, s.invite_days, s.invite_max_rewards)
        if r == "invalid":
            raise ApiError(404, "invalid_code", "invite code not found")
        if r == "self":
            raise ApiError(400, "own_code", "cannot redeem own code")
        if r == "already":
            raise ApiError(409, "already_redeemed", "an invite code was already redeemed")
        return quota_body(fresh(device))

    @app.post("/feedback/scan")
    async def feedback_scan(body: FeedbackIn, device=Depends(current_device)):
        """«تشخیص اشتباه بود» + اصلاح کاربر (برای بهبود داده؛ بدون عکس)."""
        original = json.dumps(body.original, ensure_ascii=False)
        corrected = json.dumps(body.corrected, ensure_ascii=False)
        if len(original) + len(corrected) > 20_000 or (body.note and len(body.note) > 500):
            raise ApiError(413, "feedback_too_large", "feedback too large")
        db.add_feedback(device["id"], body.scan_id, original, corrected, body.note)
        return {"ok": True}

    @app.post("/events")
    async def events(body: EventsIn, device=Depends(current_device)):
        """شمارش رویدادها (بدون داده‌ی شخصی). نام‌های ناشناخته نادیده گرفته می‌شوند."""
        ok = [
            (e.day, e.name, min(max(e.count, 0), 1000))
            for e in body.events[:200]
            if e.name in ANALYTICS_EVENTS and _DAY.match(e.day) and e.count > 0
        ]
        db.add_events(device["id"], ok)
        return {"accepted": len(ok)}

    @app.get("/admin/events")
    async def admin_events(days: int = 30, x_admin_token: str | None = Header(default=None)):
        if not s.admin_token or x_admin_token != s.admin_token:
            raise ApiError(404, "not_found", "not found")
        return {"events": db.event_stats(min(max(days, 1), 365))}

    @app.delete("/device")
    async def delete_device(device=Depends(current_device)):
        """«حذف همه‌ی داده‌ها» (بخش ۴-۷): داده‌های این دستگاه روی سرور پاک می‌شود."""
        db.delete_device(device["id"])
        return {"ok": True}

    @app.post("/quota/reward")
    async def quota_reward(body: RewardIn, device=Depends(current_device)):
        """ویدیوی جایزه‌دار کامل دیده شد ← ۱ اسکن بیشتر (حداکثر N در روز)."""
        if db.is_premium(device):
            raise ApiError(409, "premium_user", "premium users have no ads")
        if not await rewards.verify(body.reward_token):
            raise ApiError(400, "invalid_reward", "reward not verified")
        if not db.try_add_reward(device["id"], s.rewards_per_day):
            raise ApiError(429, "reward_limit", "daily reward limit reached")
        return quota_body(device)

    @app.post("/purchase/verify")
    async def purchase_verify(body: PurchaseIn, device=Depends(current_device)):
        """اعتبارسنجی خرید بازار/مایکت سمت سرور ← فعال‌سازی ویژه (بخش ۹-۳).
        بازیابی خرید بعد از نصب دوباره هم از همین مسیر است."""
        if body.store not in ("bazaar", "myket"):
            raise ApiError(400, "invalid_store", "store must be bazaar or myket")
        try:
            p = await purchases.verify(body.store, body.product_id, body.purchase_token)
        except InvalidPurchase:
            raise ApiError(402, "invalid_purchase", "purchase could not be verified")
        except VerifierUnavailable:
            raise ApiError(503, "verification_unavailable", "purchase verification is not available")
        if p.expires_at <= time.time():
            raise ApiError(402, "purchase_expired", "subscription has expired")
        db.apply_purchase(body.purchase_token, body.store, p.product_id, device["id"], p.expires_at)
        return quota_body(fresh(device))

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
