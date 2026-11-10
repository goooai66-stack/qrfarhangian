"""پنل مدیریت: رمز مدیر، نشست، و تنظیماتی که بدون ری‌استارت برای همه اعمال می‌شود.

- رمز فقط به‌صورت هش scrypt ذخیره می‌شود؛ توکن نشست فقط به‌صورت هش SHA-256.
- تنظیمات ذخیره‌شده در دیتابیس بر متغیرهای محیطی مقدم‌اند.
- کلیدهای API هرگز به مرورگر برنمی‌گردند (فقط چهار نویسه‌ی آخر).
"""

from __future__ import annotations

import dataclasses
import hashlib
import hmac
import json
import os
from dataclasses import dataclass

from .config import Settings
from .db import Database

MIN_PASSWORD = 10
SESSION_TTL = 12 * 3600
COOKIE = "cl_admin"
_OVERRIDES_KEY = "settings"
_PASSWORD_KEY = "password"


@dataclass(frozen=True)
class Field:
    name: str
    kind: str  # str | int | float | choice | secret
    label: str
    group: str
    hint: str = ""
    choices: tuple[str, ...] = ()
    min: float = 0
    max: float = 1_000_000


FIELDS: tuple[Field, ...] = (
    Field("vision_provider", "choice", "ارائه‌دهنده‌ی هوش مصنوعی", "هوش مصنوعی",
          "openai_compatible برای OpenRouter و سرویس‌های مشابه؛ none یعنی اسکن خاموش",
          choices=("none", "openai_compatible", "anthropic", "fake")),
    Field("openai_compat_base_url", "str", "آدرس API", "هوش مصنوعی", "OpenRouter: https://openrouter.ai/api/v1"),
    Field("openai_compat_api_key", "secret", "کلید API", "هوش مصنوعی", "خالی بگذار تا کلید فعلی بماند"),
    Field("openai_compat_model", "str", "نام مدل", "هوش مصنوعی", "مدلی با ورودی تصویر، مثلاً google/gemini-2.5-flash"),
    Field("anthropic_api_key", "secret", "کلید Anthropic", "هوش مصنوعی", "فقط اگر ارائه‌دهنده anthropic است"),
    Field("anthropic_model", "str", "مدل Anthropic", "هوش مصنوعی"),
    Field("provider_timeout_seconds", "float", "مهلت پاسخ مدل (ثانیه)", "هوش مصنوعی", min=3, max=120),
    Field("price_input_per_mtok", "float", "قیمت ورودی (دلار به ازای هر میلیون توکن)", "هزینه", "برای محاسبه‌ی هزینه‌ی هر اسکن"),
    Field("price_output_per_mtok", "float", "قیمت خروجی (دلار به ازای هر میلیون توکن)", "هزینه"),
    Field("free_scans_per_day", "int", "اسکن رایگان در روز (هر کاربر)", "سهمیه", max=1000),
    Field("premium_scans_per_day", "int", "اسکن کاربر ویژه در روز", "سهمیه", max=1000),
    Field("free_voice_per_day", "int", "ثبت صوتی رایگان در روز", "سهمیه", max=1000),
    Field("premium_voice_per_day", "int", "ثبت صوتی کاربر ویژه در روز", "سهمیه", max=1000),
    Field("scans_per_minute", "int", "حداکثر اسکن در دقیقه (هر کاربر)", "سهمیه", min=1, max=120),
    Field("rewards_per_day", "int", "حداکثر ویدیوی جایزه در روز", "سهمیه", max=100),
    Field("cache_ttl_days", "int", "نگه‌داری نتیجه‌ی اسکن تکراری (روز)", "سهمیه", max=365),
)
_BY_NAME = {f.name: f for f in FIELDS}
PROVIDER_FIELDS = {f.name for f in FIELDS if f.group == "هوش مصنوعی"}


class AdminError(Exception):
    def __init__(self, messages: list[str]):
        super().__init__("; ".join(messages))
        self.messages = messages


# ---- رمز ----

def hash_password(password: str) -> str:
    salt = os.urandom(16)
    h = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)
    return f"scrypt${salt.hex()}${h.hex()}"


