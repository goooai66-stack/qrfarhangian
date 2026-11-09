"""تنظیمات از متغیرهای محیطی. هیچ کلیدی در کد نیست (بخش ۲-۸)."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent


def _int(name: str, default: int) -> int:
    return int(os.environ.get(name, default))


def _float(name: str, default: float) -> float:
    return float(os.environ.get(name, default))


@dataclass
class Settings:
    # fake | anthropic | openai_compatible
    vision_provider: str = "fake"

    # Claude (کلید از ANTHROPIC_API_KEY که خود SDK می‌خواند)
    anthropic_model: str = "claude-opus-5-5"
    anthropic_effort: str = "low"

    # هر سرویس سازگار با OpenAI Chat Completions (یا درگاه داخلی)
    openai_compat_base_url: str = ""
    openai_compat_api_key: str = ""
    openai_compat_model: str = ""
    # هدرهای اختیاری OpenRouter
    openai_compat_referer: str = ""
    openai_compat_title: str = "CalorieLens"

    # قیمت هر میلیون توکن (دلار) برای لاگ هزینه؛ ۰ = نامعلوم
    price_input_per_mtok: float = 0.0
    price_output_per_mtok: float = 0.0

    provider_timeout_seconds: float = 20.0

    foods_path: Path = field(default_factory=lambda: _ROOT.parent / "assets" / "data" / "foods.json")
    db_path: str = "calorielens.db"

    free_scans_per_day: int = 3
    premium_scans_per_day: int = 30  # سقف منصفانه (مرحله‌ی ۵)
    quota_timezone: str = "Asia/Tehran"
    scans_per_minute: int = 6
    device_registrations_per_hour_per_ip: int = 10
    max_image_bytes: int = 1_000_000
    cache_ttl_days: int = 7

    # ثبت صوتی/متنی (بخش ۹-۱): رایگان ۲ در روز، ویژه با سقف منصفانه
    free_voice_per_day: int = 2
    premium_voice_per_day: int = 30
    # کد دعوت: ۷ روز ویژه برای هر دو طرف؛ سقف پاداش دعوت‌کننده
    invite_days: int = 7
    invite_max_rewards: int = 10

    # پاداش ویدیو: هر ویدیو = ۱ اسکن، حداکثر چند ویدیو در روز (بخش ۹-۱)
    rewards_per_day: int = 5
    # fake (توسعه) | stores (API فروشگاه‌ها؛ هنوز وصل نشده)
    purchase_verifier: str = "fake"
    product_days: str = "premium_monthly=30,premium_quarterly=90,premium_yearly=365"

    # خالی = /admin غیرفعال
    admin_token: str = ""

    @classmethod
    def from_env(cls) -> "Settings":
        e = os.environ
        s = cls(
            vision_provider=e.get("VISION_PROVIDER", "fake"),
            anthropic_model=e.get("ANTHROPIC_MODEL", "claude-opus-5-5"),
            anthropic_effort=e.get("ANTHROPIC_EFFORT", "low"),
            openai_compat_base_url=e.get("OPENAI_COMPAT_BASE_URL", ""),
            openai_compat_api_key=e.get("OPENAI_COMPAT_API_KEY", ""),
            openai_compat_model=e.get("OPENAI_COMPAT_MODEL", ""),
            openai_compat_referer=e.get("OPENAI_COMPAT_REFERER", ""),
            openai_compat_title=e.get("OPENAI_COMPAT_TITLE", "CalorieLens"),
            price_input_per_mtok=_float("PRICE_INPUT_PER_MTOK", 0.0),
            price_output_per_mtok=_float("PRICE_OUTPUT_PER_MTOK", 0.0),
            provider_timeout_seconds=_float("PROVIDER_TIMEOUT_SECONDS", 20.0),
            db_path=e.get("DB_PATH", "calorielens.db"),
            free_scans_per_day=_int("FREE_SCANS_PER_DAY", 3),
            premium_scans_per_day=_int("PREMIUM_SCANS_PER_DAY", 30),
            quota_timezone=e.get("QUOTA_TIMEZONE", "Asia/Tehran"),
            scans_per_minute=_int("SCANS_PER_MINUTE", 6),
            device_registrations_per_hour_per_ip=_int("DEVICE_REGISTRATIONS_PER_HOUR_PER_IP", 10),
            max_image_bytes=_int("MAX_IMAGE_BYTES", 1_000_000),
            cache_ttl_days=_int("CACHE_TTL_DAYS", 7),
            admin_token=e.get("ADMIN_TOKEN", ""),
            rewards_per_day=_int("REWARDS_PER_DAY", 5),
            free_voice_per_day=_int("FREE_VOICE_PER_DAY", 2),
            premium_voice_per_day=_int("PREMIUM_VOICE_PER_DAY", 30),
            invite_days=_int("INVITE_DAYS", 7),
            invite_max_rewards=_int("INVITE_MAX_REWARDS", 10),
            purchase_verifier=e.get("PURCHASE_VERIFIER", "fake"),
            product_days=e.get(
                "PRODUCT_DAYS", "premium_monthly=30,premium_quarterly=90,premium_yearly=365"
            ),
        )
        if "FOODS_PATH" in e:
            s.foods_path = Path(e["FOODS_PATH"])
        return s
