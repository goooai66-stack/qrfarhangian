"""رابط‌های اعتبارسنجی خرید (بازار/مایکت) و پاداش ویدیوی جایزه‌دار (تپسل).

پیاده‌سازی واقعی فروشگاه‌ها به حساب توسعه‌دهنده و کلید API نیاز دارد و
هنوز وصل نشده است؛ تا آن موقع NotConfigured خطای روشن «فعال نیست» می‌دهد.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Protocol

DAY = 86400


@dataclass
class VerifiedPurchase:
    product_id: str
    expires_at: int  # unix seconds


class InvalidPurchase(Exception):
    """توکن خرید معتبر نیست یا لغو/بازپرداخت شده."""


class VerifierUnavailable(Exception):
    """اعتبارسنجی پیکربندی نشده یا فروشگاه در دسترس نیست."""


class PurchaseVerifier(Protocol):
    async def verify(self, store: str, product_id: str, token: str) -> VerifiedPurchase: ...


class RewardVerifier(Protocol):
    async def verify(self, reward_token: str) -> bool: ...


def parse_product_days(spec: str) -> dict[str, int]:
    """«premium_monthly=30,premium_yearly=365» ← {محصول: روز}"""
    out = {}
    for part in filter(None, (p.strip() for p in spec.split(","))):
        k, _, v = part.partition("=")
        out[k.strip()] = int(v)
    return out


class FakePurchaseVerifier:
    """فقط برای توسعه و تست: توکن‌هایی که با «test-» شروع می‌شوند معتبرند."""

    def __init__(self, product_days: dict[str, int]):
        self.product_days = product_days

    async def verify(self, store: str, product_id: str, token: str) -> VerifiedPurchase:
        if product_id not in self.product_days:
            raise InvalidPurchase(f"unknown product {product_id}")
        if not token.startswith("test-"):
            raise InvalidPurchase("not a test token")
        return VerifiedPurchase(product_id, int(time.time()) + self.product_days[product_id] * DAY)


class NotConfiguredPurchaseVerifier:
    """جای اتصال API توسعه‌دهنده‌ی کافه‌بازار و مایکت (بعد از ساخت حساب)."""

    async def verify(self, store: str, product_id: str, token: str) -> VerifiedPurchase:
        raise VerifierUnavailable(f"purchase verification for {store} is not configured")


class TrustingRewardVerifier:
    """توسعه: هر توکن غیرخالی پذیرفته می‌شود. سقف روزانه جلوی سوءاستفاده را می‌گیرد."""

    async def verify(self, reward_token: str) -> bool:
        return bool(reward_token)