def verify_password(password: str, stored: str | None) -> bool:
    try:
        scheme, salt, expected = (stored or "").split("$")
        if scheme != "scrypt":
            return False
        h = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=2**14, r=8, p=1, dklen=32)
        return hmac.compare_digest(h.hex(), expected)
    except (ValueError, TypeError):
        return False


def password_set(db: Database) -> bool:
    return db.admin_get(_PASSWORD_KEY) is not None


def set_password(db: Database, password: str) -> None:
    if len(password) < MIN_PASSWORD:
        raise AdminError([f"رمز باید حداقل {MIN_PASSWORD} نویسه باشد"])
    db.admin_set(_PASSWORD_KEY, hash_password(password))
    db.admin_sessions_clear()  # نشست‌های قبلی باطل می‌شوند


def check_password(db: Database, password: str) -> bool:
    return verify_password(password, db.admin_get(_PASSWORD_KEY))


# ---- تنظیمات ----

def _coerce(f: Field, raw) -> object:
    if f.kind in ("str", "secret"):
        if not isinstance(raw, str):
            raise ValueError
        v = raw.strip()
        if len(v) > 500 or any(ord(c) < 32 for c in v):
            raise ValueError
        return v
    if f.kind == "choice":
        if raw not in f.choices:
            raise ValueError
        return raw
    if isinstance(raw, bool):
        raise ValueError
    v = float(raw)
    if v != v or not (f.min <= v <= f.max):
        raise ValueError
    if f.kind == "int":
        if v != int(v):
            raise ValueError
        return int(v)
    return v


def load_overrides(db: Database) -> dict:
    try:
        d = json.loads(db.admin_get(_OVERRIDES_KEY) or "{}")
    except json.JSONDecodeError:
        return {}
    return {k: v for k, v in d.items() if k in _BY_NAME}


def apply_overrides(s: Settings, overrides: dict) -> Settings:
    """نسخه‌ای از تنظیمات با مقدارهای پنل روی آن (مقدار خراب نادیده گرفته می‌شود)."""
    clean = {}
    for k, v in overrides.items():
        try:
            clean[k] = _coerce(_BY_NAME[k], v)
        except (ValueError, TypeError):
            continue
    return dataclasses.replace(s, **clean)


def validate_update(current: Settings, incoming: dict) -> tuple[Settings, dict]:
    """ورودی فرم ← (تنظیمات تازه، تغییرها). خطاها به فارسی، همه با هم."""
    errors: list[str] = []
    changes: dict = {}
    for k, raw in incoming.items():
        f = _BY_NAME.get(k)
        if f is None:
            errors.append(f"تنظیم ناشناخته: {k}")
            continue
        if f.kind == "secret" and raw == "":
            continue  # خالی = کلید فعلی بماند
        try:
            changes[k] = _coerce(f, raw)
        except (ValueError, TypeError):
            errors.append(f"«{f.label}» نامعتبر است")
    if errors:
        raise AdminError(errors)
    candidate = dataclasses.replace(current, **changes)
    url = candidate.openai_compat_base_url
    if url and not url.startswith(("https://", "http://localhost", "http://127.0.0.1")):
        errors.append("آدرس API باید با https:// شروع شود")
    errors += candidate.problems()
    if errors:
        raise AdminError(errors)
    return candidate, changes


def save_overrides(db: Database, changes: dict) -> None:
    merged = load_overrides(db) | changes
    db.admin_set(_OVERRIDES_KEY, json.dumps(merged, ensure_ascii=False))


def mask(value: str) -> str:
    return "" if not value else "••••" + value[-4:] if len(value) > 8 else "••••"


def describe(s: Settings) -> list[dict]:
    """برای فرم: مقدار فعلی هر تنظیم؛ کلیدها فقط ماسک‌شده."""
    out = []
    for f in FIELDS:
        v = getattr(s, f.name)
        item = {"name": f.name, "kind": f.kind, "label": f.label, "group": f.group, "hint": f.hint}
        if f.kind == "secret":
            item |= {"value": "", "masked": mask(v), "is_set": bool(v)}
        else:
            item["value"] = v
        if f.choices:
            item["choices"] = list(f.choices)
        out.append(item)
    return out
